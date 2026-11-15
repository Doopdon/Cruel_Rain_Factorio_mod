local walls={NAME="cave-wall"}
function walls.is_wall(name) return name=="out-of-map" or name==walls.NAME end
local function cave(surface) return string.match(surface.name,"^deep%-caves%-level%-%d+$")~=nil end
function walls.set_tiles(surface,tiles,...)
  local protected=storage.deep_caves and storage.deep_caves.entrance_puddle_tiles
  protected=protected and protected[surface.index]
  if protected then
    for _,tile in ipairs(tiles) do
      local p=tile.position;local x,y=p.x or p[1],p.y or p[2]
      if protected[x..":"..y] and tile.name:match("^deep%-caves%-%a+%-%d+$")
        and surface.get_tile(x,y).name=="deep-caves-shallow-water" then
        tile.name="deep-caves-shallow-water"
      end
    end
  end
  surface.set_tiles(tiles,...)
  if not cave(surface) or #tiles==0 then return end
  local minx,miny,maxx,maxy=math.huge,math.huge,-math.huge,-math.huge
  for _,tile in ipairs(tiles) do
    local p=tile.position;local x,y=p.x or p[1],p.y or p[2]
    minx=math.min(minx,x);miny=math.min(miny,y);maxx=math.max(maxx,x);maxy=math.max(maxy,y)
  end
  -- Include correction neighbors at the edge of this edit.
  remote.call("cave-walls","sync_area",surface.index,
    {left_top={x=minx-1,y=miny-1},right_bottom={x=maxx+2,y=maxy+2}})
end
function walls.upgrade()
  local state=storage.deep_caves
  if state.solid_wall_version==1 then return 0 end
  local total=0
  for _,surface in pairs(game.surfaces) do
    if cave(surface) then
      for chunk in surface.get_chunks() do
        if surface.is_chunk_generated(chunk) then
          local area={{chunk.x*32,chunk.y*32},{chunk.x*32+32,chunk.y*32+32}}
          local changes={}
          for _,tile in ipairs(surface.find_tiles_filtered{area=area,name="out-of-map"}) do
            changes[#changes+1]={name=walls.NAME,position=tile.position}
          end
          if #changes>0 then surface.set_tiles(changes,false,false,false);total=total+#changes end
        end
      end
      remote.call("cave-walls","register_surface",surface.index)
    end
  end
  state.solid_wall_version=1
  return total
end
return walls
