local wire_visuals = require("wire-visuals")
local powered_defenses = require("powered-defenses")
local traps = require("traps")
local fuel_limit = require("fuel-limit")
local spinner = require("spinner")
local FIRE = "iw-defense-fire"
local FLAME = "iw-defense-flame"
local STEP = 30
local STARTER_COAL = 5
local DAMAGE_PER_SECOND = 26
local HALF_WIDTH = 1.5

local function coal_ticks()
  return math.max(60, math.floor(settings.global["iw-coal-burn-seconds"].value * 60 + 0.5))
end

local function remove_flame(state)
  if state.flame and state.flame.valid then state.flame.destroy() end
  for _, flame in pairs(state.flames or {}) do
    if flame.valid then flame.destroy() end
  end
  state.flame = nil
  state.flames = nil
end

local function ensure_flame(state)
  local entity = state.entity
  if not entity.valid then return end
  -- Reuse the old center reference when upgrading from a one-tile fire.
  state.flames = state.flames or {[5] = state.flame}
  local i = 0
  for y = -1, 1 do
    for x = -1, 1 do
      i = i + 1
      if not state.flames[i] or not state.flames[i].valid then
        state.flames[i] = entity.surface.create_entity{
          name = FLAME,
          position = {x = entity.position.x + x, y = entity.position.y + y},
          force = entity.force,
          initial_ground_flame_count = 1
        }
      end
    end
  end
  state.flame = state.flames[5]
end

local function damage_square(state, burned_ticks)
  local entity = state.entity
  local position = entity.position
  local targets = entity.surface.find_entities_filtered{
    area = {
      {position.x - HALF_WIDTH, position.y - HALF_WIDTH},
      {position.x + HALF_WIDTH, position.y + HALF_WIDTH}
    }
  }
  local damage = DAMAGE_PER_SECOND * burned_ticks / 60
  for _, target in pairs(targets) do
    -- Damage only mobile creatures and characters; all structures are safe.
    if not entity.valid then return end
    if target.valid and (target.type == "unit" or target.type == "character")
      and target.health and target.destructible then
      target.damage(damage, entity.force, "fire", state.flame, entity)
    end
  end
end

local function filter_coal(entity)
  local inventory = entity.get_inventory(defines.inventory.chest)
  if inventory then
    -- Include every quality of coal, while keeping other items out.
    inventory.set_filter(1, {name = "coal", quality = "normal", comparator = ">="})
    inventory.set_bar(2)
  end
  return inventory
end

local function extinguish(id, state)
  storage.fires[id] = nil
  remove_flame(state)
  if state.entity.valid then state.entity.destroy{raise_destroy = true} end
end

local function update_fire(id, state, tick)
  if not state.entity.valid then
    remove_flame(state)
    storage.fires[id] = nil
    return
  end
  local entity = state.entity
  local inventory = filter_coal(entity)
  local elapsed = math.max(0, tick - state.last_tick)
  local burned = 0
  state.last_tick = tick

  -- Pay for every elapsed tick, including an interval crossing several pieces
  -- of coal. Empty inventory does not extinguish coal already being burned.
  while true do
    if state.remaining_ticks <= 0 then
      local stack = inventory and inventory[1]
      if not stack or not stack.valid_for_read or stack.name ~= "coal" then
        break
      end
      -- Consume the occupied slot directly so quality coal burns too.
      stack.count = stack.count - 1
      state.remaining_ticks = coal_ticks()
    end
    if elapsed == 0 then break end
    local duration = math.min(elapsed, state.remaining_ticks)
    state.remaining_ticks = state.remaining_ticks - duration
    elapsed = elapsed - duration
    burned = burned + duration
  end

  if burned > 0 then
    local pollution = settings.global["iw-fire-pollution-per-minute"].value * burned / 3600
    if pollution > 0 then entity.surface.pollute(entity.position, pollution, FIRE) end
    ensure_flame(state)
    damage_square(state, burned)
  end
  if not entity.valid or state.remaining_ticks <= 0 then
    extinguish(id, state)
  else
    ensure_flame(state)
  end
end

local function register(entity, remaining_ticks)
  if not entity or not entity.valid or entity.name ~= FIRE then return end
  storage.fires = storage.fires or {}
  local id = entity.unit_number
  if storage.fires[id] then return end
  filter_coal(entity)
  local state = {
    entity = entity,
    remaining_ticks = remaining_ticks or STARTER_COAL * coal_ticks(),
    last_tick = game.tick
  }
  storage.fires[id] = state
  ensure_flame(state)
end

local function on_built(event)
  register(event.entity)
  wire_visuals.register(event.entity)
  powered_defenses.register(event.entity)
  traps.register(event.entity)
  spinner.register(event.entity)
  fuel_limit.register(event.entity)
  fuel_limit.update()
end

local function on_removed(event)
  local entity = event.entity
  if not entity then return end
  wire_visuals.remove(entity)
  powered_defenses.remove(entity)
  traps.remove(entity, event.name == defines.events.on_entity_died)
  spinner.remove(entity)
  fuel_limit.remove(entity)
  if entity.name ~= FIRE then return end
  local id = entity.unit_number
  local state = storage.fires and storage.fires[id]
  if state then
    storage.fires[id] = nil
    remove_flame(state)
  end
end

local function on_cloned(event)
  wire_visuals.register(event.destination)
  if powered_defenses.cloned(event) then return end
  traps.register(event.destination)
  spinner.register(event.destination)
  fuel_limit.register(event.destination)
  if event.destination.name == FLAME then
    -- Cloning an area also clones its decorative/damaging flame. The fuel
    -- container's own registered flame replaces it, preventing orphan fires.
    event.destination.destroy()
  elseif event.destination.name == FIRE then
    local source = storage.fires and storage.fires[event.source.unit_number]
    if source then update_fire(event.source.unit_number, source, game.tick) end
    register(event.destination, source and source.remaining_ticks or 0)
    update_fire(event.destination.unit_number, storage.fires[event.destination.unit_number], game.tick)
  end
end

local function rescan()
  wire_visuals.rescan()
  powered_defenses.rescan()
  traps.rescan()
  spinner.rescan()
  fuel_limit.rescan()
  storage.fires = storage.fires or {}
  -- Preserve already consumed starter fuel across version/config changes.
  for id, state in pairs(storage.fires) do
    if not state.entity.valid then
      remove_flame(state)
      storage.fires[id] = nil
    end
  end
  for _, surface in pairs(game.surfaces) do
    for _, flame in pairs(surface.find_entities_filtered{name = FLAME}) do flame.destroy() end
    for _, entity in pairs(surface.find_entities_filtered{name = FIRE}) do register(entity) end
  end
  for id, state in pairs(storage.fires) do update_fire(id, state, game.tick) end
end

local function on_surface_removed(event)
  wire_visuals.surface_removed(event)
  powered_defenses.surface_removed(event)
  traps.surface_removed(event)
  spinner.surface_removed(event)
  for id, state in pairs(storage.fires or {}) do
    if not state.entity.valid or state.entity.surface.index == event.surface_index then
      remove_flame(state)
      storage.fires[id] = nil
    end
  end
end

script.on_init(rescan)
script.on_configuration_changed(rescan)
script.on_event({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.on_space_platform_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive
}, on_built)
script.on_event({
  defines.events.on_player_mined_entity,
  defines.events.on_robot_mined_entity,
  defines.events.on_entity_died,
  defines.events.script_raised_destroy
}, on_removed)
script.on_event(defines.events.on_entity_cloned, on_cloned)
script.on_event({defines.events.on_pre_surface_deleted, defines.events.on_pre_surface_cleared}, on_surface_removed)
script.on_nth_tick(STEP, function(event)
  wire_visuals.update()
  traps.cleanup(event.tick)
  for id, state in pairs(storage.fires or {}) do update_fire(id, state, event.tick) end
end)

script.on_event(defines.events.on_player_rotated_entity, function(event)
  fuel_limit.register(event.entity)
  fuel_limit.update()
end)
script.on_nth_tick(1, function(event)
  fuel_limit.update()
  spinner.update(event.tick)
  powered_defenses.update(event.tick)
end)

script.on_event(defines.events.on_script_trigger_effect, traps.trigger)
