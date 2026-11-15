local generation=require("scripts.generation")
local wasteland={}
local dead_trees={"dead-grey-trunk","dead-dry-hairy-tree","dead-tree-desert","dry-tree","dry-hairy-tree"}
local dead={}
for _,name in ipairs(dead_trees) do dead[name]=true end
local function natural(name)
  return name=="dry-dirt" or name=="nuclear-ground"
    or string.match(name,"^grass%-%d+$") or string.match(name,"^dirt%-%d+$")
    or string.match(name,"^sand%-%d+$") or string.match(name,"^red%-desert%-%d+$")
    or string.match(name,"^deep%-caves%-waste%-")
end
function wasteland.ground_name(x,y,seed)
  local broad=generation.smooth_noise(x/85,y/85,seed+40101)
  local fine=generation.smooth_noise(x/19,y/19,seed+40133)
  local n=broad*.78+fine*.22
  return n>.57 and "deep-caves-waste-ash" or n<.38 and "deep-caves-waste-dust" or "deep-caves-waste-earth"
end

function wasteland.process_chunk(surface,area,seed)
  if surface.name~="nauvis" then return end
  for _,enemy in pairs(surface.find_entities_filtered{area=area,force="enemy",type={"unit","unit-spawner","turret"}}) do enemy.destroy() end
  -- Resources include solid ore, coal, stone and oil. Machines and their
  -- inventories are left in place even if their deposit is now exhausted.
  for _,resource in pairs(surface.find_entities_filtered{area=area,type="resource"}) do resource.destroy() end
  for _,tree in pairs(surface.find_entities_filtered{area=area,type="tree",force="neutral"}) do
    if not dead[tree.name] then tree.destroy() end
  end
  surface.destroy_decoratives{area=area}
  local tiles={}
  for x=area.left_top.x,area.right_bottom.x-1 do
    for y=area.left_top.y,area.right_bottom.y-1 do
      local tile=surface.get_tile(x,y)
      if tile.valid then
        local name=wasteland.ground_name(x+.5,y+.5,seed)
        if natural(tile.name) and not tile.hidden_tile then
          if tile.name~=name then tiles[#tiles+1]={name=name,position={x,y}} end
        elseif tile.hidden_tile and natural(tile.hidden_tile) then
          -- Keep paving, but reveal wasteland rather than grass if it is mined.
          surface.set_hidden_tile({x=x,y=y},name)
        end
      end
    end
  end
  if #tiles>0 then surface.set_tiles(tiles,true,false,true) end
  -- Sparse dead trees remain mineable for wood; no green forests return.
  local cx,cy=math.floor(area.left_top.x/32),math.floor(area.left_top.y/32)
  for i=1,2 do
    if generation.hash01(cx,cy,seed+41003+i*127)<.18 then
      local p={x=area.left_top.x+3+generation.hash01(cx,cy,seed+41101+i*131)*26,
        y=area.left_top.y+3+generation.hash01(cx,cy,seed+41201+i*137)*26}
      local name=dead_trees[math.floor(generation.hash01(cx,cy,seed+41303+i*139)*#dead_trees)+1]
      if natural(surface.get_tile(p).name) and surface.can_place_entity{name=name,position=p,force="neutral"} then
        surface.create_entity{name=name,position=p,force="neutral"}
      end
    end
  end
end

function wasteland.upgrade()
  local surface=game.surfaces.nauvis
  if not surface then return end
  surface.no_enemies_mode=true
  if storage.deep_caves.surface_enemies_cleared_version~=1 then
    for _,enemy in pairs(surface.find_entities_filtered{force="enemy",type={"unit","unit-spawner","turret"}}) do enemy.destroy() end
    storage.deep_caves.surface_enemies_cleared_version=1
  end
  local settings=surface.map_gen_settings
  settings.autoplace_controls=settings.autoplace_controls or {}
  for name,control in pairs(prototypes.autoplace_control) do
    if control.category=="resource" or name=="trees" or name=="enemy-base" then
      -- Factorio 2.1 map generation requires finite frequency even when disabled.
      settings.autoplace_controls[name]={frequency=1,size=0,richness=0}
    end
  end
  surface.map_gen_settings=settings
  if storage.deep_caves.wasteland_version==1 then return end
  local seed=(game.default_map_gen_settings.seed+7919)%4294967295
  local chunks={}
  for chunk in surface.get_chunks() do
    if surface.is_chunk_generated(chunk) then chunks[#chunks+1]={x=chunk.x,y=chunk.y} end
  end
  table.sort(chunks,function(a,b) return a.x==b.x and a.y<b.y or a.x<b.x end)
  for _,chunk in ipairs(chunks) do
    wasteland.process_chunk(surface,{left_top={x=chunk.x*32,y=chunk.y*32},right_bottom={x=chunk.x*32+32,y=chunk.y*32+32}},seed)
  end
  storage.deep_caves.wasteland_version=1
end

return wasteland
