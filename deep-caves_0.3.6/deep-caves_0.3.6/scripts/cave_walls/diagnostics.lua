local checks=require("scripts.cave_walls.checks")
local walls=require("scripts.cave_walls.walls")
local guns=require("scripts.cave_walls.gun-targeting")
local flames=require("scripts.cave_walls.flames")
local diagnostics={}
local function count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
function diagnostics.run(action)
  if action=="off" then
    if not checks.enabled() then return "Cave Walls: checks are already OFF." end
    storage.cave_wall_checks_enabled=false
    guns.suspend();flames.suspend()
    if storage.cave_walls then storage.cave_walls.previous={};storage.cave_walls.flying={} end
    return "Cave Walls: all runtime checks OFF (all levels). Robots and shots can cross walls. Existing collision helpers remain. Run /cave-walls-checks on to restore."
  elseif action=="on" then
    if checks.enabled() then return "Cave Walls: checks are already ON." end
    storage.cave_wall_checks_enabled=true
    walls.rebuild();guns.rebuild();guns.tick()
    return "Cave Walls: checks ON; wall collisions and turret registry synchronized."
  elseif action=="status" or action=="" then
    local state=storage.cave_walls or {}
    local helpers=0
    for _,surface in pairs(game.surfaces) do helpers=helpers+surface.count_entities_filtered{name="cave-wall-collision"} end
    return "Cave Walls: checks "..(checks.enabled() and "ON" or "OFF")
      .." | wall surfaces: "..count(state.surfaces).." | collision helpers: "..helpers
      .." | registered turrets: "..count(storage.cave_wall_turrets)
      .." | sweep chunks: "..#(state.chunks or {})..". OFF pauses scripts, not native entities or Cruel Rain generation."
  end
  return "Usage: /cave-walls-checks off | on | status"
end
function diagnostics.command(command)
  local player=command.player_index and game.get_player(command.player_index)
  local action=string.lower((command.parameter or ""):match("^%s*(.-)%s*$"))
  local function reply(message) if player then player.print(message) else game.print(message) end end
  if (action=="on" or action=="off") and player and not player.admin then
    reply("Only an admin can toggle Cave Walls checks.");return
  end
  reply(diagnostics.run(action))
end
return diagnostics
