-- All three components share one dispatcher; duplicate tick/chunk/lifecycle
-- registrations compose rather than overwriting another component's work.
local script=require("scripts.events")
local integration=require("scripts.integration")
script.on_init(integration.adopt)
script.on_configuration_changed(integration.adopt)
require("scripts.cave_walls.control")
require("scripts.weather.control")

local generation = require("scripts.generation")
local surfaces = require("scripts.surfaces")
local portals = require("scripts.portals")
local navigation = require("scripts.navigation")
local daylight = require("scripts.daylight")
local cargo = require("scripts.cargo")
local puddles = require("scripts.puddles")
local flooding = require("scripts.flooding")
local features = require("scripts.features")
local wasteland = require("scripts.wasteland")
local walls = require("scripts.walls")
local diagnostics = require("scripts.diagnostics")
local drips = require("scripts.drips")
local spawn_checks = require("scripts.spawn_checks")
local fluids = require("scripts.fluids")
local ramp_gui = require("scripts.ramp_gui")
local silos = require("scripts.silos")

local function cave_depth(surface)
  return surfaces.depth_from_surface(surface)
end

script.on_init(function()
  portals.init_storage()
  surfaces.upgrade_darkness()
  wasteland.upgrade()
  local starting=portals.ensure_starting_entrance()
  -- Creating only the Nauvis endpoint leaves Cave 1 lazy and starter ores absent.
  if starting then portals.ensure_pair(starting) end
  portals.ensure_second_starting_entrance()
  portals.upgrade_entrance_density()
  features.ensure_level1_starter_resources()
  generation.upgrade_floor_textures()
  generation.upgrade_ground_mix()
  generation.upgrade_shallow_water()
  portals.enforce_depth_limit()
  navigation.upgrade()
  generation.upgrade_rocks()
  cargo.upgrade()
  portals.upgrade_surface_vents()
  portals.upgrade_integrated_power()
  fluids.upgrade()
  ramp_gui.reset()
  daylight.update()
  portals.upgrade_surface_returns()
  local converted=walls.upgrade()
  if converted>0 then game.print("Cruel Rain: converted "..converted.." void tiles to solid cave walls.") end
  features.queue_resources()
  features.queue_enemies()
  puddles.queue_existing()
  flooding.queue_existing()
end)

script.on_configuration_changed(function()
  portals.init_storage()
  surfaces.upgrade_darkness()
  storage.deep_caves.power_cache=nil
  storage.deep_caves.daylight_cache=nil
  wasteland.upgrade()
  portals.migrate_ramp_entities()
  portals.rebuild_registry()
  local starting=portals.ensure_starting_entrance()
  if starting then portals.ensure_pair(starting) end
  portals.ensure_second_starting_entrance()
  portals.upgrade_entrance_density()
  features.enforce_level1_safe_zone()
  features.ensure_level1_starter_resources()
  generation.upgrade_floor_textures()
  generation.upgrade_ground_mix()
  generation.upgrade_shallow_water()
  portals.enforce_depth_limit()
  navigation.upgrade()
  generation.upgrade_rocks()
  cargo.upgrade()
  portals.upgrade_surface_vents()
  portals.upgrade_integrated_power()
  fluids.upgrade()
  ramp_gui.reset()
  daylight.update()
  portals.upgrade_surface_returns()
  local converted=walls.upgrade()
  if converted>0 then game.print("Cruel Rain: converted "..converted.." void tiles to solid cave walls.") end
  features.queue_resources()
  features.queue_enemies()
  puddles.queue_existing()
  flooding.queue_existing()
end)

script.on_event(defines.events.on_chunk_generated, function(event)
  local surface = event.surface
  local depth = cave_depth(surface)

  if depth and depth>0 and depth<=surfaces.MAX_DEPTH then
    local seed = surfaces.seed_for_depth(depth)
    diagnostics.measure("Chunk terrain",generation.generate_chunk,surface,event.area,depth,seed)
    -- Every newly generated cave chunk gets its deterministic random-entrance
    -- roll. Previously pair_generation skipped this entire block while return
    -- ramps force-generated nearby chunks; those chunks never receive another
    -- on_chunk_generated event, so they stayed permanently entrance-free.
    diagnostics.measure("Chunk ramps",portals.spawn_random_entrance,surface,event.area,depth,seed)
    if (storage.deep_caves.pair_generation or 0) == 0 and depth==1 then
      portals.queue_surface_return(surface,event.area)
    end
    diagnostics.measure("Chunk resources and enemies",features.populate,surface,event.area,depth,seed)
    diagnostics.measure("Chunk rocks",generation.populate_rocks,surface,event.area,depth,seed)
  elseif surface.name == "nauvis" then
    local seed = surfaces.seed_for_depth(0)
    diagnostics.measure("Surface terrain",wasteland.process_chunk,surface,event.area,seed)
    diagnostics.measure("Surface ramps",portals.spawn_random_entrance,surface,event.area,0,seed)
  end
end)

script.on_nth_tick(10, function()
  if diagnostics.background_enabled() then
    diagnostics.measure("Background surface returns",portals.prepare_surface_returns)
    diagnostics.measure("Background ramp pairing",portals.prepare_return_ramps)
  end
  diagnostics.measure("Player travel and activation",portals.tick_players)
  diagnostics.measure("Depth display",navigation.update_all)
end)

script.on_nth_tick(3, function()
  diagnostics.measure("Ramp lighting and rain",daylight.update)
end)

script.on_nth_tick(5, function()
  diagnostics.measure("Ramp power transfer",portals.equalize_power)
  diagnostics.measure("Deep flooding migration",flooding.tick)
end)

commands.add_command("cave-info", "Print Cruel Rain debug information.", function(command)
  local player = game.get_player(command.player_index)
  if not player then return end
  local depth = cave_depth(player.surface)
  if depth == nil then
    player.print("This surface is not managed by Cruel Rain.")
  elseif depth == 0 then
    player.print("Depth 0: Nauvis")
  else
    local p = generation.params(depth)
    player.print(string.format(
      "Cave Level %d | chamber %.1f | tunnel %.1f | cell %.1f | bend %.1f",
      depth, p.chamber, p.tunnel, p.cell, p.bend
    ))
  end
end)

commands.add_command("cave-create-entrance", "Create a downward cave entrance near you (debug command).", function(command)
  local player = game.get_player(command.player_index)
  if not player or not player.admin then return end
  local depth = cave_depth(player.surface)
  if depth == nil then
    player.print("Cruel Rain only supports Nauvis and its cave surfaces.")
    return
  end
  if depth>=surfaces.MAX_DEPTH then player.print("Cave 5 is the final flooded level; no downward entrance can be created here.");return end
  local pos = player.surface.find_non_colliding_position(
    "deep-caves-ramp-down",
    {x = player.position.x + 4, y = player.position.y},
    12,
    0.5
  )
  if pos then
    portals.create_endpoint(player.surface, pos, "deep-caves-ramp-down", depth, depth + 1)
    player.print("Created a cave entrance to Level " .. (depth + 1) .. ".")
  else
    player.print("Could not find room for an entrance nearby.")
  end
end)

script.on_event(defines.events.on_gui_opened, portals.open_inventory)
script.on_event(defines.events.on_gui_click,ramp_gui.click)
script.on_event(defines.events.on_gui_closed,ramp_gui.closed)
script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity,
  defines.events.script_raised_built,defines.events.script_raised_revive},fluids.pipe_built)
script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity,
  defines.events.script_raised_built,defines.events.script_raised_revive},silos.built)
script.on_event(defines.events.on_entity_cloned,silos.built)

script.on_event(defines.events.on_tick,diagnostics.tick)
commands.add_command("cave-diagnostics","Profile cave scripts: start 10, stop, status.",diagnostics.command)
commands.add_command("cave-background","Toggle background ramp/return preparation: off, on, status.",diagnostics.background_command)
commands.add_command("cave-check-spawns","Inspect nearby ramps, nests, ores and broken links without generating terrain.",spawn_checks.command)

script.on_nth_tick(30,function() diagnostics.measure("Entrance puddle migration",puddles.tick) end)

-- Level 1 permits normal enemy expansion, except inside the small starter
-- nest-exclusion circle.  Deeper cave levels keep the density-controlled
-- behavior from previous builds, where native expansion is suppressed.
script.on_event(defines.events.on_biter_base_built,function(event)
  local entity=event.entity
  if not (entity and entity.valid) then return end
  local name=entity.surface.name
  if name=="deep-caves-level-1" then
    if features.in_level1_nest_safe_zone(entity.surface,entity.position) then entity.destroy() end
  elseif name:match("^deep%-caves%-level%-%d+$") then
    entity.destroy()
  end
end)

script.on_nth_tick(15,function() features.tick_resources() end)
script.on_nth_tick(60,function()
  features.tick_enemies();drips.tick();fluids.retry_pending()
end)
commands.add_command("cave-populate-resources","Scatter cave ores through already explored chunks over time.",function(command)
  if command.player_index and not game.players[command.player_index].admin then return end
  local count=features.queue_resources()
  local message="Cruel Rain: queued ore placement in "..count.." explored chunks."
  if command.player_index then game.players[command.player_index].print(message) else game.print(message) end
end)

commands.add_command("cave-populate-enemies","Apply current nest density to explored caves over time.",function(command)
  local player=command.player_index and game.get_player(command.player_index)
  if player and not player.admin then player.print("Only an admin can populate cave enemies.");return end
  local count=features.queue_enemies()
  local message="Cruel Rain: queued enemy placement in "..count.." explored chunks."
  if player then player.print(message) else game.print(message) end
end)

commands.add_command("cave-enemy-density","Print the active Cruel Rain enemy density and current cave nest counts.",function(command)
  local player=command.player_index and game.get_player(command.player_index)
  local density=settings.startup["deep-caves-enemy-density"].value
  local parts={"Cruel Rain enemy density = "..density.." (Startup setting)."}
  for depth=1,surfaces.MAX_DEPTH do
    local surface=game.surfaces[surfaces.name(depth)]
    if surface then
      parts[#parts+1]="L"..depth..": "..surface.count_entities_filtered{force="enemy",type="unit-spawner"}.." nests"
    end
  end
  local message=table.concat(parts,"  ")
  if player then player.print(message) else game.print(message) end
end)
