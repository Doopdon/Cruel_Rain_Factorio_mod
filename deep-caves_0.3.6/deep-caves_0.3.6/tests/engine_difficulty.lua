-- Disposable native checks; never required by production control.lua.
local surfaces=require('scripts.surfaces')
local silos
local major,minor,patch=script.active_mods['deep-caves']:match('^(%d+)%.(%d+)%.(%d+)$')
local has_silos=tonumber(major)>0 or tonumber(minor)>3 or (tonumber(minor)==3 and tonumber(patch)>=2)
if has_silos then silos=require('scripts.silos') end
local function setting(name,fallback)
 local value=settings.startup[name];return value and value.value or fallback
end
local research=setting('deep-caves-research-cost',has_silos and .1 or 1)
local rockets=setting('deep-caves-rocket-cost',has_silos and .1 or 1)
local surface_only=settings.startup['deep-caves-surface-silos-only']
surface_only=surface_only==nil or surface_only.value
local suite={}
local passed,failed=0,0
local function check(ok,message) assert(ok,message) end
local function test(name,fn)
 local ok,err=pcall(fn)
 if ok then passed=passed+1;log('DC_ENGINE PASS '..name)
 else failed=failed+1;log('DC_ENGINE FAIL '..name..': '..tostring(err)) end
end
local function flat(surface,p)
 surface.request_to_generate_chunks(p,1);surface.force_generate_chunk_requests()
 for _,entity in pairs(surface.find_entities_filtered{area={{p.x-12,p.y-12},{p.x+12,p.y+12}}}) do entity.destroy() end
 local tiles={}
 for x=p.x-12,p.x+12 do for y=p.y-12,p.y+12 do tiles[#tiles+1]={name='concrete',position={x=x,y=y}} end end
 surface.set_tiles(tiles)
end
local function drops(surface,p)
 local amount=0
 for _,item in pairs(surface.find_entities_filtered{type='item-entity',area={{p.x-12,p.y-12},{p.x+12,p.y+12}}}) do
  if item.stack.valid_for_read and item.stack.name=='rocket-silo' then amount=amount+item.stack.count end
 end
 return amount
end
local function setup(legacy)
 local force=game.forces.player
 local baseline={}
 if legacy then
  for name,technology in pairs(force.technologies) do
   if technology.research_unit_count>0 then
    local ingredients={}
    for _,i in ipairs(technology.research_unit_ingredients) do ingredients[#ingredients+1]={name=i.name,amount=i.amount} end
    baseline[name]={count=technology.research_unit_count,formula=technology.research_unit_count_formula,
     energy=technology.research_unit_energy,ingredients=ingredients}
   end
  end
 end
 force.technologies.military.researched=true
 local function unlock(technology)
  for _,prerequisite in pairs(technology.prerequisites) do unlock(prerequisite);prerequisite.researched=true end
 end
 unlock(force.technologies.automation)
 check(force.add_research('automation'),'could not begin saved research');force.research_progress=.4
 local p={x=4800,y=4800};flat(game.surfaces.nauvis,p)
 local silo=game.surfaces.nauvis.create_entity{name='rocket-silo',position=p,force=force}
 check(silo and silo.valid,'could not create saved surface silo');silo.rocket_parts=math.min(2,math.max(0,silo.prototype.rocket_parts_required-1))
 storage.deep_caves.difficulty_fixture={legacy=legacy,baseline=baseline,silo=silo,position=p,saved_parts=silo.rocket_parts,old_multiplier=research,research_count=force.current_research.research_unit_count}
 log('DC_ENGINE FIXTURE saved research, a completed technology and a surface silo with '..silo.rocket_parts..' rocket parts')
end
function suite.setup_upgrade_fixture() setup(true) end
function suite.setup_save_fixture() setup(false) end
function suite.prepare()
 local fixture=storage.deep_caves.difficulty_fixture
 local force=game.forces.player
 test('science costs follow the multiplier with a minimum of one and unchanged ingredients and times',function()
  local checked=0
  for name,old in pairs(fixture.baseline) do
   local t=force.technologies[name]
   local ratio=research/fixture.old_multiplier
   local expected=math.max(1,old.formula and math.floor(old.count*ratio) or math.ceil(old.count*ratio))
   check(t.research_unit_count==expected,name..' cost '..t.research_unit_count..' expected '..expected)
   check(t.research_unit_energy==old.energy,name..' research time changed')
   check(#t.research_unit_ingredients==#old.ingredients,name..' pack types changed')
   for i,ingredient in ipairs(t.research_unit_ingredients) do
    check(ingredient.name==old.ingredients[i].name and ingredient.amount==old.ingredients[i].amount,name..' ingredients changed')
   end
   checked=checked+1
  end
  if fixture.legacy then check(checked>100,'baseline did not include the research tree') end
  check(force.technologies['electric-mining-drill'].research_unit_count==math.max(1,math.ceil(25*research)),'25-unit technology did not follow multiplier')
  check(force.technologies['deep-caves-test-tiny-research'].research_unit_count==math.max(1,math.ceil(research)),'tiny research became free')
  log('DC_ENGINE SAMPLE compared '..checked..' saved technologies')
 end)
 test('infinite research scales by level and small formulas never become free',function()
  local damage=force.technologies['physical-projectile-damage-7']
  check(damage.research_unit_count==math.max(1,math.floor(1000*research)),'first infinite level cost is wrong')
  damage.level=8;check(damage.research_unit_count==math.max(1,math.floor(2000*research)),'next infinite level cost is wrong')
  local low=force.technologies['deep-caves-test-low-formula-1']
  check(low.research_unit_count==math.max(1,math.floor(research)),'small formula did not follow multiplier');low.level=4
  check(low.research_unit_count==math.max(1,math.floor(8*research)),'small higher-level formula did not follow multiplier')
 end)
 test('save upgrades retain completed research and current selection with native cost recalculation',function()
  check(force.technologies.military.researched,'completed research was reset')
  check(force.current_research and force.current_research.name=='automation','active research was reset')
  -- Native upgrades retain invested units if they fit the new count;
  -- a reduction below the invested units resets progress instead.
  local count=force.current_research.research_unit_count
  local invested=.4*fixture.research_count
  local expected=invested<=count and invested/count or 0
  check(math.abs(force.research_progress-expected)<.00001,'unexpected native progress after cost recalculation')
  log('DC_ENGINE SAMPLE research progress '..force.research_progress..' after '..(fixture.legacy and 'cost upgrade' or 'ordinary reload'))
 end)
 test('saved rocket silo retains its parts while launch cost becomes ten or five',function()
  local expected=math.max(1,math.ceil((script.active_mods['space-age'] and 50 or 100)*rockets))
  check(prototypes.entity['rocket-silo'].rocket_parts_required==expected,'rocket launch cost is wrong')
  check(fixture.silo.valid and fixture.silo.rocket_parts==fixture.saved_parts,'saved silo or its rocket parts were lost')
 end)
 test('outdoor rocket silos and ghosts remain buildable',function()
  local p={x=4840,y=4800};flat(game.surfaces.nauvis,p)
  check(game.surfaces.nauvis.can_place_entity{name='rocket-silo',position=p,force=force},'outdoor native placement was blocked')
  local entity=game.surfaces.nauvis.create_entity{name='rocket-silo',position=p,force=force,raise_built=true}
  check(entity and entity.valid,'outdoor script build was blocked');entity.destroy()
  local ghost=game.surfaces.nauvis.create_entity{name='entity-ghost',inner_name='rocket-silo',position=p,force=force,raise_built=true}
  check(ghost and ghost.valid,'outdoor ghost was blocked');ghost.destroy()
 end)
 if surface_only then
 test('every cave depth rejects scripted rocket silo placement with one refund',function()
  for depth=1,5 do
   local cave=surfaces.ensure(depth);local p={x=4900,y=4900};flat(cave,p)
   local entity=cave.create_entity{name='rocket-silo',position=p,force=force,raise_built=true}
   check(not (entity and entity.valid),'cave '..depth..' accepted silo')
   check(cave.count_entities_filtered{type='rocket-silo',position=p,radius=1}==0,'underground silo remains')
   check(drops(cave,p)==1,'cave '..depth..' lost or duplicated its refund')
   if script.active_mods['space-age'] then
    check(cave.get_property('deep-caves-above-ground')==0,'native cave property was not set')
    check(not cave.can_place_entity{name='rocket-silo',position=p,force=force},'native placement accepted underground silo')
   end
  end
 end)
 test('underground silo ghosts are rejected without a refund or robot rebuild loop',function()
  local cave=surfaces.ensure(1);local p={x=4940,y=4900};flat(cave,p)
  local ghost=cave.create_entity{name='entity-ghost',inner_name='rocket-silo',position=p,force=force,raise_built=true}
  check(not (ghost and ghost.valid),'underground ghost survived');check(drops(cave,p)==0,'ghost generated free silo item')
 end)
 test('robot refund keeps native item quality and returns only the consumed item',function()
  local cave=surfaces.ensure(1);local p={x=4980,y=4900};flat(cave,p)
  local quality=script.active_mods.quality and 'rare' or 'normal'
  local entity=cave.create_entity{name='rocket-silo',position=p,force=force,quality=quality}
  check(entity and entity.valid,'could not create refund fixture')
  local robot=cave.create_entity{name='construction-robot',position=p,force=force}
  local cargo=robot.get_inventory(defines.inventory.robot_cargo)
  local used=game.create_inventory(1);used.insert{name='rocket-silo',count=20,quality=quality}
  silos.built{entity=entity,robot=robot,stack=used[1]}
  check(not entity.valid and cargo.get_item_count{name='rocket-silo',quality=quality}==1,'robot refund lost quality or returned extra items')
  check(drops(cave,p)==0,'robot refund also spilled');used.destroy();robot.destroy()
 end)
 test('a full robot cargo spills exactly one quality silo',function()
  local cave=surfaces.ensure(1);local p={x=5020,y=4900};flat(cave,p)
  local quality=script.active_mods.quality and 'epic' or 'normal'
  local entity=cave.create_entity{name='rocket-silo',position=p,force=force,quality=quality}
  local robot=cave.create_entity{name='construction-robot',position=p,force=force}
  robot.get_inventory(defines.inventory.robot_cargo).insert{name='iron-plate',count=100}
  silos.built{entity=entity,robot=robot}
  check(drops(cave,p)==1,'full robot cargo lost or duplicated silo')
  local found=false
  for _,item in pairs(cave.find_entities_filtered{type='item-entity',position=p,radius=12}) do
   if item.stack.name=='rocket-silo' then found=item.stack.quality.name==quality end
  end
  check(found,'spilled refund lost quality');robot.destroy()
 end)
 test('clone and raised ghost revival cannot bypass underground placement',function()
  local cave=surfaces.ensure(1);local p={x=5060,y=4900};flat(cave,p)
  local clone=fixture.silo.clone{position=p,surface=cave,force=force}
  check(not (clone and clone.valid),'cloned silo survived underground');check(drops(cave,p)==1,'clone refund missing')
  p={x=5100,y=4900};flat(cave,p)
  local ghost=cave.create_entity{name='entity-ghost',inner_name='rocket-silo',position=p,force=force}
  if ghost then
   local _,entity=ghost.revive{raise_revive=true}
   check(not (entity and entity.valid),'revived silo survived underground')
   if ghost.valid then ghost.destroy() end
  end
 end)
 else
 test('disabled restriction permits underground builds, ghosts, clones and revivals',function()
  local cave=surfaces.ensure(1);local p={x=4900,y=4900};flat(cave,p)
  check(cave.can_place_entity{name='rocket-silo',position=p,force=force},'native placement remains blocked')
  local entity=cave.create_entity{name='rocket-silo',position=p,force=force,raise_built=true}
  check(entity and entity.valid,'disabled guard rejected the silo');entity.destroy()
  local ghost=cave.create_entity{name='entity-ghost',inner_name='rocket-silo',position=p,force=force,raise_built=true}
  check(ghost and ghost.valid,'disabled guard rejected a ghost')
  local _,revived=ghost.revive{raise_revive=true};check(revived and revived.valid,'disabled guard rejected revival');revived.destroy()
  local clone=fixture.silo.clone{position=p,surface=cave,force=force}
  check(clone and clone.valid,'disabled guard rejected clone');clone.destroy()
  check(drops(cave,p)==0,'disabled guard refunded valid placement')
 end)
 end
 test('other underground machines still build normally',function()
  local cave=surfaces.ensure(1);local p={x=5140,y=4900};flat(cave,p)
  local entity=cave.create_entity{name='assembling-machine-1',position=p,force=force,raise_built=true}
  check(entity and entity.valid,'restriction affected other machines')
 end)
 local silo=fixture.silo;local p=fixture.position
 silo.rocket_parts=silo.prototype.rocket_parts_required-1
 force.recipes['rocket-part'].enabled=true
 for _,ingredient in ipairs(force.recipes['rocket-part'].ingredients) do
  check(silo.insert{name=ingredient.name,count=ingredient.amount}==ingredient.amount,'could not fill final rocket-part craft')
 end
 silo.crafting_progress=.95
 local pole=game.surfaces.nauvis.create_entity{name='substation',position={x=p.x+7,y=p.y},force=force}
 local supply=game.surfaces.nauvis.create_entity{name='electric-energy-interface',position={x=p.x+10,y=p.y},force=force}
 check(pole and supply,'could not create rocket test supply');supply.power_production=1000000000
end
function suite.run()
 local silo=storage.deep_caves.difficulty_fixture.silo
 test('native rocket crafting finishes after the tenth or fifth part',function()
  check(silo.rocket_parts>=silo.prototype.rocket_parts_required or silo.rocket_silo_status~=defines.rocket_silo_status.building_rocket,
   'final discounted rocket part did not finish construction: '..silo.rocket_parts..' parts')
 end)
 log(string.format('DC_ENGINE RESULT %d passed, %d failed',passed,failed))
 if failed>0 then error('Cruel Rain native difficulty checks failed') end
end
return suite
