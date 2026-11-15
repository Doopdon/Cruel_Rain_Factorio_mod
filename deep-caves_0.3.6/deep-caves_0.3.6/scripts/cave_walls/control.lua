local script=require("scripts.events")
local checks=require("scripts.cave_walls.checks")
local profiler=require("scripts.cave_walls.profiler")
local walls=require("scripts.cave_walls.walls")
local flames=require("scripts.cave_walls.flames")
local guns=require("scripts.cave_walls.gun-targeting")
script.on_init(function() walls.rebuild();guns.rebuild();guns.tick() end)
script.on_configuration_changed(function(e)
  walls.rebuild();guns.rebuild();guns.tick()
  if e.mod_changes and (e.mod_changes["cave-walls"] or e.mod_changes["deep-caves"]) then flames.upgrade() end
end)
script.on_event(defines.events.on_tick,function(e)
  profiler.tick()
  if not checks.enabled() then return end
  local checked=walls.tick(e)
  if checked then guns.scan(checked.surface,checked.area) end
  flames.tick()
  guns.tick()
end)
local function select_area(event,erase)
  if event.item~="cave-wall-brush" then return end
  local player=game.get_player(event.player_index)
  -- Selection events supply a LuaSurface directly, not a surface_index.
  local surface=event.surface or (player and player.surface)
  if not (surface and surface.valid) then return end
  local count,reason=walls.paint(surface,event.area,erase)
  guns.tick();flames.tick()
  if player then
    if reason then player.print({"cave-walls.too-large"})
    elseif count>0 then player.print({erase and "cave-walls.erased" or "cave-walls.painted",count}) end
  end
end
script.on_event(defines.events.on_player_selected_area,function(e) select_area(e,false) end)
script.on_event(defines.events.on_player_alt_selected_area,function(e) select_area(e,true) end)
script.on_event(defines.events.on_player_reverse_selected_area,function(e) select_area(e,true) end)
script.on_event(defines.events.on_chunk_generated,function(e)
  walls.chunk_generated(e.surface,e.area)
end)
remote.add_interface("cave-walls",{
  sync_area=function(surface_index,area)
    local surface=game.surfaces[surface_index]
    if surface then walls.sync(surface,area);guns.scan(surface,area) end
  end,
  register_surface=function(surface_index) local surface=game.surfaces[surface_index];if surface then walls.sync(surface) end end
})

script.on_event(defines.events.on_script_trigger_effect,function(e)
  profiler.measure("Flame trigger effects",flames.effect,e)
  if e.effect_id=="cave-wall-bullet-created" or e.effect_id=="cave-wall-flying-created" then
    walls.track_bullet(e.target_entity)
    walls.track_bullet(e.source_entity)
  end
end)

-- Check newly built turrets before their first native firing update.
script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity,
  defines.events.script_raised_built,defines.events.script_raised_revive},function(e)
  local entity=e.entity
  if entity and entity.valid and (entity.name=="gun-turret" or entity.name=="laser-turret"
    or entity.name=="flamethrower-turret") then guns.track(entity);guns.tick() end
end)

commands.add_command("cave-walls-checks","Toggle all Cave Walls runtime checks: off, on, status. Admin required for changes.",require("scripts.cave_walls.diagnostics").command)

commands.add_command("cave-walls-diagnostics","Profile wall scripts: start 10, stop, status.",profiler.command)
