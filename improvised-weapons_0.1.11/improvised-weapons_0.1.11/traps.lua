local M = {}
local DUD = "iw-claymore-dud-fire"
local function track_dud(entity)
  if not entity or not entity.valid then return end
  storage.iw_dud_fires = storage.iw_dud_fires or {}
  for _, record in pairs(storage.iw_dud_fires) do
    if record.entity == entity then return end
  end
  table.insert(storage.iw_dud_fires, {entity = entity, surface = entity.surface,
    position = {x = entity.position.x, y = entity.position.y}, force = entity.force,
    last_tick = game.tick, expires = game.tick + 300})
end
local names = {["iw-claymore"] = true, ["iw-bear-trap"] = true}
local function key(surface_index, p, name)
  return surface_index .. ":" .. p.x .. ":" .. p.y .. ":" .. name
end
local function hostile(force, target)
  return target.valid and target.health and target.destructible and target.force
    and target.force ~= force and target.force.name ~= "neutral"
    and not force.get_friend(target.force) and not force.get_cease_fire(target.force)
end
function M.register(entity)
  if entity and entity.valid and entity.name == DUD then track_dud(entity); return end
  if not entity or not entity.valid or not names[entity.name] then return end
  storage.iw_traps = storage.iw_traps or {}
  local p = {x = entity.position.x, y = entity.position.y}
  storage.iw_traps[key(entity.surface.index, p, entity.name)] = {
    entity = entity, position = p, force = entity.force, surface = entity.surface
  }
end
function M.rescan()
  storage.iw_traps = {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{name = DUD}) do track_dud(entity) end
    for name in pairs(names) do
      for _, entity in pairs(surface.find_entities_filtered{name = name}) do M.register(entity) end
    end
  end
end
function M.remove(entity, died)
  if not names[entity.name] then return end
  local k = key(entity.surface.index, entity.position, entity.name)
  local record = storage.iw_traps and storage.iw_traps[k]
  if not record then return end
  -- Keep the force/position briefly if native mine consumption invalidates its
  -- source before the script-trigger event arrives. Mining gets no effects.
  if died then record.expires = game.tick + 2 else storage.iw_traps[k] = nil end
end
function M.cleanup(tick)
  for i = #(storage.iw_dud_fires or {}), 1, -1 do
    local record = storage.iw_dud_fires[i]
    -- At natural expiry the native flame may already be invalid; still pay
    -- the final interval, but stop immediately for early destruction.
    if record.surface.valid and (record.entity.valid or tick >= record.expires) then
      local elapsed = math.max(0, math.min(tick, record.expires) - record.last_tick)
      record.last_tick = tick
      if elapsed > 0 then
        local p = record.position
        for _, target in pairs(record.surface.find_entities_filtered{
          area = {{p.x - 0.5, p.y - 0.5}, {p.x + 0.5, p.y + 0.5}}
        }) do
          if target.valid and (target.type == "unit" or target.type == "character")
            and target.health and target.destructible then
            target.damage(13 * elapsed / 60, record.force, "fire",
              record.entity.valid and record.entity or nil)
          end
        end
      end
    end
    if not record.surface.valid or not record.entity.valid or tick >= record.expires then
      table.remove(storage.iw_dud_fires, i)
    end
  end
  for k, record in pairs(storage.iw_traps or {}) do
    if not record.entity.valid and not record.expires then record.expires = tick + 2 end
    if record.expires and tick > record.expires then storage.iw_traps[k] = nil end
  end
end
function M.surface_removed(event)
  for i = #(storage.iw_dud_fires or {}), 1, -1 do
    local record = storage.iw_dud_fires[i]
    if not record.surface.valid or record.surface.index == event.surface_index then
      table.remove(storage.iw_dud_fires, i)
    end
  end
  for k, record in pairs(storage.iw_traps or {}) do
    if not record.surface.valid or record.surface.index == event.surface_index then storage.iw_traps[k] = nil end
  end
end
function M.trigger(event)
  local name = event.effect_id == "iw-claymore-trigger" and "iw-claymore"
    or event.effect_id == "iw-bear-trap-trigger" and "iw-bear-trap"
  if not name then return end
  local source = event.source_entity
  local p = source and source.valid and source.position or event.source_position
  if not p then return end
  local k = key(event.surface_index, p, name)
  local record = storage.iw_traps and storage.iw_traps[k]
  if not record and source and source.valid and source.name == name then
    M.register(source); record = storage.iw_traps[k]
  end
  if not record or record.spent then return end
  record.spent = true
  record.expires = game.tick + 2
  local surface, force = record.surface, record.force
  if not surface.valid then return end
  local cause = source and source.valid and source or nil
  if name == "iw-claymore" then
    storage.iw_trap_rng = storage.iw_trap_rng or game.create_random_generator()
    if storage.iw_trap_rng(1, 2) == 1 then
      surface.create_entity{name = "explosion", position = p}
      for _, target in pairs(surface.find_entities_filtered{
        area = {{p.x - 3, p.y - 3}, {p.x + 3, p.y + 3}}
      }) do
        local dx, dy = target.position.x - p.x, target.position.y - p.y
        if hostile(force, target) and dx * dx + dy * dy <= 9 then
          target.damage(250, force, "explosion", cause and cause.valid and cause or nil)
        end
      end
    else
      track_dud(surface.create_entity{name = DUD, position = p, force = force,
        initial_ground_flame_count = 1})
    end
  else
    -- Native trigger radius 0.01 requires collision with the center point.
    -- Query that same contact zone, then hit only the nearest hostile entity.
    local nearest, distance
    for _, target in pairs(surface.find_entities_filtered{
      area = {{p.x - 0.01, p.y - 0.01}, {p.x + 0.01, p.y + 0.01}}
    }) do
      if hostile(force, target) then
        local dx, dy = target.position.x - p.x, target.position.y - p.y
        local d = dx * dx + dy * dy
        if not nearest or d < distance then nearest, distance = target, d end
      end
    end
    if nearest then nearest.damage(100, force, "physical", cause and cause.valid and cause or nil) end
  end
  -- Native force_die_on_attack consumes the mine after its action finishes.
end
return M
