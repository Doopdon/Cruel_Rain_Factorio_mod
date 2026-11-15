local flooding={}
local generation=require("scripts.generation")
local surfaces=require("scripts.surfaces")
local walls=require("scripts.walls")
local TRANSIENT={unit=true,character=true,["construction-robot"]=true,["logistic-robot"]=true,["combat-robot"]=true,
  ["capture-robot"]=true,projectile=true,["artillery-projectile"]=true,stream=true,beam=true,explosion=true,
  corpse=true,["character-corpse"]=true,["item-entity"]=true,fire=true,["smoke-with-trigger"]=true}
function flooding.queue_existing()
  local state=storage.deep_caves
  if state.bottom_flood_version==1 or state.bottom_flood_queue then return end
  local queue={}
  for _,surface in pairs(game.surfaces) do
    local depth=surfaces.depth_from_surface(surface)
    if depth==surfaces.MAX_DEPTH then
      for chunk in surface.get_chunks() do
        if surface.is_chunk_generated(chunk) then queue[#queue+1]={surface=surface.index,x=chunk.x,y=chunk.y} end
      end
    end
  end
  state.bottom_flood_queue=queue;state.bottom_flood_cursor=1
end
function flooding.chunk(surface,x,y)
  local depth=surfaces.depth_from_surface(surface);if depth~=surfaces.MAX_DEPTH then return end
  local minx,miny=x*32,y*32;local maxx,maxy=minx+32,miny+32
  local area={{minx,miny},{maxx,maxy}}
  local occupied={}
  for _,entity in ipairs(surface.find_entities_filtered{area=area}) do
    if entity.valid and entity.name~="cave-wall-collision" and not TRANSIENT[entity.type] then
      local box=entity.bounding_box
      for tx=math.max(minx,math.floor(box.left_top.x)),math.min(maxx-1,math.ceil(box.right_bottom.x)-1) do
        for ty=math.max(miny,math.floor(box.left_top.y)),math.min(maxy-1,math.ceil(box.right_bottom.y)-1) do
          occupied[tx..":"..ty]=true
        end
      end
    end
  end
  local ramps=surface.find_entities_filtered{area={{minx-7,miny-7},{maxx+7,maxy+7}},name={"deep-caves-ramp-up","deep-caves-ramp-down","deep-caves-vent"}}
  local seed=surfaces.seed_for_depth(depth);local changes={}
  for _,tile in ipairs(surface.find_tiles_filtered{area=area}) do
    local p=tile.position;local key=p.x..":"..p.y
    if generation.is_cave_ground(tile.name) and not tile.hidden_tile and not occupied[key]
      and generation.flooded_at(p.x+.5,p.y+.5,depth,seed) then
      local clear=true
      for _,ramp in ipairs(ramps) do
        local dx,dy=p.x+.5-ramp.position.x,p.y+.5-ramp.position.y
        if dx*dx+dy*dy<49 then clear=false;break end
      end
      if clear then changes[#changes+1]={name="deep-caves-shallow-water",position=p} end
    end
  end
  if #changes>0 then walls.set_tiles(surface,changes,false,false,false) end
end
function flooding.tick()
  local state=storage.deep_caves;if not state then return end
  local queue=state.bottom_flood_queue;if not queue then return end
  local cursor=state.bottom_flood_cursor or 1
  local chunk=queue[cursor]
  if not chunk then state.bottom_flood_queue=nil;state.bottom_flood_cursor=nil;state.bottom_flood_version=1;return end
  local surface=game.surfaces[chunk.surface]
  if surface and surface.is_chunk_generated{x=chunk.x,y=chunk.y} then flooding.chunk(surface,chunk.x,chunk.y) end
  state.bottom_flood_cursor=cursor+1
end
return flooding
