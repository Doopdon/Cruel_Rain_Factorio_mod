local script=require("scripts.events")
local storm=require("scripts.weather.storm")
local exposure=require("scripts.weather.exposure")
script.on_init(function() storm.initialize();storm.sync_all() end)
local function configuration_changed()
  storm.initialize();storm.clear_views();storm.sync_all()
end
script.on_configuration_changed(configuration_changed)
script.on_event(defines.events.on_tick,storm.tick)
script.on_nth_tick(6,storm.sync_all)
script.on_nth_tick(60,exposure.tick)
local function refresh(event)
  local player=game.get_player(event.player_index)
  if player then storm.sync_player(player) end
end
script.on_event({defines.events.on_player_joined_game,defines.events.on_player_changed_surface},refresh)
script.on_event(defines.events.on_player_left_game,function(event)
  local state=storage.surface_thunderstorm
  storm.destroy_view(state.views[event.player_index]);state.views[event.player_index]=nil
  state.sheltered_rain[event.player_index]=nil
end)
script.on_event(defines.events.on_player_removed,function(event)
  local state=storage.surface_thunderstorm
  storm.destroy_view(state.views[event.player_index]);state.views[event.player_index]=nil
  state.sheltered_rain[event.player_index]=nil
end)
script.on_event(defines.events.on_runtime_mod_setting_changed,function(event)
  if event.setting=="surface-thunderstorm-enabled" then
    local state=storage.surface_thunderstorm
    state.override=nil;state.flash_start=nil;state.pending_thunder={}
    state.next_strike=game.tick+180
    storm.clear_views()
  end
  storm.sync_all()
end)
commands.add_command("surface-storm","Surface Thunderstorm: on, off, lightning, or status.",function(command)
  local player=command.player_index and game.get_player(command.player_index)
  local param=string.lower(command.parameter or "status")
  local function say(text) if player then player.print(text) else game.print(text) end end
  if param=="status" then say("Surface thunderstorm: "..(storm.enabled() and "ON (Nauvis only)" or "OFF"));return end
  if player and not player.admin then say("Only an admin can change the weather.");return end
  if param=="on" or param=="off" then
    local state=storage.surface_thunderstorm
    state.override=param=="on";state.flash_start=nil;state.pending_thunder={}
    state.next_strike=game.tick+180
    storm.clear_views();storm.sync_all()
    say("Surface thunderstorm "..string.upper(param)..".")
  elseif param=="lightning" then
    storm.sync_all();storm.strike();say("Lightning flash triggered.")
  else say("Use /surface-storm on, off, lightning, or status.") end
end)

-- Read-only clock for cave openings and other sheltered weather integrations.
remote.add_interface("surface-thunderstorm",{
 get_weather=function()
   local enabled=storm.enabled()
   return {enabled=enabled,flash=enabled and storm.flash_strength(game.tick) or 0}
 end
})
return {configuration_changed=configuration_changed}
