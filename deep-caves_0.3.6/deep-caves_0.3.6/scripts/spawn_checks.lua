local surfaces=require("scripts.surfaces")
local checks={}

-- Bounded, read-only inspection for a player's current area. Empty samples
-- are possible with probabilistic spawning; only broken registry links fail.
function checks.inspect(surface,position,radius)
  local cx,cy=math.floor(position.x/32),math.floor(position.y/32)
  local area={{(cx-radius)*32,(cy-radius)*32},{(cx+radius+1)*32,(cy+radius+1)*32}}
  local result={chunks=0,down=0,up=0,nests=0,unpaired=0,broken=0,ores={}}
  for x=cx-radius,cx+radius do for y=cy-radius,cy+radius do
    if surface.is_chunk_generated{x=x,y=y} then result.chunks=result.chunks+1 end
  end end
  local records=storage.deep_caves.portals
  for _,ramp in ipairs(surface.find_entities_filtered{area=area,name={"deep-caves-ramp-down","deep-caves-ramp-up","deep-caves-vent"}}) do
    local direction=ramp.name=="deep-caves-ramp-down" and "down" or "up"
    result[direction]=result[direction]+1
    local record=records[ramp.unit_number]
    if not record then result.broken=result.broken+1
    elseif not record.pair_unit then result.unpaired=result.unpaired+1
    else
      local pair=records[record.pair_unit]
      if not (pair and pair.entity and pair.entity.valid and pair.pair_unit==ramp.unit_number) then
        result.broken=result.broken+1
      end
    end
  end
  result.nests=surface.count_entities_filtered{area=area,type="unit-spawner",force="enemy"}
  for _,ore in ipairs({"iron-ore","copper-ore","coal","stone","crude-oil","uranium-ore"}) do
    result.ores[ore]=surface.count_entities_filtered{area=area,name=ore,type="resource"}
  end
  return result
end

function checks.command(command)
  local player=command.player_index and game.get_player(command.player_index)
  if not player then return end
  local surface=player.physical_surface
  local depth=surfaces.depth_from_surface(surface)
  if depth==nil then player.print("This surface is not managed by Cruel Rain.");return end
  local parameter=command.parameter
  if not parameter or parameter:match("^%s*$") then parameter="3" end
  local radius=tonumber(parameter)
  if not radius or radius<1 or radius>8 or radius~=math.floor(radius) then
    player.print("Usage: /cave-check-spawns [chunk radius 1-8]");return
  end
  local r=checks.inspect(surface,player.physical_position,radius)
  player.print(string.format("Cruel Rain %s: %d generated chunks | down=%d, up=%d, nests=%d | unpaired=%d, broken links=%d",
    surface.name,r.chunks,r.down,r.up,r.nests,r.unpaired,r.broken))
  local names={}
  for _,ore in ipairs({"iron-ore","copper-ore","coal","stone","crude-oil","uranium-ore"}) do
    names[#names+1]=ore.."="..r.ores[ore]
  end
  player.print("Resource entities: "..table.concat(names,", "))
  player.print("Enemy density="..settings.startup["deep-caves-enemy-density"].value
    .." | surface-return preparation="..(storage.deep_caves.background_preparation_enabled~=false and "on" or "off")
    .." | starter placement="..(storage.deep_caves.starter_resource_version==3 and "complete" or "pending"))
end
return checks
