local profiler={}
-- Transient output-only timing state: never serialize LuaProfiler or use
-- timings to change simulation behavior. Loading ends a running sample.
local session
local FLYING={"construction-robot","logistic-robot","combat-robot","capture-robot","projectile","artillery-projectile"}
local function count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
local function reply(player,message)
  if player and player.valid then player.print(message) else game.print(message) end
end
function profiler.measure(name,fn,...)
  if not session then return fn(...) end
  local entry=session.entries[name]
  if not entry then entry={timer=game.create_profiler(true),calls=0};session.entries[name]=entry end
  entry.calls=entry.calls+1
  local timer=game.create_profiler()
  local result=fn(...)
  timer.stop();entry.timer.add(timer)
  return result
end
function profiler.counter(name,amount)
  if session then session.counters[name]=(session.counters[name] or 0)+amount end
end
function profiler.snapshot(player)
  local state=storage.cave_walls or {}
  reply(player,"Cave Walls: checks "..(storage.cave_wall_checks_enabled~=false and "ON" or "OFF")
    .." | registered turrets="..count(storage.cave_wall_turrets)
    .." | tracked flame streams="..count(storage.cave_wall_flames and storage.cave_wall_flames.streams)
    .." | tracked flying="..count(state.flying)
    .." | pending discovery surfaces="..count(state.flying_discovery)
    .." | sweep chunks="..#(state.chunks or {}))
  for _,surface in pairs(game.surfaces) do
    local helpers=surface.count_entities_filtered{name="cave-wall-collision"}
    if helpers>0 or (state.surfaces and state.surfaces[surface.index]) then
      reply(player,surface.name..": collision helpers="..helpers
        ..", flying entities="..surface.count_entities_filtered{type=FLYING}
        ..", registered wall surface="..tostring(state.surfaces and state.surfaces[surface.index]==true))
    end
  end
end
local function report()
  if not session then return end
  local finished=session;session=nil
  local player=finished.player_index and game.get_player(finished.player_index)
  local ticks=math.max(1,game.tick-finished.start_tick)
  reply(player,"Cave Walls timing report: "..ticks.." simulation ticks. Values are milliseconds. Wall sync includes native helper creation/deletion. Nested/reentrant sections can overlap; do not sum them.")
  local names={};for name in pairs(finished.entries) do names[#names+1]=name end;table.sort(names)
  for _,name in ipairs(names) do
    local entry=finished.entries[name]
    local average=game.create_profiler(true);average.add(entry.timer);average.divide(entry.calls)
    local per_tick=game.create_profiler(true);per_tick.add(entry.timer);per_tick.divide(ticks)
    reply(player,{"",name," | calls=",entry.calls," | total=",entry.timer,
      " | average/call=",average," | average/game tick=",per_tick})
  end
  if #names==0 then reply(player,"No measured work occurred (checks may be OFF).") end
  names={};for name in pairs(finished.counters) do names[#names+1]=name end;table.sort(names)
  for _,name in ipairs(names) do reply(player,name..": "..finished.counters[name]) end
  profiler.snapshot(player)
  reply(player,"This measures Cave Walls script work, including sync calls from Cruel Rain. Native collision/pathfinding costs between events are not captured. Use F4 -> show-time-usage and send that view too if this report is small but the game still lags. Reloading ends a sample; diagnostics never remove walls or alter weapon behavior.")
end
function profiler.tick()
  if session and game.tick>=session.end_tick then report() end
end
function profiler.command(command)
  local player=command.player_index and game.get_player(command.player_index)
  local action,argument=(command.parameter or "status"):match("^%s*(%S+)%s*(.-)%s*$")
  action=action and action:lower() or "status"
  if action=="status" then profiler.snapshot(player);return end
  if player and not player.admin then reply(player,"Only an admin can start or stop wall timing samples.");return end
  if action=="start" then
    local seconds=argument=="" and 10 or tonumber(argument)
    if not seconds or seconds<1 or seconds>60 or seconds~=math.floor(seconds) then
      reply(player,"Use /cave-walls-diagnostics start 10 (whole seconds from 1 to 60).");return
    end
    session={start_tick=game.tick,end_tick=game.tick+seconds*60,player_index=command.player_index,entries={},counters={}}
    reply(player,"Sampling Cave Walls for "..seconds.." simulation seconds. Reproduce the lag; the report prints automatically. Reloading ends the sample.")
  elseif action=="stop" then
    if session then report() else reply(player,"No wall timing sample is running.") end
  else reply(player,"Usage: /cave-walls-diagnostics start 10 | stop | status") end
end
return profiler
