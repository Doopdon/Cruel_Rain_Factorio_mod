-- Runs only in the disposable copy created by run_engine.py. No hooks are
-- installed in a normal game. Uses real prototypes, Cave Walls and collisions.
local generation=require("scripts.generation")
local surfaces=require("scripts.surfaces")
local portals=require("scripts.portals")
local features=require("scripts.features")
local require_cached_spawn_checks=require("scripts.spawn_checks")
local suite={}
local passed,failed=0,0
local function check(ok,message) assert(ok,message) end
local function test(name,fn)
  local ok,err=pcall(fn)
  if ok then passed=passed+1;log("DC_ENGINE PASS "..name)
  else failed=failed+1;log("DC_ENGINE FAIL "..name..": "..tostring(err)) end
end
local function area(x,y) return {left_top={x=x*32,y=y*32},right_bottom={x=x*32+32,y=y*32+32}} end
function suite.prepare()
  -- Chunk events requested in on_init are deferred by Factorio. Request the
  -- test regions in one simulation callback and inspect them on a later tick.
  for depth=1,5 do
    local cave=surfaces.ensure(depth)
    for _,region in ipairs({{300,-300},{-4096,4096}}) do
      cave.request_to_generate_chunks({x=region[1]*32+64,y=region[2]*32+64},3)
      cave.force_generate_chunk_requests()
    end
    -- Finite random samples can legitimately omit a rare resource. Add one
    -- eligible seeded site per allowed resource to test actual placement.
    -- These are generated normally, with no direct entity creation or rerolls.
    local intervals=depth==1 and {{0,.22},{.22,.42},{.42,.62},{.62,1}}
      or depth==2 and {{0,.29},{.29,.55},{.55,.76},{.76,1}}
      or depth==3 and {{0,.27},{.27,.51},{.51,.69},{.69,.88},{.88,1}}
      or {{0,.25},{.25,.47},{.47,.64},{.64,.8},{.8,.91},{.91,1}}
    local seed=surfaces.seed_for_depth(depth)
    for index,interval in ipairs(intervals) do
      local found=false
      for attempt=0,2047 do
        local x,y=2000+attempt,2000+depth*37+index*7
        local pick=generation.hash01(x,y,seed+30132)
        if generation.hash01(x,y,seed+30001)>=.55 and pick>=interval[1] and pick<interval[2]
          and generation.hash01(x,y,seed+25013)>=.5 and generation.hash01(x,y,seed+32003)>=.1 then
          local count=0;for _ in pairs(generation.layout_kinds(x,y,depth,seed)) do count=count+1 end
          if count>=24 then
            cave.request_to_generate_chunks({x=x*32+16,y=y*32+16},0)
            cave.force_generate_chunk_requests();found=true;break
          end
        end
      end
      check(found,"could not select an eligible resource test site")
    end
    log("DC_ENGINE PREPARED L"..depth)
  end
end
function suite.run()
  test("initial Cave 1, four complete starter deposits and paired primary ramp",function()
    local cave=game.surfaces[surfaces.name(1)]
    check(cave~=nil,"Cave 1 missing after initialization")
    check(storage.deep_caves.starter_resource_version==3,"starter placement incomplete")
    for _,p in ipairs({{"iron-ore",9,-9},{"copper-ore",-9,-9},{"coal",9,9},{"stone",-9,9}}) do
      for dx=-1,1 do for dy=-1,1 do
        local pos={x=p[2]+dx+.5,y=p[3]+dy+.5}
        check(cave.count_entities_filtered{name=p[1],position=pos,radius=.01}==1,p[1].." starter tile missing")
        check(generation.is_cave_ground(cave.get_tile(pos).name),"starter ore on unbuildable ground")
        check(cave.count_entities_filtered{name="cave-wall-collision",position=pos,radius=.01}==0,"wall collision underneath ore")
      end end
    end
    local source=storage.deep_caves.portals[storage.deep_caves.starting_entrance]
    local pair=source and storage.deep_caves.portals[source.pair_unit]
    check(pair and pair.entity.valid and pair.entity.surface==cave,"primary entrance unpaired")
    local inventory=source.inventory_entity
    check(inventory and inventory.valid and pair.inventory_entity.link_id==inventory.link_id,"ramp inventories not linked")
  end)
  test("Level 1 starter nest exclusion applies during initial generation",function()
    local cave=game.surfaces[surfaces.name(1)]
    local center=storage.deep_caves.level1_start_position or {x=0,y=0}
    check(cave.count_entities_filtered{position=center,radius=63.99,type="unit-spawner",force="enemy"}==0,"starter area has nests")
  end)
  for depth=1,5 do
    test("distant live generation, ramps, nests and ores on Level "..depth,function()
      local cave=surfaces.ensure(depth)
      local boxes={}
      for _,region in ipairs({{300,-300},{-4096,4096}}) do
        local center={x=region[1]*32+64,y=region[2]*32+64}
        cave.request_to_generate_chunks(center,3);cave.force_generate_chunk_requests()
        boxes[#boxes+1]={{(region[1]-1)*32,(region[2]-1)*32},{(region[1]+6)*32,(region[2]+6)*32}}
      end
      local ramps,nests,ores=0,0,0
      for _,box in ipairs(boxes) do
        ramps=ramps+cave.count_entities_filtered{area=box,name="deep-caves-ramp-down"}
        nests=nests+cave.count_entities_filtered{area=box,type="unit-spawner",force="enemy"}
        ores=ores+cave.count_entities_filtered{area=box,type="resource"}
      end
      if depth<5 then check(ramps>0,"no distant descents") else check(ramps==0,"descent below final level") end
      check(nests>0,"no distant scripted nests");check(ores>0,"no distant ores")
      for _,box in ipairs(boxes) do
        for _,ore in ipairs(cave.find_entities_filtered{area=box,type="resource"}) do
          check(ore.amount>0,"non-positive resource amount")
          check(generation.is_cave_ground(cave.get_tile(ore.position).name),"resource submerged or inside wall")
          if depth<3 then check(ore.name~="crude-oil","oil on an upper level") end
          if depth<4 then check(ore.name~="uranium-ore","uranium on an upper level") end
        end
        for _,ramp in ipairs(cave.find_entities_filtered{area=box,name="deep-caves-ramp-down"}) do
          local p=ramp.position
          local landing=cave.find_non_colliding_position("character",{x=p.x,y=p.y-3.2},5,.25)
          check(landing~=nil,"no character-sized landing at ramp")
          check(storage.deep_caves.portals[ramp.unit_number]~=nil,"ramp missing registry record")
        end
      end
      log(string.format("DC_ENGINE SAMPLE L%d ramps=%d nests=%d resources=%d",depth,ramps,nests,ores))
    end)
  end
  test("four basic ores, oil and uranium are present on their allowed levels",function()
    for depth=1,5 do
      local cave=game.surfaces[surfaces.name(depth)]
      for _,ore in ipairs({"iron-ore","copper-ore","coal","stone"}) do
        check(cave.count_entities_filtered{name=ore}>0,ore.." missing on L"..depth)
      end
      if depth>=3 then check(cave.count_entities_filtered{name="crude-oil"}>0,"oil missing on L"..depth) end
      if depth>=4 then check(cave.count_entities_filtered{name="uranium-ore"}>0,"uranium missing on L"..depth) end
    end
  end)
  test("native biters can spawn beside nests on every level",function()
    for depth=1,5 do
      local cave=game.surfaces[surfaces.name(depth)]
      local nest=cave.find_entities_filtered{type="unit-spawner",force="enemy",limit=1}[1]
      check(nest~=nil,"no test nest")
      local pos=cave.find_non_colliding_position("small-biter",{x=nest.position.x+3.5,y=nest.position.y},12,.25)
      check(pos~=nil,"no biter-sized ground beside nest on L"..depth)
      local unit=cave.create_entity{name="small-biter",position=pos,force="enemy"}
      check(unit and unit.valid,"native biter creation failed")
      unit.destroy()
    end
  end)
  test("spawn inspection reports valid links without generating terrain",function()
    local checks=require_cached_spawn_checks
    local cave=game.surfaces[surfaces.name(1)]
    local p=storage.deep_caves.level1_start_position
    local chunks=0;for _ in cave.get_chunks() do chunks=chunks+1 end
    local r=checks.inspect(cave,p,3)
    local after=0;for _ in cave.get_chunks() do after=after+1 end
    check(chunks==after,"inspection expanded the map")
    check(r.broken==0 and r.up>0 and r.ores["iron-ore"]>=9,"incorrect inspection result")
  end)
  test("fresh distant pairing generates a valid up-ramp and linked cargo",function()
    local cave=game.surfaces[surfaces.name(2)]
    local ramp=cave.find_entities_filtered{name="deep-caves-ramp-down",area={{9600,-9600},{9760,-9440}},limit=1}[1]
    check(ramp~=nil,"no distant test ramp")
    local source=storage.deep_caves.portals[ramp.unit_number]
    local pair=portals.ensure_pair(source)
    check(pair and pair.entity.valid and pair.entity.name=="deep-caves-ramp-up","pair creation failed")
    check(pair.pair_unit==ramp.unit_number and source.pair_unit==pair.entity.unit_number,"asymmetric pair")
    check(source.inventory_entity.link_id==pair.inventory_entity.link_id,"cargo link differs")
    check(storage.deep_caves.pair_generation==0,"pair-generation guard leaked")
  end)
  test("exploring a distant Level 1 column creates a paired Nauvis return",function()
    local cave=game.surfaces[surfaces.name(1)]
    local column
    for x=700,800 do
      if generation.hash01(x,700,surfaces.seed_for_depth(0)+25013)<.5 then column={x=x,y=700};break end
    end
    check(column~=nil,"no test column")
    local center={x=column.x*32+16.5,y=column.y*32+16.5}
    cave.request_to_generate_chunks(center,1);cave.force_generate_chunk_requests()
    generation.carve_circle(cave,center,7)
    local pos=cave.find_non_colliding_position("character",center,12,.5)
    check(pos~=nil,"no test character landing")
    local character=cave.create_entity{name="character",position=pos,force="player"}
    check(character and character.valid,"test character creation failed")
    for _=1,30 do
      storage.deep_caves.next_background_preparation_tick=0
      portals.prepare_surface_returns({{character=character}})
      game.surfaces.nauvis.force_generate_chunk_requests()
    end
    local ups=cave.find_entities_filtered{name="deep-caves-vent",position=center,radius=80}
    check(#ups>0,"no distant surface return")
    for _,up in ipairs(ups) do
      local record=storage.deep_caves.portals[up.unit_number]
      local pair=record and storage.deep_caves.portals[record.pair_unit]
      check(pair and pair.entity.valid and pair.entity.surface.name=="nauvis","surface return not paired")
    end
    character.destroy()
  end)
  test("completed generation passes are idempotent and do not resurrect cleared nests",function()
    local cave=game.surfaces[surfaces.name(3)];local seed=surfaces.seed_for_depth(3)
    local ramp_count=cave.count_entities_filtered{name="deep-caves-ramp-down"}
    local resource_count=cave.count_entities_filtered{type="resource"}
    for x=300,303 do for y=-300,-297 do
      local key=x..":"..y
      local state=storage.deep_caves
      if state.entrance_chunks[cave.index][key]==2 then portals.spawn_random_entrance(cave,area(x,y),3,seed) end
      if state.resource_chunks[cave.index][key]==5 then features.populate_resources(cave,area(x,y),3,seed) end
      features.populate_enemies(cave,area(x,y),3,seed)
    end end
    check(cave.count_entities_filtered{name="deep-caves-ramp-down"}==ramp_count,"duplicate ramps")
    check(cave.count_entities_filtered{type="resource"}==resource_count,"duplicate resources")
    local nest=cave.find_entities_filtered{type="unit-spawner",area={{9600,-9600},{9792,-9408}},limit=1}[1]
    check(nest~=nil,"no cleared-nest test target")
    local p=nest.position;local chunk_area=area(math.floor(p.x/32),math.floor(p.y/32))
    nest.destroy()
    check(features.populate_enemies(cave,chunk_area,3,seed)==0,"cleared nest recreated")
  end)
  test("both nest types allow native unit and character placement inside their footprint",function()
    local surface=game.create_surface("nest-collision-test",{width=64,height=64})
    surface.request_to_generate_chunks({0,0},1);surface.force_generate_chunk_requests()
    for _,entity in pairs(surface.find_entities_filtered{}) do entity.destroy() end
    local tiles={}
    for x=-12,12 do for y=-12,12 do tiles[#tiles+1]={name="concrete",position={x,y}} end end
    surface.set_tiles(tiles)
    for _,name in ipairs({"biter-spawner","spitter-spawner"}) do
      local nest=surface.create_entity{name=name,position={0,0},force="enemy"}
      check(nest and nest.valid,"could not create "..name)
      for _,unit in ipairs({"small-biter","behemoth-biter","small-spitter","behemoth-spitter","character"}) do
        check(surface.can_place_entity{name=unit,position={0,0}},unit.." blocked by "..name)
      end
      check(nest.health>0 and nest.destructible,"nest became invulnerable")
      nest.destroy()
    end
    game.delete_surface(surface)
  end)
  log(string.format("DC_ENGINE RESULT %d passed, %d failed",passed,failed))
  if failed>0 then error("Deep Caves engine regression tests failed") end
end
return suite
