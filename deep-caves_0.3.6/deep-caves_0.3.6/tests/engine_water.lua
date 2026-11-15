local suite={}
local surfaces=require("scripts.surfaces")
local generation=require("scripts.generation")
function suite.prepare()
 local cave=surfaces.ensure(1)
 for _,p in ipairs({{x=1024,y=1024},{x=-1024,y=1024}}) do
  cave.request_to_generate_chunks(p,1);cave.force_generate_chunk_requests()
 end
end
function suite.run()
 local cave=surfaces.ensure(1);local wet=0;local seed=surfaces.seed_for_depth(1)
 for _,p in ipairs({{x=1024,y=1024},{x=-1024,y=1024}}) do
  for x=p.x-32,p.x+31 do for y=p.y-32,p.y+31 do
   if generation.is_floor(x+.5,y+.5,1,seed) and generation.flooded_at(x+.5,y+.5,1,seed)
    and cave.get_tile(x,y).name=="deep-caves-shallow-water" then wet=wet+1 end
  end end
 end
 assert(wet>0,"no new shallow water on native Cave 1 tunnel floors")
 for _,name in ipairs({"iron-ore","copper-ore","coal","stone"}) do
  local resource=cave.find_entities_filtered{type="resource",name=name,position={0,0},radius=32,limit=1}[1]
  assert(resource,"missing starter "..name)
  assert(generation.is_cave_ground(cave.get_tile(resource.position).name),"starter ore is underwater")
 end
 log("DC_ENGINE PASS "..wet.." sampled native tunnel tiles have shallow water; all four starter resources remain dry")
 log("DC_ENGINE RESULT 1 passed, 0 failed")
end
return suite
