local checks=require("scripts.cave_walls.checks")
local profiler=require("scripts.cave_walls.profiler")
local walls = {}
local NAME = "cave-wall"
local FLYING_TYPES={ ["construction-robot"]=true,["logistic-robot"]=true,["combat-robot"]=true,["capture-robot"]=true,["projectile"]=true,["artillery-projectile"]=true }
local FLYING = {"construction-robot","logistic-robot","combat-robot","capture-robot","projectile","artillery-projectile"}
local function init()
  storage.cave_walls = storage.cave_walls or {surfaces={},originals={},previous={},blockers={},visuals={}}
  storage.cave_walls.blockers=storage.cave_walls.blockers or {}
  storage.cave_walls.visuals=storage.cave_walls.visuals or {}
  storage.cave_walls.flying=storage.cave_walls.flying or {}
  storage.cave_walls.flying_discovery=storage.cave_walls.flying_discovery or {}
  return storage.cave_walls
end
local function key(x,y) return x..":"..y end
-- Only an exposed edge needs a collision entity. Solid interiors are
-- inaccessible from the floor and are still wall tiles for flying/LOS checks.
local function exposed(surface,x,y)
  for dx=-1,1 do for dy=-1,1 do
    if dx~=0 or dy~=0 then
      local name=surface.get_tile(x+dx,y+dy).name
      if name~=NAME and name~="out-of-map" then return true end
    end
  end end
  return false
end
local function block(surface,x,y)
  if not checks.enabled() then return end
  local state=init()
  local list=state.blockers[surface.index] or {}
  local visuals=state.visuals[surface.index] or {}
  state.blockers[surface.index]=list
  state.visuals[surface.index]=visuals
  local k=key(x,y)
  if not exposed(surface,x,y) then
    local e=list[k];if e and e.valid then e.destroy() end;list[k]=nil
    local v=visuals[k];if v and v.valid then v.destroy() end;visuals[k]=nil
    return
  end
  if not (list[k] and list[k].valid) then
    local e=surface.create_entity{name="cave-wall-collision",position={x+.5,y+.5},force="neutral"}
    if e then e.destructible=false;list[k]=e end
  end
  if not (visuals[k] and visuals[k].valid) then
    local v=surface.create_entity{name="cave-wall-visual",position={x+.5,y+.5},force="neutral"}
    if v then v.destructible=false;visuals[k]=v end
  end
end
local function unblock(surface,x,y)
  local state=init()
  local list=state.blockers[surface.index]
  local visuals=state.visuals[surface.index]
  local k=key(x,y)
  if list and list[k] then if list[k].valid then list[k].destroy() end;list[k]=nil end
  if visuals and visuals[k] then if visuals[k].valid then visuals[k].destroy() end;visuals[k]=nil end
end
function walls.has_walls(surface) return init().surfaces[surface.index]==true end
function walls.register(surface)
  local state=init()
  if not state.surfaces[surface.index] then state.flying_discovery[surface.index]=true end
  state.surfaces[surface.index]=true
end
local function sync(surface,area)
  if not checks.enabled() then return end
  local state=init()
  local list=state.blockers[surface.index] or {}
  local visuals=state.visuals[surface.index] or {}
  state.blockers[surface.index]=list
  state.visuals[surface.index]=visuals
  local function clean(list,k,e)
    if e and (not e.valid or surface.get_tile(e.position).name~=NAME
      or not exposed(surface,math.floor(e.position.x),math.floor(e.position.y))) then
      if e.valid then e.destroy() end
      list[k]=nil
    end
  end
  if area then
    local a=area.left_top or area[1];local b=area.right_bottom or area[2]
    local ax,ay=a.x or a[1],a.y or a[2]
    local bx,by=b.x or b[1],b.y or b[2]
    for x=math.floor(ax),math.ceil(bx)-1 do
      for y=math.floor(ay),math.ceil(by)-1 do local k=key(x,y);clean(list,k,list[k]);clean(visuals,k,visuals[k]) end
    end
  else for k,e in pairs(list) do clean(list,k,e) end; for k,e in pairs(visuals) do clean(visuals,k,e) end end
  local tiles=surface.find_tiles_filtered{name=NAME,area=area}
  profiler.counter("Wall tiles inspected by sync",#tiles)
  for _,tile in ipairs(tiles) do walls.register(surface);block(surface,tile.position.x,tile.position.y) end
  if not area and #tiles==0 then state.surfaces[surface.index]=nil;state.previous[surface.index]=nil;state.visuals[surface.index]=nil end
end
function walls.sync(surface,area)
  return profiler.measure("Wall helper synchronization",sync,surface,area)
end
local function remember_chunk(surface,x,y)
  local state=init()
  state.chunks=state.chunks or {};state.chunk_keys=state.chunk_keys or {}
  local k=surface.index..":"..x..":"..y
  if not state.chunk_keys[k] then
    state.chunk_keys[k]=true
    state.chunks[#state.chunks+1]={surface=surface.index,x=x,y=y}
  end
end
function walls.chunk_generated(surface,area)
  remember_chunk(surface,math.floor(area.left_top.x/32),math.floor(area.left_top.y/32))
  walls.sync(surface,{left_top={x=area.left_top.x-1,y=area.left_top.y-1},
    right_bottom={x=area.right_bottom.x+1,y=area.right_bottom.y+1}})
end
function walls.rebuild()
  if not checks.enabled() then return end
  local state=init()
  state.surfaces={};state.previous={};state.chunks={};state.chunk_keys={};state.chunk_cursor=1
  state.flying={};state.flying_discovery={}
  state.visuals=state.visuals or {}
  for index in pairs(game.surfaces) do state.flying_discovery[index]=true end
  -- Prune dense legacy collision helpers once, then rebuild chunk by chunk.
  for index,list in pairs(state.blockers) do
    local surface=game.surfaces[index]
    for k,e in pairs(list) do
      if not surface or not e.valid or surface.get_tile(e.position).name~=NAME
        or not exposed(surface,math.floor(e.position.x),math.floor(e.position.y)) then
        if e.valid then e.destroy() end
        list[k]=nil
      end
    end
    if not surface then state.blockers[index]=nil end
  end
  for index,list in pairs(state.visuals) do
    local surface=game.surfaces[index]
    for k,e in pairs(list) do
      if not surface or not e.valid or surface.get_tile(e.position).name~=NAME
        or not exposed(surface,math.floor(e.position.x),math.floor(e.position.y)) then
        if e.valid then e.destroy() end
        list[k]=nil
      end
    end
    if not surface then state.visuals[index]=nil end
  end
  for _,surface in pairs(game.surfaces) do
    for chunk in surface.get_chunks() do if surface.is_chunk_generated(chunk) then
      remember_chunk(surface,chunk.x,chunk.y)
      walls.sync(surface,{{chunk.x*32,chunk.y*32},{chunk.x*32+32,chunk.y*32+32}})
    end end
  end
end
-- Batched changes preserve the painted terrain and existing entities.
-- Never remove entities: painting is terrain editing, not demolition.
function walls.paint(surface,area,erase)
  local state=init()
  local originals=state.originals[surface.index] or {}
  state.originals[surface.index]=originals
  local changes,restore={},{}
  local minx,miny=math.floor(area.left_top.x),math.floor(area.left_top.y)
  local maxx,maxy=math.ceil(area.right_bottom.x)-1,math.ceil(area.right_bottom.y)-1
  if (maxx-minx+1)*(maxy-miny+1)>65536 then return nil,"too-large" end
  for x=minx,maxx do for y=miny,maxy do
    -- Do not expand an unexplored map with a brush selection.
    if surface.is_chunk_generated{x=math.floor(x/32),y=math.floor(y/32)} then
      local tile=surface.get_tile(x,y)
      local k=key(x,y)
      if erase and tile.name==NAME then
        local old=originals[k]
        changes[#changes+1]={name=old and old.name or "stone-path",position={x,y}}
        restore[#restore+1]={position={x,y},old=old,key=k}
      elseif not erase and tile.name~=NAME then
        originals[k]={name=tile.name,hidden=surface.get_hidden_tile{x,y},double_hidden=surface.get_double_hidden_tile{x,y}}
        changes[#changes+1]={name=NAME,position={x,y}}
      end
    end
  end end
  if #changes>0 then
    surface.set_tiles(changes,false,false,false)
    for _,tile in ipairs(changes) do
      if tile.name==NAME then block(surface,tile.position[1],tile.position[2])
      else unblock(surface,tile.position[1],tile.position[2]) end
    end
    for _,entry in ipairs(restore) do
      local old=entry.old
      surface.set_hidden_tile(entry.position,old and old.hidden or nil)
      surface.set_double_hidden_tile(entry.position,old and old.double_hidden or nil)
      originals[entry.key]=nil
    end
    walls.sync(surface,{{minx-1,miny-1},{maxx+2,maxy+2}})
    walls.register(surface)
    -- Flying entities already over a newly painted wall are removed immediately.
    walls.tick_surface(surface)
    if erase and #surface.find_tiles_filtered{name=NAME,limit=1}==0 then
      state.surfaces[surface.index]=nil;state.previous[surface.index]=nil;state.visuals[surface.index]=nil
    end
  end
  return #changes
end
local function wall_at(surface,x,y) return surface.get_tile(x,y).name==NAME end
-- Exact grid traversal catches fast flying entities crossing a one-tile
-- wall without ending their tick inside it. Positions are ground projections.
function walls.crosses(surface,a,b)
  local x,y=math.floor(a.x),math.floor(a.y)
  local endx,endy=math.floor(b.x),math.floor(b.y)
  if wall_at(surface,x,y) then return true end
  local dx,dy=b.x-a.x,b.y-a.y
  local sx=dx>0 and 1 or dx<0 and -1 or 0
  local sy=dy>0 and 1 or dy<0 and -1 or 0
  local tx=dx==0 and math.huge or ((sx>0 and x+1 or x)-a.x)/dx
  local ty=dy==0 and math.huge or ((sy>0 and y+1 or y)-a.y)/dy
  local stepx=dx==0 and math.huge or 1/math.abs(dx)
  local stepy=dy==0 and math.huge or 1/math.abs(dy)
  while x~=endx or y~=endy do
    if tx<ty then x=x+sx;tx=tx+stepx
    elseif ty<tx then y=y+sy;ty=ty+stepy
    else
      -- A diagonal touching the exact corner also touches both side tiles.
      if wall_at(surface,x+sx,y) or wall_at(surface,x,y+sy) then return true end
      x=x+sx;y=y+sy;tx=tx+stepx;ty=ty+stepy
    end
    if wall_at(surface,x,y) then return true end
  end
  return false
end
function walls.track_flying(entity)
  if not checks.enabled() then return end
  if not (entity and entity.valid and FLYING_TYPES[entity.type]) then return end
  local state=init()
  local id=entity.unit_number and ("u"..entity.unit_number)
    or ("r"..script.register_on_object_destroyed(entity))
  if state.flying[id] then return end
  local p=entity.position
  state.flying[id]={entity=entity,previous={x=p.x,y=p.y},surface=entity.surface.index}
end
walls.track_bullet=walls.track_flying
local function process_flying(surface)
  local state=init()
  local processed={}
  for id,entry in pairs(state.flying) do
    local entity=entry.entity
    if not entity.valid then state.flying[id]=nil
    else
      local current=entity.surface
      if not surface or current==surface then
        if state.surfaces[current.index] then
          local p=entity.position
          local old=entry.surface==current.index and entry.previous
          processed[current.index]=(processed[current.index] or 0)+1
          if wall_at(current,math.floor(p.x),math.floor(p.y))
            or (old and walls.crosses(current,old,p)) then
            if entity.type=="projectile" or entity.type=="artillery-projectile" then entity.destroy()
            else local killed=entity.die(game.forces.neutral);if not killed and entity.valid then entity.destroy() end end
            state.flying[id]=nil
          else entry.previous={x=p.x,y=p.y};entry.surface=current.index end
        else entry.previous=nil;entry.surface=current.index end
      end
    end
  end
  for index,n in pairs(processed) do
    local current=game.surfaces[index]
    if current then profiler.counter("Flying objects processed ["..current.name.."]",n) end
  end
end
local function find_flying(surface) return surface.find_entities_filtered{type=FLYING} end
local function discover(surface)
  local entities=profiler.measure("Flying discovery search ["..surface.name.."]",find_flying,surface)
  for _,entity in ipairs(entities) do walls.track_flying(entity) end
end
function walls.tick_surface(surface)
  if not checks.enabled() then return end
  profiler.measure("Tracked flying wall crossing",process_flying,surface)
end
function walls.tick(event)
  if not checks.enabled() then return end
  local state=init()
  -- Amortize editor/script discovery: one generated chunk each half-second, never
  -- a repeating whole-map tile scan. Cruel Rain and the brush sync immediately.
  local chunks=state.chunks or {}
  local inspected
  if #chunks>0 and event.tick%30==0 then
    local cursor=state.chunk_cursor or 1
    if cursor>#chunks then cursor=1 end
    local chunk=chunks[cursor];state.chunk_cursor=cursor+1
    local surface=game.surfaces[chunk.surface]
    if surface and surface.is_chunk_generated{x=chunk.x,y=chunk.y} then
      local area={{chunk.x*32-1,chunk.y*32-1},{chunk.x*32+33,chunk.y*32+33}}
      walls.sync(surface,area);inspected={surface=surface,area=area}
    end
  end
  -- One migration/discovery surface per tick, then no repeating global scans.
  local index=next(state.flying_discovery)
  if index then
    state.flying_discovery[index]=nil
    local surface=game.surfaces[index]
    if surface then discover(surface) end
  end
  profiler.measure("Tracked flying wall crossing",process_flying)
  return inspected
end
return walls
