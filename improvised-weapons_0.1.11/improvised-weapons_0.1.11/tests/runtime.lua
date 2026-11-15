-- Regression tests with a simulated Factorio API, not an engine integration test.
local handlers, nth, every_tick, init, config
storage = {}
settings = {global = {
  ["iw-coal-burn-seconds"] = {value = 10},
  ["iw-fire-pollution-per-minute"] = {value = 60}
}}
defines = {inventory = {chest = 1}, events = {}, build_check_type = {manual = "manual"}, wire_connector_id = {pole_copper = 1}}
for _, name in ipairs({
  "on_built_entity", "on_robot_built_entity", "on_space_platform_built_entity",
  "script_raised_built", "script_raised_revive", "on_player_mined_entity",
  "on_robot_mined_entity", "on_entity_died", "script_raised_destroy",
  "on_entity_cloned", "on_pre_surface_deleted", "on_pre_surface_cleared", "on_player_rotated_entity", "on_script_trigger_effect"
}) do defines.events[name] = name end
handlers = {}
script = {
  on_init = function(f) init = f end,
  on_configuration_changed = function(f) config = f end,
  on_event = function(events, f)
    if type(events) ~= "table" then events = {events} end
    for _, event in ipairs(events) do handlers[event] = f end
  end,
  on_nth_tick = function(n, f) if n == 1 then every_tick = f else assert(n == 30); nth = f end end
}
rendering={objects={},draw_sprite=function(spec)
  local object={valid=true,sprite=spec.sprite,target=spec.target}
  function object.destroy()object.valid=false end
  table.insert(rendering.objects,object)
  return object
end}
local next_id = 0
local surface = {valid = true, index = 1, entities = {}, pollution = 0}
game = {tick = 0, surfaces = {surface}}

function surface.create_entity(spec)
  local e = {valid = true, name = spec.name, position = spec.position, force = spec.force, surface = surface, energy = 0}
  function e.destroy()
    e.valid = false
  end
  surface.entities[#surface.entities + 1] = e
  return e
end
function surface.find_entities_filtered(spec)
  local found = {}
  for _, e in ipairs(surface.entities) do
    local matches = (not spec.name or e.name == spec.name) and (not spec.type or e.type == spec.type)
    if matches and spec.position then
      matches = e.position.x == spec.position.x and e.position.y == spec.position.y
    end
    if matches and spec.area then
      local a, b = spec.area[1], spec.area[2]
      matches = e.position.x >= a[1] and e.position.x < b[1]
        and e.position.y >= a[2] and e.position.y < b[2]
    end
    if e.valid and matches then found[#found + 1] = e end
  end
  return found
end
function surface.pollute(position, amount, prototype)
  assert(prototype == "iw-defense-fire")
  surface.pollution = surface.pollution + amount
end

local function holder(count, quality)
  next_id = next_id + 1
  local values = {count = count or 0, name = "coal", quality = quality or "normal"}
  local stack = setmetatable({}, {
    __index = function(_, key)
      if key == "valid_for_read" then return values.count > 0 end
      return values[key]
    end,
    __newindex = function(_, key, value) values[key] = value end
  })
  local inventory = {[1] = stack}
  function inventory.set_filter(index, filter)
    assert(index == 1 and filter.name == "coal" and filter.comparator == ">=")
    inventory.filter = filter
    return true
  end
  function inventory.set_bar(bar) assert(bar == 2) end
  local e = {
    name = "iw-defense-fire", unit_number = next_id, valid = true,
    position = {x = next_id, y = 0}, force = "player", surface = surface
  }
  function e.get_inventory(index) assert(index == 1); return inventory end
  function e.destroy(options)
    e.valid = false
    if options and options.raise_destroy then handlers.script_raised_destroy{entity = e} end
  end
  e.inventory = inventory
  surface.entities[#surface.entities + 1] = e
  return e
end

local function build(e, event)
  handlers[event or "on_built_entity"]{entity = e}
  return storage.fires[e.unit_number]
end
local function tick(t)
  game.tick = t
  nth{tick = t}
end
local function near(a, b) assert(math.abs(a - b) < 0.00001, tostring(a) .. " ~= " .. tostring(b)) end
local function reset()
  storage = {}
  rendering.objects = {}
  game.tick = 0
  surface.entities = {}
  surface.pollution = 0
  surface.block_shove = false
  settings.global["iw-coal-burn-seconds"].value = 10
  settings.global["iw-fire-pollution-per-minute"].value = 60
  init()
end
local tests = 0
local function test(name, f)
  reset()
  f()
  tests = tests + 1
  print("PASS " .. name)
end

package.path = MOD_ROOT .. "/?.lua;" .. package.path
dofile(MOD_ROOT .. "/control.lua")

test("starter fuel and exact burnout", function()
  local e = holder()
  local s = build(e)
  assert(s.remaining_ticks == 3000 and s.flame.valid)
  tick(2970)
  assert(e.valid and s.remaining_ticks == 30)
  tick(3000)
  assert(not e.valid and not s.flame and storage.fires[e.unit_number] == nil)
  near(surface.pollution, 50)
end)
test("queued coal keeps fire lit after starter fuel", function()
  local e = holder(2)
  local s = build(e)
  tick(3000)
  assert(e.valid and e.inventory[1].count == 1 and s.remaining_ticks == 600)
  tick(3600)
  assert(e.valid and e.inventory[1].count == 0 and s.remaining_ticks == 600)
  tick(4200)
  assert(not e.valid)
  near(surface.pollution, 70)
end)
test("inserter-style refill before final fuel exhaustion", function()
  local e = holder()
  build(e)
  tick(2970)
  e.inventory[1].count = 1
  tick(3000)
  assert(e.valid and storage.fires[e.unit_number].remaining_ticks == 600)
end)
test("all qualities of coal burn", function()
  local e = holder(1, "legendary")
  build(e)
  tick(3000)
  assert(e.valid and e.inventory[1].count == 0)
  tick(3600)
  assert(not e.valid)
end)
test("large elapsed interval consumes multiple coal", function()
  local e = holder(5)
  local s = build(e)
  tick(4530)
  assert(e.valid and e.inventory[1].count == 2 and s.remaining_ticks == 270)
  near(surface.pollution, 75.5)
end)
test("pollution stops at exact fuel exhaustion during long update", function()
  local e = holder(1)
  build(e)
  tick(9000)
  assert(not e.valid)
  near(surface.pollution, 60)
end)
test("runtime settings affect new coal, preserving current fuel", function()
  local e = holder(1)
  local s = build(e)
  tick(1500)
  settings.global["iw-coal-burn-seconds"].value = 20
  settings.global["iw-fire-pollution-per-minute"].value = 120
  tick(3000)
  assert(s.remaining_ticks == 1200)
  near(surface.pollution, 75)
  tick(4200)
  assert(not e.valid)
  near(surface.pollution, 115)
end)
test("config rescan preserves burn progress and removes orphan flames", function()
  local e = holder()
  local s = build(e)
  tick(1500)
  local old = s.flame
  local orphan = surface.create_entity{name = "iw-defense-flame", position = {x = 0, y = 0}}
  config()
  assert(s.remaining_ticks == 1500 and not old.valid and not orphan.valid)
  assert(s.flame.valid and #surface.find_entities_filtered{name = "iw-defense-flame"} == 9)
  config()
  near(surface.pollution, 25)
end)
test("reloading control code preserves stored fuel and paired flame", function()
  local e = holder()
  local s = build(e)
  tick(1500)
  local flame = s.flame
  package.path = MOD_ROOT .. "/?.lua;" .. package.path
dofile(MOD_ROOT .. "/control.lua")
  assert(storage.fires[e.unit_number] == s and s.remaining_ticks == 1500)
  tick(1530)
  assert(s.flame == flame and s.remaining_ticks == 1470)
  near(surface.pollution, 25.5)
end)
test("all supported construction events register without double fuel", function()
  for _, event in ipairs({"on_built_entity", "on_robot_built_entity", "on_space_platform_built_entity", "script_raised_built", "script_raised_revive"}) do
    local e = holder()
    local s = build(e, event)
    assert(s and s.flame.valid)
    s.remaining_ticks = 1
    build(e, event)
    assert(s.remaining_ticks == 1)
  end
end)
test("mining and death remove paired flames", function()
  for _, event in ipairs({"on_player_mined_entity", "on_robot_mined_entity", "on_entity_died", "script_raised_destroy"}) do
    local e = holder()
    local s = build(e)
    local flame = s.flame
    handlers[event]{entity = e}
    assert(not flame.valid and not storage.fires[e.unit_number])
  end
end)
test("invalid holder and lost flame recover cleanly", function()
  local e = holder()
  local s = build(e)
  s.flame.destroy()
  tick(30)
  assert(s.flame.valid)
  local replacement = s.flame
  e.valid = false
  tick(60)
  assert(not replacement.valid and not storage.fires[e.unit_number])
end)
test("clones copy remaining fuel and discard cloned flames", function()
  local e = holder()
  local s = build(e)
  tick(1500)
  local destination = holder()
  handlers.on_entity_cloned{source = e, destination = destination}
  assert(storage.fires[destination.unit_number].remaining_ticks == 1500)
  local duplicated_flame = surface.create_entity{name = "iw-defense-flame", position = {x = 9, y = 9}}
  handlers.on_entity_cloned{source = s.flame, destination = duplicated_flame}
  assert(not duplicated_flame.valid)
  assert(#surface.find_entities_filtered{name = "iw-defense-flame"} == 18)
end)
test("clearing or deleting a surface removes states and flames", function()
  for _, event in ipairs({"on_pre_surface_cleared", "on_pre_surface_deleted"}) do
    local e = holder()
    local s = build(e)
    local flame = s.flame
    handlers[event]{surface_index = 1}
    assert(not flame.valid and not storage.fires[e.unit_number])
  end
end)
test("multiple fires emit independent pollution", function()
  build(holder())
  build(holder())
  tick(60)
  near(surface.pollution, 2)
end)
test("zero pollution setting", function()
  settings.global["iw-fire-pollution-per-minute"].value = 0
  build(holder())
  tick(3000)
  near(surface.pollution, 0)
end)
local function target(x, y, kind, name)
  local e = surface.create_entity{name = name or kind, position = {x = x, y = y}, force = "enemy"}
  e.type = kind
  e.health = 1000
  e.destructible = true
  e.received = 0
  function e.damage(amount, force, damage_type, source, cause)
    assert(force == "player" and damage_type == "fire")
    assert(source.valid and cause.valid and cause.name == "iw-defense-fire")
    e.received = e.received + amount
    e.health = e.health - amount
    return amount
  end
  return e
end
test("nine flames cover the square with one fuel holder", function()
  local e = holder(1)
  local s = build(e)
  assert(#s.flames == 9)
  assert(#surface.find_entities_filtered{name = "iw-defense-fire"} == 1)
  local positions = {}
  for _, f in ipairs(s.flames) do positions[f.position.x .. "," .. f.position.y] = true end
  for y = -1, 1 do
    for x = -1, 1 do assert(positions[(e.position.x + x) .. "," .. y]) end
  end
  tick(3000)
  assert(e.inventory[1].count == 0 and s.remaining_ticks == 600)
  tick(3600)
  assert(not e.valid and #surface.find_entities_filtered{name = "iw-defense-flame"} == 0)
end)
test("square damage includes all diagonal tiles and excludes outside targets", function()
  local e = holder()
  build(e)
  local inside, outside = {}, {}
  for y = -1, 1 do
    for x = -1, 1 do inside[#inside + 1] = target(e.position.x + x, y, "unit") end
  end
  for _, offset in ipairs({{2, 0}, {-2, 0}, {0, 2}, {0, -2}, {2, 2}}) do
    outside[#outside + 1] = target(e.position.x + offset[1], offset[2], "unit")
  end
  tick(30)
  for _, t in ipairs(inside) do near(t.received, 13) end
  for _, t in ipairs(outside) do near(t.received, 0) end
  tick(60)
  for _, t in ipairs(inside) do near(t.received, 26) end
end)
test("standard and modded inserters remain immune inside the fire", function()
  local e = holder()
  build(e)
  local normal = target(e.position.x + 1, 0, "inserter", "inserter")
  local burner = target(e.position.x, 1, "inserter", "burner-inserter")
  local modded = target(e.position.x - 1, -1, "inserter", "modded-arm")
  local chest = target(e.position.x, -1, "container", "iron-chest")
  tick(60)
  for _, t in ipairs({normal, burner, modded}) do near(t.received, 0) end
  near(chest.received, 0)
end)
test("friendly characters burn while indestructible entities are ignored", function()
  local e = holder()
  build(e)
  local player = target(e.position.x + 1, 1, "character")
  player.force = "player"
  local protected = target(e.position.x - 1, 0, "simple-entity")
  protected.destructible = false
  tick(30)
  near(player.received, 13)
  near(protected.received, 0)
end)
test("partial final fuel interval limits damage and removes every flame", function()
  local e = holder()
  local s = build(e)
  s.remaining_ticks = 10
  local biter = target(e.position.x + 1, -1, "unit")
  tick(30)
  near(biter.received, 26 / 6)
  assert(not e.valid and #surface.find_entities_filtered{name = "iw-defense-flame"} == 0)
  tick(60)
  near(biter.received, 26 / 6)
end)
test("mining removes all nine flames immediately", function()
  local e = holder()
  build(e)
  handlers.on_player_mined_entity{entity = e}
  assert(#surface.find_entities_filtered{name = "iw-defense-flame"} == 0)
end)
test("one-tile save states upgrade without resetting fuel", function()
  local e = holder()
  local old_center = surface.create_entity{name = "iw-defense-flame", position = e.position, force = e.force}
  storage.fires[e.unit_number] = {entity = e, flame = old_center, remaining_ticks = 900, last_tick = 0}
  config()
  local s = storage.fires[e.unit_number]
  assert(s.remaining_ticks == 900 and #s.flames == 9 and not old_center.valid)
end)

test("boiler-equivalent setting emits 30 per minute for all nine flames", function()
  settings.global["iw-fire-pollution-per-minute"].value = 30
  local e = holder(2)
  build(e)
  tick(3600)
  assert(e.valid and #surface.find_entities_filtered{name = "iw-defense-flame"} == 9)
  near(surface.pollution, 30)
end)


local function feeder(target, held_count)
  next_id = next_id + 1
  local e = {type = "inserter", name = "inserter", valid = true, unit_number = next_id,
    surface = surface, position = {x = target.position.x, y = 1},
    drop_target = target, drop_position = target.position,
    held_stack = {valid_for_read = (held_count or 0) > 0, count = held_count or 0},
    disabled_by_script = false, inserter_stack_size_override = 0}
  surface.entities[#surface.entities + 1] = e
  handlers.on_built_entity{entity = e}
  return e
end

test("automatic feeding stops at five while manual full stacks remain", function()
  local e = holder(5)
  build(e)
  local arm = feeder(e, 1)
  assert(arm.disabled_by_script and arm.inserter_stack_size_override == 1)
  e.inventory[1].count = 50
  every_tick{tick = 1}
  assert(e.inventory[1].count == 50 and arm.disabled_by_script)
  e.inventory[1].count = 4
  every_tick{tick = 2}
  assert(not arm.disabled_by_script)
end)
test("simultaneous inserter hands reserve the last fuel space", function()
  local e = holder(4)
  build(e)
  local a, b = feeder(e, 1), feeder(e, 1)
  every_tick{tick = 1}
  assert(a.disabled_by_script ~= b.disabled_by_script)
  e.inventory[1].count = 5
  every_tick{tick = 2}
  assert(a.disabled_by_script and b.disabled_by_script)
end)
test("full hands wait for sufficient space and remain intact", function()
  local e = holder(4)
  build(e)
  local arm = feeder(e, 3)
  assert(arm.disabled_by_script and arm.held_stack.count == 3)
  e.inventory[1].count = 2
  every_tick{tick = 1}
  assert(not arm.disabled_by_script and arm.held_stack.count == 3)
end)
test("retargeting restores inserter stack and script state", function()
  local e = holder(5)
  build(e)
  local arm = feeder(e, 1)
  arm.drop_target = nil
  arm.drop_position = {x = 100, y = 100}
  every_tick{tick = 1}
  assert(not arm.disabled_by_script and arm.inserter_stack_size_override == 0)
end)
test("fuel limiter restores and reacquires feeders on configuration change", function()
  local e = holder(5)
  build(e)
  local arm = feeder(e, 1)
  config()
  assert(arm.disabled_by_script and arm.inserter_stack_size_override == 1)
  e.inventory[1].count = 4
  every_tick{tick = 1}
  assert(not arm.disabled_by_script)
end)

local player_force = {name = "player"}
function player_force.get_friend(force) return force.name == "ally" end
function player_force.get_cease_fire(force) return force.name == "truce" end
local function spinner_entity()
  next_id = next_id + 1
  local e = {name = "iw-spinner", type = "radar", valid = true, unit_number = next_id,
    position = {x = 0, y = 0}, surface = surface, force = player_force, active = true,
    burner = {remaining_burning_fuel = 0}}
  surface.entities[#surface.entities + 1] = e
  handlers.on_built_entity{entity = e}
  return e
end
local function spinner_target(x, y, force)
  local e = {name = "target", type = "unit", valid = true, position = {x = x, y = y},
    force = force or {name = "enemy"}, health = 100, destructible = true, damage_taken = 0}
  function e.damage(amount, source, damage_type, cause)
    assert(source == player_force and damage_type == "physical" and cause.name == "iw-spinner")
    e.damage_taken = e.damage_taken + amount
  end
  surface.entities[#surface.entities + 1] = e
  return e
end
local function spinner_ticks(first, last)
  for t = first, last do game.tick = t; every_tick{tick = t} end
end
test("spinner damages diagonal enemies but excludes outside square", function()
  local e = spinner_entity(); e.burner.remaining_burning_fuel = 100
  local inside = spinner_target(1, 1)
  local outside = spinner_target(2, 0)
  spinner_ticks(1, 60)
  near(inside.damage_taken, 13); near(outside.damage_taken, 0)
end)
test("spinner exempts friendly, allied, neutral and cease-fire non-character units", function()
  local e = spinner_entity(); e.burner.remaining_burning_fuel = 100
  local targets = {spinner_target(0, 0, player_force), spinner_target(0, 0, {name = "ally"}),
    spinner_target(0, 0, {name = "neutral"}), spinner_target(0, 0, {name = "truce"})}
  spinner_ticks(1, 60)
  for _, target in ipairs(targets) do near(target.damage_taken, 0) end
end)
test("empty spinner persists and restarts when refueled", function()
  local e = spinner_entity()
  local target = spinner_target(0, 1)
  spinner_ticks(1, 30); near(target.damage_taken, 0)
  assert(e.valid)
  e.burner.remaining_burning_fuel = 100
  spinner_ticks(31, 60); near(target.damage_taken, 6.5)
  e.burner.remaining_burning_fuel = 0
  spinner_ticks(61, 90); near(target.damage_taken, 6.5)
  assert(e.valid)
end)
test("spinner charges damage only for powered ticks", function()
  local e = spinner_entity()
  local target = spinner_target(0, 1)
  e.burner.remaining_burning_fuel = 100
  spinner_ticks(1, 10)
  e.burner.remaining_burning_fuel = 0
  spinner_ticks(11, 30)
  near(target.damage_taken, 13 / 6)
end)
test("disabled spinner does not damage and resumes without starter fuel", function()
  local e = spinner_entity(); e.burner.remaining_burning_fuel = 100; e.active = false
  local target = spinner_target(0, 1)
  spinner_ticks(1, 30); near(target.damage_taken, 0)
  e.active = true
  config()
  spinner_ticks(31, 60); near(target.damage_taken, 6.5)
end)
test("spinner removal and surface cleanup discard damage state", function()
  local e = spinner_entity()
  handlers.on_player_mined_entity{entity = e}
  assert(not storage.iw_spinners[e.unit_number])
  local b = spinner_entity()
  handlers.on_pre_surface_cleared{surface_index = surface.index}
  assert(not storage.iw_spinners[b.unit_number])
end)

test("circuit-disabled feeder does not reserve the last space", function()
  local e = holder(4); build(e)
  local a, b = feeder(e, 1), feeder(e, 1)
  a.disabled_by_control_behavior = true
  every_tick{tick = 1}
  assert(not b.disabled_by_script)
end)
test("external script-disabled state survives limiter release", function()
  local e = holder(4); build(e)
  local a = feeder(e, 1)
  a.disabled_by_script = true
  every_tick{tick = 1}
  e.inventory[1].count = 5
  every_tick{tick = 2}
  a.drop_target = nil; a.drop_position = {x = 100, y = 100}
  every_tick{tick = 3}
  assert(a.disabled_by_script and a.inserter_stack_size_override == 0)
end)

local function trap_entity(name, x)
  next_id = next_id + 1
  local e = {name = name, type = "land-mine", valid = true, unit_number = next_id,
    position = {x = x or 0, y = 0}, surface = surface, force = player_force}
  surface.entities[#surface.entities + 1] = e
  handlers.on_built_entity{entity = e}
  return e
end
local function trap_target(x, y, force)
  local e = {name = "medium-biter", type = "unit", valid = true,
    position = {x = x, y = y}, force = force or {name = "enemy"},
    health = 75, destructible = true, received = 0}
  function e.damage(amount, source, damage_type)
    assert(source == player_force)
    e.received = e.received + amount
    e.last_damage_type = damage_type
    local effective = damage_type == "physical" and (amount - 4) * 0.9 or amount * 0.9
    e.health = math.max(0, e.health - effective)
  end
  surface.entities[#surface.entities + 1] = e
  return e
end
local function trigger_trap(e, roll, invalid_source)
  storage.iw_trap_rng = function(low, high) assert(low == 1 and high == 2); return roll end
  handlers.on_script_trigger_effect{effect_id = e.name .. "-trigger", source_entity = e,
    source_position = e.position, surface_index = surface.index, tick = game.tick}
end
local function count_entities(name)
  return #surface.find_entities_filtered{name = name}
end
test("claymore successful roll explodes once within circular radius", function()
  local e = trap_entity("iw-claymore")
  local inside = trap_target(2, 0)
  local corner = trap_target(2.8, 2.8)
  local friendly = trap_target(0, 0, player_force)
  trigger_trap(e, 1)
  near(inside.received, 250); near(corner.received, 0); near(friendly.received, 0)
  assert(inside.last_damage_type == "explosion")
  assert(count_entities("explosion") == 1 and count_entities("iw-claymore-dud-fire") == 0)
  trigger_trap(e, 1)
  near(inside.received, 250); assert(count_entities("explosion") == 1)
end)
test("claymore failed roll creates only the short-lived native fire", function()
  local e = trap_entity("iw-claymore")
  local target = trap_target(0, 0)
  trigger_trap(e, 2)
  near(target.received, 0)
  assert(count_entities("explosion") == 0 and count_entities("iw-claymore-dud-fire") == 1)
  local fire = surface.find_entities_filtered{name = "iw-claymore-dud-fire"}[1]
  assert(fire.force == player_force and fire.position.x == 0)
  trigger_trap(e, 2)
  assert(count_entities("iw-claymore-dud-fire") == 1)
end)
test("trap effects retain their owning force after native consumption", function()
  local e = trap_entity("iw-claymore")
  local target = trap_target(0, 0)
  handlers.on_entity_died{entity = e, name = defines.events.on_entity_died}
  e.valid = false
  trigger_trap(e, 1)
  near(target.received, 250)
end)
test("bear trap kills a vanilla medium biter only on direct contact", function()
  local e = trap_entity("iw-bear-trap")
  local on_top = trap_target(0, 0)
  local adjacent = trap_target(0.5, 0)
  trigger_trap(e, 1)
  near(on_top.received, 100); assert(on_top.health == 0 and on_top.last_damage_type == "physical")
  near(adjacent.received, 0); assert(count_entities("explosion") == 0)
end)
test("bear trap strikes one overlapping hostile and spares friends", function()
  local e = trap_entity("iw-bear-trap")
  local a, b = trap_target(0, 0), trap_target(0.005, 0)
  local friend = trap_target(0, 0, player_force)
  trigger_trap(e, 1)
  near(a.received, 100); near(b.received, 0); near(friend.received, 0)
end)
test("bear trap cannot repeat its strike", function()
  local e = trap_entity("iw-bear-trap")
  local target = trap_target(0, 0)
  trigger_trap(e, 1); trigger_trap(e, 1)
  near(target.received, 100)
end)
test("mining a trap produces neither blast nor dud fire", function()
  local e = trap_entity("iw-claymore")
  handlers.on_player_mined_entity{entity = e, name = defines.events.on_player_mined_entity}
  e.valid = false
  trigger_trap(e, 2)
  assert(count_entities("iw-claymore-dud-fire") == 0 and count_entities("explosion") == 0)
end)
test("trap rescan and cloned traps preserve independent outcomes", function()
  local original = trap_entity("iw-claymore", 0)
  local clone = trap_entity("iw-claymore", 10)
  handlers.on_entity_cloned{source = original, destination = clone}
  config()
  trigger_trap(original, 1); trigger_trap(clone, 2)
  assert(count_entities("explosion") == 1 and count_entities("iw-claymore-dud-fire") == 1)
end)
test("trap cleanup handles surface removal and ordinary destruction", function()
  local e = trap_entity("iw-bear-trap")
  handlers.on_entity_died{entity = e, name = defines.events.on_entity_died}
  e.valid = false
  tick(30)
  assert(next(storage.iw_traps) == nil)
  trap_entity("iw-claymore")
  handlers.on_pre_surface_cleared{surface_index = surface.index}
  assert(next(storage.iw_traps) == nil)
end)
test("unrelated script effects leave improvised traps alone", function()
  trap_entity("iw-claymore")
  handlers.on_script_trigger_effect{effect_id = "foreign-mod-effect", surface_index = surface.index}
  assert(count_entities("explosion") == 0 and count_entities("iw-claymore-dud-fire") == 0)
end)

function surface.find_non_colliding_position(name, desired, radius, precision)
  if surface.block_shove then return nil end
  return {x = desired.x, y = desired.y}
end
local function character(x, y)
  local e = spinner_target(x, y, player_force)
  e.name, e.type = "character", "character"
  function e.teleport(p,surface_arg,raised,snap,check)
    assert(check=="manual")
    if surface.block_shove then return false end
    e.position = {x = p.x, y = p.y}; e.shoves = (e.shoves or 0) + 1; return true
  end
  return e
end
test("spinner damages and gently pushes its owning player's character", function()
  local e = spinner_entity(); e.burner.remaining_burning_fuel = 100
  local player = character(1, 0)
  spinner_ticks(1, 30)
  near(player.damage_taken, 6.5); near(player.position.x, 1.35)
  assert(player.shoves == 1)
end)
test("spinner keeps damaging when no safe knockback position exists", function()
  local e = spinner_entity(); e.burner.remaining_burning_fuel = 100
  local player = character(0, 0)
  surface.block_shove = true
  spinner_ticks(1, 30)
  near(player.damage_taken, 6.5); near(player.position.y, 0)
  assert(not player.shoves)
end)
test("spinner skips knockback for a player riding in a vehicle", function()
  local e = spinner_entity(); e.burner.remaining_burning_fuel = 100
  local player = character(1, 0); player.player = {vehicle = {}}
  spinner_ticks(1, 30)
  near(player.damage_taken, 6.5); near(player.position.x, 1)
end)
local function defense(name)
  next_id = next_id + 1
  local e = {name = name, valid = true, unit_number = next_id,
    type = name == "iw-barbed-wire" and "wall" or name == "iw-electric-fence" and "electric-pole" or "fluid-turret",
    position = {x = 0, y = 0}, surface = surface, force = player_force, disabled_by_script = false}
  surface.entities[#surface.entities + 1] = e
  handlers.on_built_entity{entity = e}
  return e, storage.iw_powered_defenses[e.unit_number]
end
local function contact_target(x, kind, force)
  local e = {name = kind or "small-biter", type = kind == "character" and "character" or "unit",
    valid = true, health = 100, destructible = true, force = force or {name = "enemy"},
    position = {x = x, y = 0}, received = 0}
  function e.damage(amount, owner, damage_type, cause)
    assert(owner == player_force and cause.valid)
    e.received = e.received + amount; e.last_damage_type = damage_type
  end
  surface.entities[#surface.entities + 1] = e
  return e
end
test("barbed wire causes small contact damage to enemies and players", function()
  defense("iw-barbed-wire")
  local enemy, player, distant = contact_target(0.6), contact_target(-0.6,"character",player_force), contact_target(1)
  spinner_ticks(1, 60)
  near(enemy.received,4); near(player.received,4); near(distant.received,0)
  assert(enemy.last_damage_type == "physical")
end)
test("electric fence remains harmless without power and shocks when charged", function()
  local e, state = defense("iw-electric-fence")
  local enemy, player = contact_target(0.6), contact_target(-0.6,"character",player_force)
  spinner_ticks(1,30); near(enemy.received,0)
  assert(state.consumer.valid and not state.consumer.destructible and not state.consumer.operable)
  state.consumer.energy = 100
  spinner_ticks(31,90)
  near(enemy.received,40); near(player.received,40)
  assert(enemy.last_damage_type == "electric")
  state.consumer.energy = 0
  spinner_ticks(91,120); near(enemy.received,40)
end)
test("electric fence charges damage only for ticks with power", function()
  local e, state = defense("iw-electric-fence")
  local enemy = contact_target(0.6)
  state.consumer.energy = 100; spinner_ticks(1,10)
  state.consumer.energy = 0; spinner_ticks(11,30)
  near(enemy.received,40/6)
end)
test("flamethrower turret requires electricity and resumes when recharged", function()
  local e, state = defense("flamethrower-turret")
  assert(e.disabled_by_script)
  state.consumer.energy = 100; spinner_ticks(1,1)
  assert(not e.disabled_by_script)
  state.consumer.energy = 0; spinner_ticks(2,2)
  assert(e.disabled_by_script)
  state.consumer.energy = 100; spinner_ticks(3,3)
  assert(not e.disabled_by_script)
end)
test("flamethrower gate preserves another script's disabled state", function()
  local e, state = defense("flamethrower-turret")
  state.consumer.energy = 100; spinner_ticks(1,1)
  e.disabled_by_script = true; spinner_ticks(2,2)
  state.consumer.energy = 0; spinner_ticks(3,3)
  state.consumer.energy = 100; spinner_ticks(4,4)
  assert(e.disabled_by_script)
end)
test("powered defense rescan replaces consumers without leaking old entities", function()
  local e, state = defense("iw-electric-fence")
  local old = state.consumer
  config()
  assert(not old.valid and state.consumer.valid and state.consumer ~= old)
  assert(count_entities("iw-fence-power") == 1)
end)
test("powered defense removal and surface clear remove consumers", function()
  local e, state = defense("iw-electric-fence")
  local child = state.consumer
  handlers.on_player_mined_entity{entity = e}
  assert(not child.valid and not storage.iw_powered_defenses[e.unit_number])
  local a, b = defense("flamethrower-turret")
  handlers.on_pre_surface_cleared{surface_index = surface.index}
  assert(not b.consumer.valid and not storage.iw_powered_defenses[a.unit_number])
end)
test("cloned consumer is discarded and owner gets exactly one new consumer", function()
  local e, state = defense("iw-electric-fence")
  local duplicate = surface.create_entity{name = "iw-fence-power", position = e.position, force = player_force}
  handlers.on_entity_cloned{source = state.consumer, destination = duplicate}
  assert(not duplicate.valid and count_entities("iw-fence-power") == 1)
end)

test("a horizontal spinner bank pushes perpendicular once per pulse", function()
  local a,b,c=spinner_entity(),spinner_entity(),spinner_entity()
  a.position={x=-1,y=0};b.position={x=0,y=0};c.position={x=1,y=0}
  for _,e in ipairs({a,b,c})do e.burner.remaining_burning_fuel=100 end
  local player=character(0.6,0.8)
  spinner_ticks(1,30)
  near(player.position.x,0.6);near(player.position.y,1.15)
  assert(player.shoves==1)
end)
test("a vertical spinner bank pushes sideways away from its column", function()
  local a,b=spinner_entity(),spinner_entity()
  a.position={x=0,y=-1};b.position={x=0,y=1}
  a.burner.remaining_burning_fuel=100;b.burner.remaining_burning_fuel=100
  local player=character(-0.8,0.6)
  spinner_ticks(1,30)
  near(player.position.x,-1.15);near(player.position.y,0.6)
  assert(player.shoves==1)
end)
test("single-spinner diagonal shove stays exactly on the radial line", function()
  local e=spinner_entity();e.burner.remaining_burning_fuel=100
  local player=character(1,1)
  spinner_ticks(1,30)
  near(player.position.x,1+0.35/math.sqrt(2));near(player.position.y,player.position.x)
end)
test("blocked shove tries shorter straight steps without a side search", function()
  local e=spinner_entity();e.burner.remaining_burning_fuel=100
  local player=character(1,0)
  function player.teleport(p,_,_,_,check)
    assert(check=="manual");near(p.y,0)
    if p.x>1.2 then return false end
    player.position=p;player.shoves=(player.shoves or 0)+1;return true
  end
  local old=surface.find_non_colliding_position
  surface.find_non_colliding_position=function()error("must not search sideways")end
  spinner_ticks(1,30)
  surface.find_non_colliding_position=old
  near(player.position.x,1.15);near(player.position.y,0)
end)
local function wire_at(x,y,ghost)
  next_id=next_id+1
  local e={name=ghost and "entity-ghost" or "iw-barbed-wire",type=ghost and "entity-ghost" or "wall",
    ghost_name=ghost and "iw-barbed-wire" or nil,unit_number=next_id,valid=true,
    position={x=x,y=y},surface=surface,force=player_force,disabled_by_script=false}
  surface.entities[#surface.entities+1]=e
  handlers.on_built_entity{entity=e}
  return e,storage.iw_wire_visuals[e.unit_number]
end
test("all sixteen barbed-wire neighbor combinations select one correct tile", function()
  local dirs={{0,-1,1},{1,0,2},{0,1,4},{-1,0,8}}
  for mask=0,15 do
    local x=mask*10
    local e,state=wire_at(x,0)
    for _,d in ipairs(dirs)do if math.floor(mask/d[3])%2==1 then wire_at(x+d[1],d[2])end end
    assert(state.mask==mask and state.render.sprite=="iw-barbed-wire-mask-"..mask)
  end
  local states,objects=0,0
  for _ in pairs(storage.iw_wire_visuals)do states=states+1 end
  for _,o in ipairs(rendering.objects)do if o.valid then objects=objects+1 end end
  assert(objects==states)
end)
test("barbed-wire line endpoints update correctly when the middle is mined", function()
  local a,sa=wire_at(0,0);local b,sb=wire_at(1,0);local c,sc=wire_at(2,0)
  assert(sa.mask==2 and sb.mask==10 and sc.mask==8)
  handlers.on_player_mined_entity{entity=b}
  b.valid=false
  assert(sa.mask==0 and sc.mask==0 and not sb.render.valid)
end)
test("barbed-wire rescan replaces renders and preserves topology", function()
  local a,sa=wire_at(0,0);wire_at(1,0);wire_at(0,1)
  local old=sa.render
  config()
  local new=storage.iw_wire_visuals[a.unit_number]
  assert(not old.valid and new.mask==6 and new.render.valid)
end)
test("wire ghosts use the same joins and leave no extra render after revival", function()
  local ghost,sg=wire_at(0,0,true);wire_at(1,0)
  assert(sg.mask==2)
  ghost.valid=false
  local actual,sa=wire_at(0,0)
  tick(30)
  assert(not sg.render.valid and sa.mask==2)
  assert(storage.iw_wire_tiles['1:0:0']==actual.unit_number)
end)
test("barbed-wire surface clearing removes every rendered tile", function()
  local e,state=wire_at(0,0);wire_at(1,0)
  handlers.on_pre_surface_cleared{surface_index=surface.index}
  assert(not state.render.valid and next(storage.iw_wire_visuals)==nil)
end)
local function linked_fences()
  local a,sa=defense("iw-electric-fence")
  local b,sb=defense("iw-electric-fence");b.position={x=1.4,y=0}
  function a.get_wire_connector(id,create)assert(id==1 and not create);return {connections={{target={owner=b}}}}end
  function b.get_wire_connector(id,create)assert(id==1 and not create);return {connections={{target={owner=a}}}}end
  sa.consumer.energy=100;sb.consumer.energy=100
  return a,sa,b,sb
end
test("connected fence power lines shock along their actual span once", function()
  linked_fences()
  local target=contact_target(0.7,"character",player_force)
  target.position.y=0.1
  target.bounding_box={left_top={x=0.69,y=0.09},right_bottom={x=0.71,y=0.11}}
  spinner_ticks(1,60)
  near(target.received,40)
end)
test("unconnected poles do not invent an electric fence span", function()
  local a,sa=defense("iw-electric-fence")
  local b,sb=defense("iw-electric-fence");b.position={x=1.4,y=0}
  sa.consumer.energy=100;sb.consumer.energy=100
  local target=contact_target(0.7)
  target.position.y=0.1
  target.bounding_box={left_top={x=0.69,y=0.09},right_bottom={x=0.71,y=0.11}}
  spinner_ticks(1,60)
  near(target.received,0)
end)
test("wire-span shocks stop when both endpoint charges are empty", function()
  local a,sa,b,sb=linked_fences()
  sa.consumer.energy=0;sb.consumer.energy=0
  local target=contact_target(0.7)
  spinner_ticks(1,60)
  near(target.received,0)
end)

test("a diagonal spinner bank pushes directly away from the line", function()
  local a,b,c=spinner_entity(),spinner_entity(),spinner_entity()
  a.position={x=0,y=0};b.position={x=1,y=1};c.position={x=2,y=2}
  for _,e in ipairs({a,b,c})do e.burner.remaining_burning_fuel=100 end
  local player=character(1.3,0.7)
  spinner_ticks(1,30)
  near(player.position.x,1.3+0.35/math.sqrt(2));near(player.position.y,0.7-0.35/math.sqrt(2))
  assert(player.shoves==1)
end)
test("idle fence has base demand and no discharge effects", function()
  local e,state=defense("iw-electric-fence")
  state.consumer.energy=100
  spinner_ticks(1,60)
  near(state.consumer.power_usage*60,20000)
  assert(count_entities("iw-fence-discharge")==0 and count_entities("iw-fence-contact-sparks")==0)
end)
test("shock demand rises tenfold and expires after contact ends", function()
  local e,state=defense("iw-electric-fence")
  state.consumer.energy=100
  local target=contact_target(0.6)
  spinner_ticks(1,30)
  near(state.consumer.power_usage*60,200000)
  assert(count_entities("iw-fence-discharge")==1 and count_entities("iw-fence-contact-sparks")==1)
  target.position.x=5
  spinner_ticks(31,59);near(state.consumer.power_usage*60,200000)
  spinner_ticks(60,60);near(state.consumer.power_usage*60,20000)
  near(target.received,20)
end)
test("continuous contact renews demand and pulses effects only twice per second", function()
  local e,state=defense("iw-electric-fence")
  state.consumer.energy=100;contact_target(0.6)
  spinner_ticks(1,90)
  near(state.consumer.power_usage*60,200000)
  assert(count_entities("iw-fence-discharge")==3 and count_entities("iw-fence-contact-sparks")==3)
end)
test("multiple targets do not multiply pole demand or audible pulses", function()
  local e,state=defense("iw-electric-fence")
  state.consumer.energy=100
  contact_target(0.6);contact_target(-0.6,"character",player_force)
  spinner_ticks(1,30)
  near(state.consumer.power_usage*60,200000)
  assert(count_entities("iw-fence-discharge")==1 and count_entities("iw-fence-contact-sparks")==2)
end)
test("shared wire contact sparks once but activates both powered endpoints", function()
  local a,sa,b,sb=linked_fences()
  local target=contact_target(0.7)
  target.position.y=0.1
  target.bounding_box={left_top={x=0.69,y=0.09},right_bottom={x=0.71,y=0.11}}
  spinner_ticks(1,30)
  near(target.received,20)
  near(sa.consumer.power_usage*60,200000);near(sb.consumer.power_usage*60,200000)
  assert(count_entities("iw-fence-contact-sparks")==1 and count_entities("iw-fence-discharge")==2)
end)
test("unpowered contact emits no sparks and retains idle demand", function()
  local e,state=defense("iw-electric-fence");contact_target(0.6)
  spinner_ticks(1,60)
  near(state.consumer.power_usage*60,20000)
  assert(count_entities("iw-fence-discharge")==0 and count_entities("iw-fence-contact-sparks")==0)
end)
test("configuration migration restores active fence demand on its new consumer", function()
  local e,state=defense("iw-electric-fence")
  state.consumer.energy=100;contact_target(0.6);spinner_ticks(1,30)
  local old=state.consumer
  config()
  assert(not old.valid and state.consumer.valid)
  near(state.consumer.power_usage*60,200000)
  state.consumer.energy=0;spinner_ticks(31,60)
  near(state.consumer.power_usage*60,20000)
end)
test("contact sparks survive a lethal shock without reading invalid target", function()
  local e,state=defense("iw-electric-fence")
  state.consumer.energy=100
  local target=contact_target(0.6)
  function target.damage()target.valid=false end
  spinner_ticks(1,30)
  assert(not target.valid and count_entities("iw-fence-contact-sparks")==1)
  near(state.consumer.power_usage*60,200000)
end)
test("mining entities without unit numbers preserves tracked defenses", function()
  local spinner=spinner_entity()
  local fence,state=defense("iw-electric-fence")
  local fire=holder();build(fire)
  for _,kind in ipairs({"tree","simple-entity","entity-ghost"}) do
    local entity=surface.create_entity{name=kind,position={x=10,y=10},force=player_force}
    entity.type=kind
    assert(entity.unit_number==nil)
    handlers.on_player_mined_entity{entity=entity}
    handlers.on_robot_mined_entity{entity=entity}
    handlers.script_raised_destroy{entity=entity}
    handlers.on_entity_died{entity=entity,name=defines.events.on_entity_died}
  end
  assert(storage.iw_spinners[spinner.unit_number])
  assert(storage.iw_powered_defenses[fence.unit_number]==state and state.consumer.valid)
  assert(storage.fires[fire.unit_number])
  handlers.on_player_mined_entity{entity=spinner}
  assert(storage.iw_spinners[spinner.unit_number]==nil)
end)
test("fire pits leave every structure and vehicle type unharmed", function()
  local fire=holder();build(fire)
  local structures={}
  for _,kind in ipairs({"container","assembling-machine","inserter","wall","electric-pole",
    "ammo-turret","fluid-turret","turret","mining-drill","radar","car","spider-vehicle",
    "tree","simple-entity","unit-spawner","roboport"}) do
    structures[#structures+1]=target(fire.position.x,0,kind)
  end
  local unit=target(fire.position.x,0,"unit")
  local player=target(fire.position.x,0,"character")
  tick(60)
  for _,entity in ipairs(structures) do near(entity.received,0) end
  near(unit.received,26);near(player.received,26)
end)
test("dud fire burns creatures and players but spares structures", function()
  local trap=trap_entity("iw-claymore")
  local unit=trap_target(0,0)
  local player=trap_target(0,0,player_force);player.type="character"
  local chest=trap_target(0,0);chest.type="container"
  local wall=trap_target(0,0);wall.type="wall"
  local outside=trap_target(1,0)
  trigger_trap(trap,2);tick(60)
  near(unit.received,13);near(player.received,13)
  near(chest.received,0);near(wall.received,0);near(outside.received,0)
end)
test("dud fire final interval stops precisely at five seconds", function()
  local trap=trap_entity("iw-claymore")
  local unit=trap_target(0,0)
  trigger_trap(trap,2);tick(270)
  local flame=surface.find_entities_filtered{name="iw-claymore-dud-fire"}[1]
  flame.valid=false
  tick(300);near(unit.received,65)
  assert(#storage.iw_dud_fires==0)
  tick(360);near(unit.received,65)
end)
test("dud fire early destruction stops damage", function()
  local trap=trap_entity("iw-claymore")
  local unit=trap_target(0,0)
  trigger_trap(trap,2);tick(30)
  surface.find_entities_filtered{name="iw-claymore-dud-fire"}[1].valid=false
  tick(60);near(unit.received,6.5)
  assert(#storage.iw_dud_fires==0)
end)
test("dud fire configuration rescan preserves expiry and avoids duplicate damage", function()
  local trap=trap_entity("iw-claymore")
  local unit=trap_target(0,0)
  trigger_trap(trap,2);tick(120)
  config()
  assert(#storage.iw_dud_fires==1 and storage.iw_dud_fires[1].expires==300)
  tick(300);near(unit.received,65)
end)
test("dud fire surface cleanup removes tracked flames", function()
  local trap=trap_entity("iw-claymore")
  trigger_trap(trap,2)
  handlers.on_pre_surface_cleared{surface_index=1}
  assert(#storage.iw_dud_fires==0)
end)
print(tests .. " runtime regression tests passed")
