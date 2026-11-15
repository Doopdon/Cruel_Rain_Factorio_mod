-- Fast checks for event composition, helper recovery and weather audio logic.
local passed,failed=0,0
local function test(name,fn)
  local ok,err=pcall(fn)
  if ok then passed=passed+1;print("PASS "..name)
  else failed=failed+1;print("FAIL "..name..": "..tostring(err)) end
end
local function check(ok,message) assert(ok,message) end
test("shared lifecycle and tick handlers preserve all three components in order",function()
  local captured,seen={},{}
  script={}
  for _,name in ipairs({"on_init","on_configuration_changed","on_event","on_nth_tick"}) do
    script[name]=function(key,fn)
      if fn then captured[name..key]=fn else captured[name]=key end
    end
  end
  package.loaded["scripts.events"]=nil
  local events=require("scripts.events")
  for _,component in ipairs({"walls","weather","caves"}) do
    local function receive(event) seen[#seen+1]=component..":"..tostring(event and event.tick or 0) end
    events.on_init(receive);events.on_configuration_changed(receive)
    events.on_event(1,receive);events.on_nth_tick(60,receive)
  end
  for _,name in ipairs({"on_init","on_configuration_changed","on_event1","on_nth_tick60"}) do
    seen={};captured[name]{tick=60}
    check(table.concat(seen,",")=="walls:60,weather:60,caves:60","lost or reordered "..name)
  end
end)
test("array event registrations compose with individual registrations",function()
  local handlers,counts={},{0,0}
  script={on_event=function(id,fn) handlers[id]=fn end}
  package.loaded["scripts.events"]=nil
  local events=require("scripts.events")
  events.on_event({10,11},function() counts[1]=counts[1]+1 end)
  events.on_event(11,function() counts[2]=counts[2]+1 end)
  handlers[10]{};handlers[11]{}
  check(counts[1]==2 and counts[2]==1,"array registration overwrote a component")
end)
test("legacy wall helpers are recovered without duplicates or unrelated changes",function()
  local function entity(name,x)
    local e={name=name,valid=true,position={x=x,y=.5}}
    e.destroy=function() e.valid=false end
    return e
  end
  local collision=entity("cave-wall-collision",.5)
  local duplicate=entity("cave-wall-collision",.5)
  local visual=entity("cave-wall-visual",.5)
  storage={deep_caves={portals={}}}
  local core=storage.deep_caves
  game={surfaces={{index=7,find_entities_filtered=function() return {collision,duplicate,visual} end}}}
  package.loaded["scripts.integration"]=nil
  local integration=require("scripts.integration");integration.adopt()
  check(storage.cave_walls.blockers[7]["0:0"]==collision,"original collision helper lost")
  check(storage.cave_walls.visuals[7]["0:0"]==visual,"original visual helper lost")
  check(not duplicate.valid and collision.valid and visual.valid,"duplicate cleanup was incorrect")
  check(storage.deep_caves==core,"cave save state was replaced")
  local state=storage.cave_walls;integration.adopt()
  check(storage.cave_walls==state,"repeat recovery reset wall state")
end)
test("renamed vents route muffled rain and delayed thunder on Cave 1 only",function()
  local calls={}
  local vent={name="deep-caves-vent",valid=true,position={x=0,y=0}}
  local cave={name="deep-caves-level-1",valid=true}
  cave.find_entities_filtered=function(filter)
    local accepted=false
    for _,name in ipairs(filter.name) do if name==vent.name then accepted=true end end
    check(accepted,"weather still searches only the old ascent prototype")
    return {vent}
  end
  local player={connected=true,index=1,surface=cave,physical_surface=cave,physical_position={x=2,y=0}}
  player.play_sound=function(sound) calls[#calls+1]=sound.path end
  game={tick=100,connected_players={player},get_player=function() return player end}
  storage={surface_thunderstorm={override=true,views={},sheltered_rain={},next_strike=1000,pending_thunder={100}}}
  settings={get_player_settings=function() return {
    ["surface-thunderstorm-darkness"]={value=.45},["surface-thunderstorm-rain-intensity"]={value=1},
    ["surface-thunderstorm-lightning"]={value=true},["surface-thunderstorm-volume"]={value=.55}} end}
  package.loaded["scripts.weather.storm"]=nil
  local storm=require("scripts.weather.storm")
  storm.sync_player(player);storm.tick()
  check(calls[1]=="surface-thunderstorm-muffled-rain-a","vent rain was not routed")
  check(calls[2]=="surface-thunderstorm-muffled-thunder","vent thunder was not routed")
  player.surface={name="deep-caves-level-2",valid=true};player.physical_surface=player.surface
  check(storm.nearest_opening(player)==nil,"deeper cave transmitted surface weather")
  player.surface=cave;player.physical_surface=cave;storage.surface_thunderstorm.override=false
  check(storm.nearest_opening(player)==nil,"disabled storm transmitted vent audio")
end)
test("remote views suppress vent audio for a sheltered physical character",function()
  local cave={name="deep-caves-level-1",valid=true}
  local player={connected=true,physical_surface=cave,surface={name="nauvis",valid=true}}
  storage={surface_thunderstorm={override=true}}
  local storm=require("scripts.weather.storm")
  check(storm.nearest_opening(player)==nil,"remote camera transmitted cave sound")
end)
print(string.format("RESULT: %d passed, %d failed",passed,failed))
os.exit(failed==0 and 0 or 1)
