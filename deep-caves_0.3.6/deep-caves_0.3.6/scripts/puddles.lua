local puddles={}
local generation=require("scripts.generation")
local walls=require("scripts.walls")
local function eligible(record)
  return record.entity and record.entity.valid and record.from_depth==1 and record.to_depth==0
    and record.entity.surface.name=="deep-caves-level-1"
end
function puddles.add(record)
  if not eligible(record) or record.entrance_puddle_version==1 then return end
  local entity=record.entity;local surface=entity.surface;local p=entity.position
  local state=storage.deep_caves
  state.entrance_puddle_tiles=state.entrance_puddle_tiles or {}
  local protected=state.entrance_puddle_tiles[surface.index] or {}
  state.entrance_puddle_tiles[surface.index]=protected
  local changes={}
  -- Center water beneath the three-tile sprite, with a small lower lip.
  for x=math.floor(p.x-1.55),math.ceil(p.x+1.55) do
    for y=math.floor(p.y-1.3),math.ceil(p.y+2.1) do
      local dx,dy=(x+.5-p.x)/1.55,(y+.5-(p.y+.4))/1.7
      if dx*dx+dy*dy<=1 and surface.is_chunk_generated{x=math.floor(x/32),y=math.floor(y/32)} then
        local tile=surface.get_tile(x,y)
        if generation.is_cave_ground(tile.name) and not tile.hidden_tile then
          -- The ramp and its helpers must be allowed over their own puddle.
          -- Keep unrelated structures, ores, rocks and characters dry.
          local blocked=false
          for _,occupant in pairs(surface.find_entities_filtered{area={{x+.001,y+.001},{x+.999,y+.999}}}) do
            if occupant~=entity and occupant~=record.inventory_entity
              and occupant~=record.power and occupant~=record.pole then blocked=true;break end
          end
          if not blocked then
            changes[#changes+1]={name="deep-caves-shallow-water",position={x,y}}
            protected[x..":"..y]=true
          end
        end
      end
    end
  end
  if #changes>0 then walls.set_tiles(surface,changes,false,false,false) end
  record.entrance_puddle_version=1
end
function puddles.queue_existing()
  local state=storage.deep_caves
  state.entrance_puddle_queue={};state.entrance_puddle_cursor=1
  for _,record in pairs(state.portals) do
    if eligible(record) and record.entrance_puddle_version~=1 then
      state.entrance_puddle_queue[#state.entrance_puddle_queue+1]=record
    end
  end
end
function puddles.tick()
  local state=storage.deep_caves;if not state then return end
  local queue=state.entrance_puddle_queue;if not queue then return end
  local cursor=state.entrance_puddle_cursor or 1
  for _=1,10 do
    local record=queue[cursor]
    if not record then state.entrance_puddle_queue=nil;state.entrance_puddle_cursor=nil;return end
    puddles.add(record);cursor=cursor+1
  end
  state.entrance_puddle_cursor=cursor
end
return puddles
