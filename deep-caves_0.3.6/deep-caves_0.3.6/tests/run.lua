-- Run from the mod folder: lua tests/run.lua (or texlua tests/run.lua).
-- Optional first argument: another mod folder, for regression comparisons.
local source=arg[1] or '.'
package.path=source..'/?.lua;'..package.path
local mock=dofile('tests/factorio_mock.lua')
local passed,failed=0,0
local function check(ok,message) assert(ok,message) end
local function test(name,fn)
  local ok,err=pcall(fn)
  if ok then passed=passed+1;print('PASS '..name)
  else failed=failed+1;print('FAIL '..name..': '..tostring(err)) end
end
local sparse={1,1,1,1,1,1}
local function modules(preset,seed)
  mock.reset(preset,seed)
  local generation=require('scripts.generation')
  local portals=require('scripts.portals');portals.init_storage()
  return generation,portals,require('scripts.features'),require('scripts.surfaces')
end
local function paint(surface,area,name)
  local tiles={}
  for x=area.left_top.x,area.right_bottom.x-1 do for y=area.left_top.y,area.right_bottom.y-1 do
    tiles[#tiles+1]={name=name,position={x,y}}
  end end
  surface.set_tiles(tiles)
  surface.chunks[math.floor(area.left_top.x/32)..':'..math.floor(area.left_top.y/32)]={
    x=math.floor(area.left_top.x/32),y=math.floor(area.left_top.y/32)}
end
test('a new game creates Cave 1 and four starter deposits before first travel',function()
  mock.reset(sparse,17);dofile(source..'/control.lua');mock.on_init()
  local cave=game.surfaces['deep-caves-level-1']
  check(cave~=nil,'Cave 1 does not exist at the end of initialization')
  for _,ore in ipairs({'iron-ore','copper-ore','coal','stone'}) do
    check(cave.count_entities_filtered{name=ore,area={{-12,-12},{13,13}}}>=9,ore..' starter patch missing')
  end
  check(cave.count_entities_filtered{type='unit-spawner',position={0,0},radius=50}==0,'starter nests appeared during chunk generation')
end)
test('one-tile tunnel chunks offer ramp sites, including far from origin',function()
  local g=modules(sparse,12345)
  local tested=0
  for x=300,307 do for y=-304,-297 do
    local area=mock.area(x,y);local open=false
    for _,kind in pairs(g.layout_kinds(x,y,1,117993)) do if kind then open=true;break end end
    if open then
      tested=tested+1
      check(g.find_floor_in_chunk(area,1,117993)~=nil,'no ramp site in open chunk '..x..':'..y)
    end
  end end
  check(tested>8,'not enough distant open chunks sampled')
end)
test('a winning ore roll searches the entire natural tunnel chunk',function()
  local g,_,features=modules(sparse,23)
  local cave=mock.surface('deep-caves-level-2','cave-wall')
  local seed=23+2*104729+7919
  local area=mock.area(300,-300)
  for x=300,350 do
    if g.hash01(x,-300,seed+30001)>=.55 then area=mock.area(x,-300);break end
  end
  local cx=math.floor(area.left_top.x/32);local cy=-300
  local targetx=area.left_top.x+4+g.hash01(cx*17+1,cy,seed+30011)*24
  local targety=area.left_top.y+4+g.hash01(cx,cy*19+1,seed+30013)*24
  local x=targetx-area.left_top.x>16 and area.left_top.x or area.right_bottom.x-1
  local y=targety-area.left_top.y>16 and area.left_top.y or area.right_bottom.y-1
  cave.set_tiles{{name='deep-caves-stone-2',position={x,y}}}
  check(features.populate_resources(cave,area,2,seed)>0,'winning ore roll missed the only floor tile')
end)
test('failed ore creation can be retried',function()
  local g,_,features=modules(nil,42)
  local cave=mock.surface('deep-caves-level-1','cave-wall')
  local area,seed=mock.area(400,400),112690
  for x=400,450 do if g.hash01(x,400,seed+30001)>=.55 then area=mock.area(x,400);break end end
  local tile={x=area.left_top.x+16,y=area.left_top.y+16}
  cave.set_tiles{{name='deep-caves-stone-1',position=tile}}
  local original=cave.create_entity;cave.create_entity=function() return nil end
  check(features.populate_resources(cave,area,1,seed)==0,'failure injection did not work')
  cave.create_entity=original
  check(features.populate_resources(cave,area,1,seed)>0,'failed placement was marked complete')
end)
test('failed nest creation can be retried',function()
  local _,_,features=modules(nil,71)
  settings.startup['deep-caves-enemy-density'].value=1
  local cave=mock.surface('deep-caves-level-3','cave-wall')
  local area=mock.area(50,50)
  paint(cave,area,'deep-caves-stone-3')
  local original=cave.create_entity;cave.create_entity=function() return nil end
  check(features.populate_enemies(cave,area,3,71)==0,'failure injection did not work')
  cave.create_entity=original
  check(features.populate_enemies(cave,area,3,71)==1,'failed nest placement was marked complete')
end)
test('ore and nest generation are idempotent',function()
  local g,_,features=modules(nil,97)
  settings.startup['deep-caves-enemy-density'].value=1
  local cave=mock.surface('deep-caves-level-3','cave-wall')
  local area=mock.area(60,60);paint(cave,area,'deep-caves-stone-3')
  features.populate(cave,area,3,97)
  local before=cave.count_entities_filtered{}
  features.populate(cave,area,3,97)
  check(cave.count_entities_filtered{}==before,'duplicate population added entities')
end)
test('ordinary enemy backfill does not resurrect a cleared nest',function()
  local _,_,features=modules(nil,101)
  settings.startup['deep-caves-enemy-density'].value=1
  local cave=mock.surface('deep-caves-level-3','cave-wall')
  local area=mock.area(70,70);paint(cave,area,'deep-caves-stone-3')
  check(features.populate_enemies(cave,area,3,101)==1,'initial nest failed')
  for _,e in ipairs(cave.find_entities_filtered{type='unit-spawner'}) do e.destroy() end
  features.queue_enemies();features.tick_enemies()
  check(cave.count_entities_filtered{type='unit-spawner'}==0,'backfill resurrected a cleared nest')
end)
local function walkable(surface,x,y)
  local name=surface.get_tile(x,y).name
  return name~='cave-wall' and name~='out-of-map'
end
local function reachable(surface,start,target,bounds)
  local queue={{x=math.floor(start.x),y=math.floor(start.y)}}
  local seen={[queue[1].x..':'..queue[1].y]=true};local i=1
  while queue[i] do
    local p=queue[i];i=i+1
    if p.x==math.floor(target.x) and p.y==math.floor(target.y) then return true end
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
      local x,y=p.x+d[1],p.y+d[2];local key=x..':'..y
      if not seen[key] and x>=bounds[1] and y>=bounds[2] and x<=bounds[3] and y<=bounds[4]
        and walkable(surface,x,y) then seen[key]=true;queue[#queue+1]={x=x,y=y} end
    end
  end
  return false
end
for _,seed in ipairs({0,982451653,4294967000}) do
  test('starter ores are present, accessible and safe with sparse settings, seed '..seed,function()
    mock.reset(sparse,seed);dofile(source..'/control.lua');mock.on_init()
    local cave=game.surfaces['deep-caves-level-1']
    check(cave~=nil,'missing Cave 1')
    local landing=storage.deep_caves.level1_start_position or {x=0,y=0}
    for _,patch in ipairs({{'iron-ore',9,-9},{'copper-ore',-9,-9},{'coal',9,9},{'stone',-9,9}}) do
      for dx=-1,1 do for dy=-1,1 do
        check(cave.count_entities_filtered{name=patch[1],position={x=patch[2]+dx+.5,y=patch[3]+dy+.5},radius=.01}==1,
          patch[1]..' missing a guaranteed tile')
      end end
      check(reachable(cave,landing,{x=patch[2],y=patch[3]},{-64,-64,64,64}),patch[1]..' is inaccessible')
    end
    check(cave.count_entities_filtered{force='enemy',type='unit-spawner',position=landing,radius=63.99}==0,'unsafe starter nests')
  end)
end

test('starter failure retries only the missing tile and never refills mined patches',function()
  local _,_,features=modules(sparse,11)
  local cave=mock.surface('deep-caves-level-1','cave-wall')
  mock.next_fail='iron-ore'
  features.ensure_level1_starter_resources()
  check(storage.deep_caves.starter_resource_version==nil,'partial starter marked complete')
  local before=cave.count_entities_filtered{type='resource'}
  check(features.ensure_level1_starter_resources()==1,'did not repair exactly one missing tile')
  check(cave.count_entities_filtered{type='resource'}==before+1,'duplicated starter resources')
  for _,e in ipairs(cave.find_entities_filtered{type='resource'}) do e.destroy() end
  check(features.ensure_level1_starter_resources()==0,'refilled mined starter patches')
end)

for _,depth in ipairs({2,5}) do
  test('winning ore rolls still place resources on wet-only Level '..depth,function()
    local g,_,features=modules(sparse,123)
    local cave=mock.surface('deep-caves-level-'..depth,'cave-wall')
    local seed=123+depth*104729+7919;local area
    for x=300,500 do if g.hash01(x,301,seed+30001)>=.55 then area=mock.area(x,301);break end end
    paint(cave,area,'deep-caves-shallow-water')
    check(features.populate_resources(cave,area,depth,seed)>0,'wet-only chunk lost its resource roll')
    for _,e in ipairs(cave.find_entities_filtered{type='resource'}) do
      check(g.is_cave_ground(cave.get_tile(e.position).name),'resource is underwater')
    end
  end)
end

test('oil has a buildable footprint in one-tile Level 3 tunnels',function()
  local g,_,features=modules(sparse,877)
  local cave=mock.surface('deep-caves-level-3','cave-wall');local seed=877+3*104729+7919;local area
  for x=300,1500 do
    if g.hash01(x,302,seed+30001)>=.55 and g.hash01(x,302,seed+30132)>=.88 then area=mock.area(x,302);break end
  end
  check(area~=nil,'no oil test coordinate found')
  local x=area.left_top.x+16
  local tiles={};for y=area.left_top.y,area.right_bottom.y-1 do tiles[#tiles+1]={name='deep-caves-stone-3',position={x,y}} end
  cave.set_tiles(tiles);cave.chunks[math.floor(x/32)..':302']={x=math.floor(x/32),y=302}
  features.populate_resources(cave,area,3,seed)
  check(cave.count_entities_filtered{name='crude-oil'}>0,'oil footprint was rejected')
end)

test('partial two-deposit failure retries without duplicating the completed deposit',function()
  local g,_,features=modules(nil,1234)
  local cave=mock.surface('deep-caves-level-1','cave-wall');local seed=1234+104729+7919
  local area,first,second
  local function ore(pick) return pick<.22 and 'iron-ore' or pick<.42 and 'copper-ore' or pick<.62 and 'stone' or 'coal' end
  for x=100,1000 do
    local a,b=ore(g.hash01(x,200,seed+30132)),ore(g.hash01(x,200,seed+30233))
    if g.hash01(x,200,seed+30001)>=.93 and a~=b then area=mock.area(x,200);first,second=a,b;break end
  end
  check(area~=nil,'no two-deposit coordinate found');paint(cave,area,'deep-caves-stone-1')
  local create=cave.create_entity
  cave.create_entity=function(spec) if spec.name==second then return nil end;return create(spec) end
  features.populate_resources(cave,area,1,seed)
  local before=cave.count_entities_filtered{name=first};check(before>0,'first deposit failed')
  cave.create_entity=create
  check(features.populate_resources(cave,area,1,seed)>0,'second deposit did not retry')
  check(cave.count_entities_filtered{name=first}==before,'first deposit duplicated')
  check(cave.count_entities_filtered{name=second}>0,'second deposit still missing')
end)

for _,preset in ipairs({{name='minimum mesh',p=sparse},{name='default mesh',p={1,12,4,3,10,1}}}) do
  for depth=1,5 do
    test(preset.name..': distant ramps, nests and resource types on Level '..depth,function()
      local totals={ramps=0,nests=0,ores=0,eligible=0}
      for _,seed in ipairs({17,4294967000}) do
        local g,portals,features,surfaces=modules(preset.p,seed)
        local cave=mock.surface('deep-caves-level-'..depth,'cave-wall')
        local world_seed=surfaces.seed_for_depth(depth)
        for _,region in ipairs({{300,-300},{-4096,4096}}) do
          for x=region[1],region[1]+3 do for y=region[2],region[2]+3 do
            local area=mock.area(x,y);mock.generate(cave,x,y)
            g.generate_chunk(cave,area,depth,world_seed)
            local site=g.find_floor_in_chunk(area,depth,world_seed)
            local winner=g.hash01(x,y,world_seed+25013)<.5
            if site and winner and depth<5 then
              totals.eligible=totals.eligible+1
              local record=portals.spawn_random_entrance(cave,area,depth,world_seed)
              check(record~=nil,'lost distant ramp '..x..':'..y)
              totals.ramps=totals.ramps+1
              check(reachable(cave,record.entity.position,site,{x*32,y*32,x*32+31,y*32+31}),'ramp landing is disconnected')
            end
            totals.ores=totals.ores+features.populate_resources(cave,area,depth,world_seed)
            totals.nests=totals.nests+features.populate_enemies(cave,area,depth,world_seed)
            g.populate_rocks(cave,area,depth,world_seed)
          end end
        end
        for _,e in ipairs(cave.find_entities_filtered{type='resource'}) do
          check(e.amount and e.amount>0,'non-positive resource amount')
          if depth<3 then check(e.name~='crude-oil','oil appeared too early') end
          if depth<4 then check(e.name~='uranium-ore','uranium appeared too early') end
        end
      end
      check(totals.ores>0,'no distant ores')
      check(totals.nests>0,'no distant nests')
      if depth<5 then check(totals.eligible>0 and totals.ramps==totals.eligible,'ramp eligibility failed')
      else check(totals.ramps==0,'bottom level has downward ramps') end
      print(string.format('  SAMPLE %s L%d: %d ramps, %d nests, %d resource entities',preset.name,depth,totals.ramps,totals.nests,totals.ores))
    end)
  end
end

for _,density in ipairs({0,.001,.01,.1,.5,1,10}) do
  test('enemy overlay honors density '..density..' in distant chunks',function()
    local g,_,features=modules(sparse,7351)
    settings.startup['deep-caves-enemy-density'].value=density
    local cave=mock.surface('deep-caves-level-4','cave-wall')
    local expected,made=0,0
    for x=300,315 do for y=-315,-300 do
      local area=mock.area(x,y);paint(cave,area,'deep-caves-stone-4')
      if density>0 and g.hash01(x,y,7351+32003)<features.enemy_spawn_chance({x=x*32+16,y=y*32+16},4,density) then expected=expected+1 end
      made=made+features.populate_enemies(cave,area,4,7351)
    end end
    check(made==expected,'expected '..expected..' winning rolls, created '..made)
    check(cave.count_entities_filtered{type='unit-spawner'}==expected,'nest entity count differs')
    print(string.format('  DENSITY %.3g: %d / 256 chunks',density,made))
  end)
end

test('safe zone exists before the first up-ramp and does not move with new exits',function()
  local _,portals,features=modules(sparse,13)
  settings.startup['deep-caves-enemy-density'].value=1
  local cave=mock.surface('deep-caves-level-1','cave-wall')
  paint(cave,mock.area(0,0),'deep-caves-stone-1')
  check(features.populate_enemies(cave,mock.area(0,0),1,13)==0,'nest spawned before the up-ramp existed')
  check(features.in_level1_nest_safe_zone(cave,{x=1,y=1}),'starter circle absent')
  paint(cave,mock.area(20,20),'deep-caves-stone-1')
  portals.create_endpoint(cave,{x=656,y=656},'deep-caves-ramp-up',1,0)
  check(not features.in_level1_nest_safe_zone(cave,{x=656,y=656}),'random exit creates a safe zone')
end)

test('winning independent nest overlays connect to the mesh without generating unseen chunks',function()
  local g,_,features,surfaces=modules(sparse,654)
  settings.startup['deep-caves-enemy-density'].value=1
  local cave=mock.surface('deep-caves-level-3','cave-wall')
  local area=mock.area(100,100);mock.generate(cave,100,100)
  local before=mock.generated_events
  check(features.populate_enemies(cave,area,3,surfaces.seed_for_depth(3))==1,'no nest in wall-only chunk')
  check(mock.generated_events==before,'nest recursively generated chunks')
  local seams=storage.deep_caves.cave_seams and storage.deep_caves.cave_seams[cave.index]
  check(seams and next(seams),'access spur not saved across unseen chunks')
  local seam_keys={};for key in pairs(seams) do seam_keys[#seam_keys+1]=key end
  for _,key in ipairs(seam_keys) do
    local x,y=key:match('^(-?%d+):(-?%d+)$');x,y=tonumber(x),tonumber(y)
    mock.generate(cave,x,y);g.generate_chunk(cave,mock.area(x,y),3,surfaces.seed_for_depth(3))
    check(#cave.find_tiles_filtered{area=mock.area(x,y),name={'deep-caves-stone-3','deep-caves-earth-3','deep-caves-sand-3'}}>0,
      'saved access spur vanished on generation')
  end
  local nest=cave.find_entities_filtered{type='unit-spawner'}[1]
  local bounds={area.left_top.x-300,area.left_top.y-300,area.right_bottom.x+300,area.right_bottom.y+300}
  local connected=false
  for _,tile in ipairs(cave.find_tiles_filtered{area=area,name={'deep-caves-stone-3','deep-caves-earth-3','deep-caves-sand-3'}}) do
    if g.is_floor(tile.position.x+.5,tile.position.y+.5,3,surfaces.seed_for_depth(3))
      and reachable(cave,nest.position,tile.position,bounds) then connected=true;break end
  end
  -- The natural mesh may be in a neighboring chunk; inspect those as well.
  if not connected then
    for _,key in ipairs(seam_keys) do
      local x,y=key:match('^(-?%d+):(-?%d+)$');x,y=tonumber(x),tonumber(y)
      for _,tile in ipairs(cave.find_tiles_filtered{area=mock.area(x,y),name={'deep-caves-stone-3','deep-caves-earth-3','deep-caves-sand-3'}}) do
        if g.is_floor(tile.position.x+.5,tile.position.y+.5,3,surfaces.seed_for_depth(3))
          and reachable(cave,nest.position,tile.position,bounds) then connected=true;break end
      end
      if connected then break end
    end
  end
  check(connected,'nest pocket cannot reach the natural mesh')
  check(next(seams)==nil,'generated access geometry was retained unnecessarily')
end)

test('nest overlay preserves existing ores and machines',function()
  local _,_,features=modules(nil,213)
  settings.startup['deep-caves-enemy-density'].value=1
  local cave=mock.surface('deep-caves-level-3','cave-wall');local area=mock.area(88,88)
  paint(cave,area,'deep-caves-stone-3')
  local ore=assert(cave.create_entity{name='iron-ore',position={x=88*32+16.5,y=88*32+16.5},amount=800,force='neutral'})
  local machine=assert(cave.create_entity{name='assembling-machine-1',position={x=88*32+8.5,y=88*32+8.5},force='player'})
  check(features.populate_enemies(cave,area,3,213)==1,'unobstructed alternative nest site not found')
  check(ore.valid and ore.amount==800 and machine.valid,'overlay destroyed existing entities')
end)

test('ramp entity creation failure is retryable and successful placement is unique',function()
  local g,portals,_,surfaces=modules(sparse,173)
  local cave=mock.surface('deep-caves-level-2','cave-wall');local seed=surfaces.seed_for_depth(2);local area
  for x=300,360 do
    mock.generate(cave,x,300);g.generate_chunk(cave,mock.area(x,300),2,seed)
    if g.hash01(x,300,seed+25013)<.5 and g.find_floor_in_chunk(mock.area(x,300),2,seed) then area=mock.area(x,300);break end
  end
  check(area~=nil,'no eligible test ramp');mock.next_fail='deep-caves-ramp-down'
  check(portals.spawn_random_entrance(cave,area,2,seed)==nil,'failure injection did not work')
  check(portals.spawn_random_entrance(cave,area,2,seed)~=nil,'ramp creation failure was marked complete')
  portals.spawn_random_entrance(cave,area,2,seed)
  check(cave.count_entities_filtered{area=area,name='deep-caves-ramp-down'}==1,'duplicate ramps')
end)

test('distant Level 1 exploration produces paired surface-return ramps',function()
  mock.reset(sparse,377);dofile(source..'/control.lua');mock.on_init()
  local g=require('scripts.generation');local portals=require('scripts.portals');local surfaces=require('scripts.surfaces')
  local cave=game.surfaces['deep-caves-level-1'];local area
  for x=300,350 do if g.hash01(x,300,surfaces.seed_for_depth(0)+25013)<.5 then area=mock.area(x,300);break end end
  check(area~=nil,'no return test column')
  local p={x=area.left_top.x+16.5,y=area.left_top.y+16.5}
  mock.generate(cave,math.floor(p.x/32),300);g.carve_circle(cave,p,7)
  mock.player(cave,p)
  for i=1,12 do
    game.tick=i*30;portals.prepare_surface_returns()
    game.surfaces.nauvis.force_generate_chunk_requests()
  end
  local ups=cave.find_entities_filtered{name='deep-caves-vent',position=p,radius=64}
  check(#ups>0,'no distant surface return ramp')
  for _,up in ipairs(ups) do
    local record=storage.deep_caves.portals[up.unit_number]
    local pair=record and storage.deep_caves.portals[record.pair_unit]
    check(pair and pair.entity.valid and pair.entity.surface.name=='nauvis','surface return not paired')
  end
end)

test('pair generation still populates ramps in freshly generated distant cave chunks',function()
  mock.reset(sparse,421);dofile(source..'/control.lua');mock.on_init()
  local g=require('scripts.generation');local portals=require('scripts.portals');local surfaces=require('scripts.surfaces')
  local cave=surfaces.ensure(2);local area=mock.area(250,-250)
  mock.generate(cave,250,-250);g.carve_circle(cave,{x=8016.5,y=-7983.5},7)
  local record=portals.create_endpoint(cave,{x=8016.5,y=-7983.5},'deep-caves-ramp-down',2,3)
  check(record~=nil,'source ramp failed');local pair=portals.ensure_pair(record)
  check(pair and pair.entity.valid,'destination pair failed')
  local destination=pair.entity.surface
  check(destination.count_entities_filtered{name='deep-caves-ramp-down'}>0,'forced chunks lost their downward ramps')
  check(storage.deep_caves.pair_generation==0,'pair generation guard leaked')
end)

test('all basic ores, oil and uranium occur in their allowed levels',function()
  local _,_,features=modules(nil,9001);local seen={}
  for depth=1,5 do
    local cave=mock.surface('deep-caves-level-'..depth,'cave-wall');local local_seen={}
    for x=100,179 do
      local area=mock.area(x,201);paint(cave,area,'deep-caves-stone-'..depth)
      features.populate_resources(cave,area,depth,9001+depth*104729)
    end
    for _,e in ipairs(cave.find_entities_filtered{type='resource'}) do local_seen[e.name]=true;seen[e.name]=true end
    for _,name in ipairs({'iron-ore','copper-ore','stone','coal'}) do check(local_seen[name],name..' missing on L'..depth) end
    if depth>=3 then check(local_seen['crude-oil'],'no oil on L'..depth) end
    if depth>=4 then check(local_seen['uranium-ore'],'no uranium on L'..depth) end
  end
end)

test('bottom level cannot create a downward endpoint',function()
  local _,portals=modules(nil,173)
  local cave=mock.surface('deep-caves-level-5','deep-caves-stone-5')
  check(portals.create_endpoint(cave,{x=10,y=10},'deep-caves-ramp-down',5,6)==nil,'created a Level 6 endpoint')
  portals.spawn_random_entrance(cave,mock.area(0,0),5,173)
  check(cave.count_entities_filtered{name='deep-caves-ramp-down'}==0,'random descent below bottom')
end)

test('fixed starter deposits stay clear of ramps across 24 world seeds',function()
  for seed=1,24 do
    mock.reset(sparse,seed);dofile(source..'/control.lua');mock.on_init()
    check(storage.deep_caves.starter_resource_version==3,'incomplete starter deposits for seed '..seed)
  end
end)

for _,density in ipairs({.001,.01}) do
  test('very low positive enemy density still produces nests across a larger region: '..density,function()
    local g,_,features=modules(sparse,31337)
    settings.startup['deep-caves-enemy-density'].value=density
    local cave=mock.surface('deep-caves-level-3','cave-wall')
    local expected,made=0,0
    for x=1000,1127 do for y=1000,1127 do
      local a=mock.area(x,y)
      local chance=features.enemy_spawn_chance({x=x*32+16,y=y*32+16},3,density)
      if g.hash01(x,y,31337+32003)<chance then expected=expected+1;paint(cave,a,'deep-caves-stone-3') end
      made=made+features.populate_enemies(cave,a,3,31337)
    end end
    check(expected>0 and made==expected,'low positive density failed over 16384 chunks')
    print(string.format('  LOW DENSITY %.3g: %d / 16384 chunks',density,made))
  end)
end

test('nest probability grows radially and with depth while respecting zero and caps',function()
  local _,_,features=modules(sparse,123)
  local chance=features.enemy_spawn_chance
  check(chance({x=0,y=0},1,.1)==.1,'base rate changed')
  check(chance({x=1024,y=0},1,.1)==.2,'distance did not double rate')
  check(math.abs(chance({x=0,y=0},5,.1)-.3)<1e-9,'depth did not triple rate')
  check(chance({x=3072,y=0},5,.1)==1,'combined rate is not capped')
  check(chance({x=-1024,y=0},3,.1)==chance({x=0,y=1024},3,.1),'radial symmetry failed')
  check(chance({x=1e9,y=1e9},5,0)==0,'zero density creates nests')
  check(chance({x=1e9,y=1e9},1,.01)==.04,'distance multiplier is unbounded')
end)

test('near and distant terrain is independent of chunk generation order',function()
  local function snapshot(reverse)
    local g=modules(sparse,5903);local cave=mock.surface('deep-caves-level-3','cave-wall')
    local list={};for _,r in ipairs({{0,0},{300,-300},{-4096,4096}}) do
      for x=r[1],r[1]+2 do for y=r[2],r[2]+2 do list[#list+1]={x=x,y=y} end end
    end
    if reverse then local reversed={};for i=#list,1,-1 do reversed[#reversed+1]=list[i] end;list=reversed end
    for _,c in ipairs(list) do mock.generate(cave,c.x,c.y);g.generate_chunk(cave,mock.area(c.x,c.y),3,5903) end
    local result={};for key,name in pairs(cave.tiles) do result[key]=name end;return result
  end
  local a,b=snapshot(false),snapshot(true)
  for key,name in pairs(a) do check(b[key]==name,'terrain differs at '..key) end
  for key,name in pairs(b) do check(a[key]==name,'extra terrain tile '..key) end
end)

test('read-only spawn inspection leaves terrain and entities unchanged',function()
  mock.reset(sparse,175);dofile(source..'/control.lua');mock.on_init()
  local cave=game.surfaces['deep-caves-level-1']
  local writes,events,count=cave.write_count,mock.generated_events,cave.count_entities_filtered{}
  local checks=require('scripts.spawn_checks')
  local r=checks.inspect(cave,storage.deep_caves.level1_start_position,3)
  check(r.up>0 and r.broken==0 and r.ores['iron-ore']>=9,'invalid initial spawn inspection')
  check(writes==cave.write_count and events==mock.generated_events and count==cave.count_entities_filtered{},'inspection changed game state')
  local landing=storage.deep_caves.level1_start_position
  local p=assert(cave.find_non_colliding_position('character',{x=landing.x,y=landing.y-3.2},6,.5))
  mock.player(cave,p)
  mock.commands['cave-check-spawns']{player_index=1,parameter=''}
  check(tostring(mock.messages[#mock.messages]):find('starter placement=complete',1,true),'empty-argument inspection command failed')
end)

test('oil survives a narrow tunnel at a chunk corner beside a ramp',function()
  local g,portals,features=modules(sparse,877)
  local cave=mock.surface('deep-caves-level-4','cave-wall');local seed=877+4*104729+7919;local area
  for x=300,1500 do
    local roll=g.hash01(x,302,seed+30001);local pick=g.hash01(x,302,seed+30132)
    if roll>=.55 and roll<.93 and pick>=.8 and pick<.91 then area=mock.area(x,302);break end
  end
  check(area~=nil,'no corner-oil test coordinate')
  cave.chunks[math.floor(area.left_top.x/32)..':302']={x=math.floor(area.left_top.x/32),y=302}
  local tiles={};for x=0,7 do tiles[#tiles+1]={name='deep-caves-stone-4',position={area.left_top.x+x,area.left_top.y}} end
  cave.set_tiles(tiles)
  portals.create_endpoint(cave,{x=area.left_top.x+7.5,y=area.left_top.y+7.5},'deep-caves-ramp-down',4,5)
  features.populate_resources(cave,area,4,seed)
  check(cave.count_entities_filtered{name='crude-oil'}>0,'corner oil site was lost to ramp protection')
end)

test('only Cave 1 openings to Nauvis become vents',function()
  local _,portals=modules(sparse,17)
  local cave=mock.surface('deep-caves-level-1','deep-caves-stone-1')
  local vent=portals.create_endpoint(cave,{x=100,y=100},'deep-caves-ramp-up',1,0)
  check(vent.entity.name=='deep-caves-vent','surface opening is still an ascent')
  local deeper=mock.surface('deep-caves-level-2','deep-caves-stone-2')
  local up=portals.create_endpoint(deeper,{x=100,y=100},'deep-caves-ramp-up',2,1)
  check(up.entity.name=='deep-caves-ramp-up','deeper ascent became a surface vent')
  local down=portals.create_endpoint(cave,{x=150,y=100},'deep-caves-ramp-down',1,2)
  check(down.entity.name=='deep-caves-ramp-down','descent became a vent')
end)

test('vent registry recovery and spawn inspection recognize the new prototype',function()
  local _,portals=modules(sparse,17)
  local cave=mock.surface('deep-caves-level-1','deep-caves-stone-1')
  local vent=assert(cave.create_entity{name='deep-caves-vent',position={x=16,y=16},force='player'})
  portals.rebuild_registry()
  local record=storage.deep_caves.portals[vent.unit_number]
  check(record and record.from_depth==1 and record.to_depth==0,'vent registry recovery failed')
  local result=require('scripts.spawn_checks').inspect(cave,vent.position,1)
  check(result.up==1 and result.unpaired==1 and result.broken==0,'vent omitted from inspection')
end)

test('surface vent migration preserves helpers, pairs and saved wires',function()
  local _,portals=modules(sparse,17)
  local cave=mock.surface('deep-caves-level-1','deep-caves-stone-1')
  local record=portals.create_endpoint(cave,{x=100,y=100},'deep-caves-ramp-up',1,0)
  local old=record.entity;old.name='deep-caves-ramp-up'
  local target={valid=true};local copied=0
  old.get_wire_connectors=function() return {[5]={connections={{target=target,origin=7}}}} end
  local inventory={valid=true,contents=37};record.inventory_entity=inventory
  local power=record.power;power.energy=8000000
  local pair={entity={valid=true,unit_number=999},pair_unit=old.unit_number}
  record.pair_unit=999;storage.deep_caves.portals[999]=pair
  -- Native create_entity can overlap the pole being replaced. The lightweight
  -- mock normally enforces placement; real-engine tests verify this operation.
  local original=cave.create_entity
  cave.create_entity=function(spec)
    old.valid=false;local entity=original(spec);old.valid=true
    if entity then entity.get_wire_connector=function(id)
      check(id==5,'wrong connector ID')
      return {connect_to=function(t,_,origin)
        check(t==target and origin==7,'saved wire changed');copied=copied+1
      end}
    end end
    return entity
  end
  portals.upgrade_surface_vents()
  check(not old.valid and record.entity.name=='deep-caves-vent','visible pole was not converted')
  check(storage.deep_caves.portals[old.unit_number]==nil,'stale registry entry')
  check(storage.deep_caves.portals[record.entity.unit_number]==record,'new registry entry missing')
  check(pair.pair_unit==record.entity.unit_number and record.pair_unit==999,'pair IDs lost')
  check(record.inventory_entity==inventory and inventory.contents==37,'inventory replaced')
  check(record.power==power and power.energy==8000000,'power buffer replaced')
  check(copied==1,'saved wire was not copied')
  local unit=record.entity.unit_number;portals.upgrade_surface_vents()
  check(record.entity.unit_number==unit,'repeat upgrade recreated a vent')
end)

test('failed vent migration leaves the old opening and registry intact',function()
  local _,portals=modules(sparse,17)
  local cave=mock.surface('deep-caves-level-1','deep-caves-stone-1')
  local record=portals.create_endpoint(cave,{x=100,y=100},'deep-caves-ramp-up',1,0)
  local old=record.entity;old.name='deep-caves-ramp-up'
  mock.next_fail='deep-caves-vent';portals.upgrade_surface_vents()
  check(old.valid and record.entity==old,'failed migration destroyed the opening')
  check(storage.deep_caves.portals[old.unit_number]==record,'failed migration removed the registry entry')
end)

test('vent inventory clicks and walking travel use the original pairing code',function()
  local _,portals=modules(sparse,17)
  local cave=mock.surface('deep-caves-level-1','deep-caves-stone-1')
  local record=portals.create_endpoint(cave,{x=100,y=100},'deep-caves-ramp-up',1,0)
  local pair=assert(portals.ensure_pair(record))
  local player=mock.player(cave,{x=record.entity.position.x+5,y=record.entity.position.y})
  player.teleport(record.entity.position,cave)
  local inventory={valid=true};record.inventory_entity=inventory
  package.loaded['scripts.cargo'].ensure=function(r) return r.inventory_entity end
  portals.open_inventory{player_index=1,entity=record.entity}
  check(player.opened==inventory,'vent click did not open cargo')
  player.opened=nil;portals.tick_players()
  check(player.surface==pair.entity.surface and player.surface.name=='nauvis','vent did not return player to Nauvis')
end)

print(string.format('RESULT: %d passed, %d failed',passed,failed))
os.exit(failed==0 and 0 or 1)
