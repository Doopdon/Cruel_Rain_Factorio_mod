local diagnostics={}
-- Profilers are intentionally transient: LuaProfiler cannot be serialized.
-- Timings are output only and never determine gameplay or ordering.
local session
function diagnostics.background_enabled()
  return storage.deep_caves.background_preparation_enabled~=false
end
function diagnostics.measure(name,fn,...)
  if not session then return fn(...) end
  local entry=session.entries[name]
  if not entry then entry={timer=game.create_profiler(true),calls=0};session.entries[name]=entry end
  entry.calls=entry.calls+1
  local timer=game.create_profiler()
  local result=fn(...)
  timer.stop();entry.timer.add(timer)
  return result
end
local function count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
local function reply(player,message)
  if player and player.valid then player.print(message) else game.print(message) end
end
function diagnostics.snapshot(player)
  local state=storage.deep_caves
  reply(player,"Cruel Rain: background preparation "..(diagnostics.background_enabled() and "ON" or "OFF")
    .." | ramps "..count(state.portals).." | power links "..count(state.power_links)
    .." | pending surface columns "..count(state.surface_returns and state.surface_returns.pending))
  for _,surface in pairs(game.surfaces) do
    if surface.name=="nauvis" or surface.name:match("^deep%-caves%-level%-%d+$") then
      local chunks,ramps,unpaired=0,0,0
      for chunk in surface.get_chunks() do if surface.is_chunk_generated(chunk) then chunks=chunks+1 end end
      for _,record in pairs(state.portals) do
        if record.entity and record.entity.valid and record.entity.surface==surface then
          ramps=ramps+1;if not record.pair_unit then unpaired=unpaired+1 end
        end
      end
      reply(player,surface.name..": chunks="..chunks..", ramps="..ramps..", unpaired="..unpaired
        ..", wall helpers="..surface.count_entities_filtered{name="cave-wall-collision"}
        ..", enemy units="..surface.count_entities_filtered{force="enemy",type="unit"})
    end
  end
end
local function report()
  if not session then return end
  local finished=session;session=nil
  local player=finished.player_index and game.get_player(finished.player_index)
  local ticks=math.max(1,game.tick-finished.start_tick)
  reply(player,"Cruel Rain timing report: "..ticks.." simulation ticks. Values are milliseconds. Sections can overlap when forced generation runs inside pairing/travel; do not sum them.")
  local names={};for name in pairs(finished.entries) do names[#names+1]=name end;table.sort(names)
  for _,name in ipairs(names) do
    local entry=finished.entries[name]
    local average=game.create_profiler(true);average.add(entry.timer);average.divide(entry.calls)
    local per_tick=game.create_profiler(true);per_tick.add(entry.timer);per_tick.divide(ticks)
    reply(player,{"",name," | calls=",entry.calls," | total=",entry.timer," | average/call=",average," | average/game tick=",per_tick})
  end
  if #names==0 then reply(player,"No measured work occurred during this sample.") end
  diagnostics.snapshot(player)
  reply(player,"This report measures Cruel Rain script work (including calls into Cave Walls), not rendering, engine entity updates or other mods. Use F4 -> show-time-usage for the engine breakdown.")
end
function diagnostics.tick()
  if session and game.tick>=session.end_tick then report() end
end
function diagnostics.command(command)
  local player=command.player_index and game.get_player(command.player_index)
  local action,argument=(command.parameter or "status"):match("^%s*(%S+)%s*(.-)%s*$")
  action=action and action:lower() or "status"
  if action=="status" then diagnostics.snapshot(player);return end
  if player and not player.admin then reply(player,"Only an admin can start or stop the cave timing sample.");return end
  if action=="start" then
    local seconds=10
    if argument~="" then seconds=tonumber(argument) end
    if not seconds or seconds<1 or seconds>60 or seconds~=math.floor(seconds) then
      reply(player,"Use /cave-diagnostics start 10 (whole seconds from 1 to 60).");return
    end
    session={start_tick=game.tick,end_tick=game.tick+seconds*60,player_index=command.player_index,entries={}}
    reply(player,"Sampling Cruel Rain for "..seconds.." simulation seconds. Reproduce the lag; the report prints automatically. Reloading ends the transient sample.")
  elseif action=="stop" then
    if session then report() else reply(player,"No cave timing sample is running.") end
  else reply(player,"Usage: /cave-diagnostics start 10 | stop | status") end
end
function diagnostics.background_command(command)
  local player=command.player_index and game.get_player(command.player_index)
  local action=(command.parameter or "status"):match("^%s*(.-)%s*$"):lower()
  if action=="status" or action=="" then
    reply(player,"Cruel Rain background preparation: "..(diagnostics.background_enabled() and "ON" or "OFF"));return
  end
  if action~="on" and action~="off" then reply(player,"Usage: /cave-background off | on | status");return end
  if player and not player.admin then reply(player,"Only an admin can toggle background preparation.");return end
  storage.deep_caves.background_preparation_enabled=action=="on"
  reply(player,"Cruel Rain background preparation "..action:upper()..". Existing paired ramps, power and inventories continue working. Walking onto an unpaired ramp still prepares its destination. Normal exploration still generates terrain.")
end
return diagnostics
