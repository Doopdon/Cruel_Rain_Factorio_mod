-- Factorio retains one handler per event/interval for each mod. Share one
-- registration while letting the cave, wall and weather components compose.
local events={}
local handlers={event={},nth_tick={},init={},configuration_changed={}}
local function dispatch(list,event)
  for _,handler in ipairs(list) do handler(event) end
end
local function lifecycle(name,handler)
  local list=handlers[name]
  list[#list+1]=handler
  script["on_"..name](function(event) dispatch(list,event) end)
end
function events.on_init(handler) lifecycle("init",handler) end
function events.on_configuration_changed(handler) lifecycle("configuration_changed",handler) end
local function register(kind,keys,handler)
  if type(keys)~="table" then keys={keys} end
  for _,key in ipairs(keys) do
    local list=handlers[kind][key]
    if not list then list={};handlers[kind][key]=list end
    list[#list+1]=handler
    script[kind=="event" and "on_event" or "on_nth_tick"](key,function(event) dispatch(list,event) end)
  end
end
function events.on_event(ids,handler) register("event",ids,handler) end
function events.on_nth_tick(intervals,handler) register("nth_tick",intervals,handler) end
return events
