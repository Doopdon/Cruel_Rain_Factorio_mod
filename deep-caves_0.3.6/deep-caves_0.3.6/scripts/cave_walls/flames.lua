local checks=require("scripts.cave_walls.checks")
local profiler=require("scripts.cave_walls.profiler")
local flames={}
local walls=require("scripts.cave_walls.walls")
local function state()
  storage.cave_wall_flames=storage.cave_wall_flames or {pending={},streams={}}
  return storage.cave_wall_flames
end
function flames.effect(e)
  if not checks.enabled() then return end
  local s=state()
  if e.effect_id=="cave-wall-flame-source" then
    local p=e.source_position
    if p then s.pending[e.surface_index]={tick=e.tick,position={x=p.x,y=p.y}} end
  elseif e.effect_id=="cave-wall-flame-created" then
    local stream=e.source_entity or e.target_entity
    local source=s.pending[e.surface_index]
    s.pending[e.surface_index]=nil
    if not (stream and stream.valid and source and source.tick==e.tick) then return end
    local a=source.position
    local mid=stream.position
    local b={x=2*mid.x-a.x,y=2*mid.y-a.y}
    if walls.crosses(stream.surface,a,b) then stream.destroy();return end
    local id=script.register_on_object_destroyed(stream)
    s.streams[id]={entity=stream,a=a,b=b}
  end
end
function flames.tick()
  if not checks.enabled() then return end
  local s=state()
  for id,entry in pairs(s.streams) do
    local stream=entry.entity
    if not stream.valid then s.streams[id]=nil
    elseif walls.has_walls(stream.surface) then
      local mid=stream.position
      local b={x=2*mid.x-entry.a.x,y=2*mid.y-entry.a.y}
      if walls.crosses(stream.surface,entry.a,b) then stream.destroy();s.streams[id]=nil end
    end
  end
  -- The source/creation callbacks occur in the same native firing operation.
  for index,source in pairs(s.pending) do
    if source.tick<game.tick then s.pending[index]=nil end
  end
end
function flames.upgrade()
  if not checks.enabled() then return end
  -- Older native streams have no recorded muzzle. Remove this short-lived
  -- in-flight backlog once when updating, rather than let an old shot leak.
  for _,surface in pairs(game.surfaces) do
    for _,stream in ipairs(surface.find_entities_filtered{name="flamethrower-fire-stream"}) do stream.destroy() end
  end
end
function flames.suspend()
  storage.cave_wall_flames={pending={},streams={}}
end
local measured_tick=flames.tick
function flames.tick(...) return profiler.measure("Flame stream checks",measured_tick,...) end
return flames
