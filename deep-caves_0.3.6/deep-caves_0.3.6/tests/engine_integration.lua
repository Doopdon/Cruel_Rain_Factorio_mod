-- Temporary native checks; no test handlers are installed in normal games.
local portals=require("scripts.portals")
local generation=require("scripts.generation")
local daylight=require("scripts.daylight")
local bundled=not script.active_mods["cave-walls"]
local wall_manager=bundled and require("scripts.cave_walls.walls")
local storm=bundled and require("scripts.weather.storm")
local weather_controller=bundled and require("scripts.weather.control")
local suite={}
local passed,failed=0,0
local function check(ok,message) assert(ok,message) end
local function test(name,fn)
  local ok,err=pcall(fn)
  if ok then passed=passed+1;log("DC_ENGINE PASS "..name)
  else failed=failed+1;log("DC_ENGINE FAIL "..name..": "..tostring(err)) end
end
local function primary()
  local state=storage.deep_caves
  local source=state.portals[state.starting_entrance]
  return source,state.portals[source.pair_unit]
end
local function empty_surface(name)
  local surface=game.create_surface(name,{width=64,height=64,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},
      decorative={treat_missing_as_default=false,settings={}}}})
  surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
  local tiles={}
  for x=-32,31 do for y=-32,31 do tiles[#tiles+1]={name="stone-path",position={x,y}} end end
  surface.set_tiles(tiles,false,false,false)
  for _,entity in pairs(surface.find_entities_filtered{}) do entity.destroy() end
  return surface
end
function suite.setup_upgrade_fixture()
  local source,record=primary()
  local inventory=record.inventory_entity.get_inventory(defines.inventory.chest)
  check(inventory.insert{name="coal",count=37}==37,"could not fill old cargo")
  inventory.set_filter(1,"coal")
  source.power.energy=8000000;record.power.energy=8000000
  local p=record.entity.position
  local pole=record.entity.surface.create_entity{name="medium-electric-pole",position={x=p.x+2.5,y=p.y},force="player"}
  check(pole~=nil,"could not add old ramp wires")
  for _,connector in pairs(pole.get_wire_connectors(false)) do
    for _,wire in pairs(connector.connections) do connector.disconnect_from(wire.target,wire.origin) end
  end
  for _,id in ipairs({defines.wire_connector_id.pole_copper,defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}) do
    check(record.entity.get_wire_connector(id,true).connect_to(pole.get_wire_connector(id,true),false,defines.wire_origin.player),"old wire failed")
  end
  local surface=empty_surface("deep-caves-upgrade-fixture")
  local tiles={};for y=-10,10 do tiles[#tiles+1]={name="cave-wall",position={0,y}} end
  surface.set_tiles(tiles,false,false,false)
  remote.call("cave-walls","sync_area",surface.index,{left_top={x=-1,y=-11},right_bottom={x=2,y=12}})
  local helpers=surface.find_entities_filtered{name={"cave-wall-collision","cave-wall-visual"}}
  check(#helpers>0,"old wall helpers missing")
  local inactive=surface.create_entity{name="gun-turret",position={-10,15},force="player"}
  inactive.active=false
  storage.deep_caves.bundle_upgrade_fixture={vent=record.entity,inventory=record.inventory_entity,
    power=record.power,pole=pole,helpers=helpers,surface=surface,inactive=inactive,
    weather_setting=settings.global["surface-thunderstorm-enabled"].value}
  log("DC_ENGINE UPGRADE FIXTURE original vent, 37 coal, filter, 8 MJ, wires and "..#helpers.." wall helpers")
end
function suite.prepare()
  test("only the combined Deep Caves mod supplies both compatibility interfaces",function()
    check(not script.active_mods["cave-walls"] and not script.active_mods["surface-thunderstorm"],"standalone component is still enabled")
    check(remote.interfaces["cave-walls"].sync_area and remote.interfaces["surface-thunderstorm"].get_weather,"bundled interface missing")
  end)
  local source,record=primary()
  test("cave creation, native vents and shared cargo survive combined initialization",function()
    check(record.entity.name=="deep-caves-vent" and record.entity.surface.name=="deep-caves-level-1","primary vent missing")
    check(source.pair_unit==record.entity.unit_number and record.pair_unit==source.entity.unit_number,"broken pair")
    check(source.inventory_entity.link_id==record.inventory_entity.link_id,"broken shared cargo")
  end)
  local saved=storage.deep_caves.bundle_upgrade_fixture
  if saved then
    test("three-mod save upgrade retains vent identity, cargo, filters, power and wires",function()
      check(record.entity==saved.vent and saved.vent.valid,"existing vent was replaced")
      check(record.inventory_entity==saved.inventory and saved.inventory.valid,"existing inventory was replaced")
      local inventory=saved.inventory.get_inventory(defines.inventory.chest)
      check(inventory.get_item_count("coal")==37 and inventory.get_filter(1).name=="coal","cargo or filter lost")
      check(record.power==saved.power and math.abs(saved.power.energy-8000000)<1,"power buffer or charge lost")
      for _,id in ipairs({defines.wire_connector_id.pole_copper,defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}) do
        local expected=saved.pole.get_wire_connector(id,true);local found=false
        for _,wire in pairs(record.entity.get_wire_connector(id,true).connections) do if wire.target==expected then found=true end end
        check(found,"saved wire lost")
      end
      check(settings.global["surface-thunderstorm-enabled"].value==saved.weather_setting,"map weather setting changed")
    end)
    test("legacy boundary helpers are reused and deliberately inactive turrets stay inactive",function()
      local helpers=saved.surface.find_entities_filtered{name={"cave-wall-collision","cave-wall-visual"}}
      check(#helpers==#saved.helpers,"old boundary helpers were duplicated")
      for _,entity in pairs(saved.helpers) do check(entity.valid,"old boundary helper was discarded") end
      check(saved.inactive.valid and not saved.inactive.active,"deliberately inactive turret was enabled")
    end)
  end
  local p=record.entity.position
  test("renamed native vents transmit weather on Cave 1 and respect remote view",function()
    local player={connected=true,surface=record.entity.surface,physical_surface=record.entity.surface,physical_position={x=p.x+2,y=p.y}}
    local opening,gain=storm.nearest_opening(player)
    check(opening and gain>0,"weather missed the renamed vent")
    player.surface=game.surfaces.nauvis
    check(storm.nearest_opening(player)==nil,"remote map camera triggered cave audio")
  end)
  test("native weather cleanup preserves cave skylights and puddles",function()
    game.surfaces.nauvis.always_day=true
    storage.deep_caves.daylight_cache={nearby={record},player_key="",refresh_tick=game.tick+1000}
    storm.strike();daylight.update()
    local light=record.daylight
    check(light and light.valid and light.intensity==1,"vent did not receive native lightning")
    local view=storm.create_view(game.surfaces.nauvis)
    storm.update_view(view,{x=0,y=0},1,{width=800,height=600},{darkness=.45,rain=1,lightning=true,volume=.55})
    check(view.shade.valid and view.flash.valid and next(view.rain)~=nil,"native rain or shade not created")
    local shade=view.shade;storage.surface_thunderstorm.views[999]=view
    weather_controller.configuration_changed()
    check(not shade.valid and light.valid,"weather reload removed the cave skylight")
    check(record.entrance_puddle_version==1,"vent puddle state lost")
  end)
  local fixtures={combat={},phase="blocked"}
  storage.deep_caves.integration_fixture=fixtures
  for _,name in ipairs({"gun-turret","laser-turret","flamethrower-turret"}) do
    local surface=empty_surface("deep-caves-integration-"..name)
    local area={left_top={x=0,y=-10},right_bottom={x=1,y=11}}
    wall_manager.paint(surface,area,false)
    local target=surface.create_entity{name="biter-spawner",position={8.5,.5},force="enemy"};target.disabled_by_script=true
    local turret=surface.create_entity{name=name,position={-8.5,.5},direction=defines.direction.east,force="player",raise_built=true}
    check(turret~=nil,"native turret fixture failed")
    local ammo
    if name=="gun-turret" then turret.insert{name="firearm-magazine",count=5};ammo=turret.get_inventory(defines.inventory.turret_ammo)[1].ammo
    elseif name=="flamethrower-turret" then turret.set_fluid(1,{name="crude-oil",amount=100})
    else turret.energy=turret.electric_buffer_size end
    check(storage.cave_wall_turrets[turret.unit_number]==turret,"shared build event did not register the turret")
    fixtures.combat[#fixtures.combat+1]={name=name,turret=turret,target=target,health=target.health,surface=surface,area=area,ammo=ammo}
  end
  local surface=empty_surface("deep-caves-integration-flying")
  wall_manager.paint(surface,{left_top={x=0,y=-10},right_bottom={x=1,y=11}},false)
  local bot=surface.create_entity{name="construction-robot",position={-4.5,.5},force="player"}
  fixtures.bot=bot;fixtures.bot_move_tick=game.tick+1
  fixtures.projectile_target=surface.create_entity{name="wooden-chest",position={5.5,5.5},force="enemy"}
  local bullet_name
  for name in pairs(prototypes.entity) do if name:match("^cave%-wall%-turret%-bullet%-firearm%-magazine%-%d+$") then bullet_name=name;break end end
  check(bullet_name~=nil,"native turret bullet prototype missing")
  local bullet=surface.create_entity{name=bullet_name,position={-5.5,5.5},target=fixtures.projectile_target,speed=.8,force="player"}
  check(bullet~=nil,"native projectile fixture failed")
  fixtures.bullet=bullet;fixtures.projectile_health=fixtures.projectile_target.health
  test("native flying creation effects reach the shared script-trigger handler",function()
    check(storage.cave_walls.flying["u"..bot.unit_number]~=nil,"construction robot was not tracked")
    local found=false
    for _,entry in pairs(storage.cave_walls.flying) do if entry.entity==bullet then found=true end end
    check(found,"moving bullet was not tracked")
  end)
  local nauvis=game.surfaces.nauvis
  nauvis.request_to_generate_chunks({80,80},1);nauvis.force_generate_chunk_requests()
  local pos=nauvis.find_non_colliding_position("steel-chest",{80,80},40,.5)
  fixtures.surface_chest=nauvis.create_entity{name="steel-chest",position=pos,force="player"}
  fixtures.surface_health=fixtures.surface_chest.health
  local cave=record.entity.surface
  fixtures.cave_chest=cave.create_entity{name="steel-chest",position={x=p.x+4,y=p.y-3},force="player"}
  check(fixtures.cave_chest~=nil,"sheltered chest fixture failed")
  fixtures.cave_health=fixtures.cave_chest.health
  log("DC_ENGINE PREPARED combined wall, weather and combat integration")
end
local function finish()
  log(string.format("DC_ENGINE RESULT %d passed, %d failed",passed,failed))
  if failed>0 then error("Deep Caves combined integration checks failed") end
end
function suite.run()
  local fixture=storage.deep_caves.integration_fixture
  for _,combat in ipairs(fixture.combat) do
    test(combat.name.." holds fire against a target behind native cave walls",function()
      -- Spawners regenerate a small floating-point amount even at full health.
      check(combat.target.valid and combat.target.health>=combat.health,"blocked target was damaged")
      if combat.name=="gun-turret" then
        local stack=combat.turret.get_inventory(defines.inventory.turret_ammo)[1]
        check(stack.count==5 and stack.ammo==combat.ammo,"blocked target consumed rounds")
      elseif combat.name=="flamethrower-turret" then
        check(combat.turret.get_fluid(1).amount==100,"blocked target consumed oil")
      end
    end)
  end
  test("shared tick processing intercepts fast robot crossings and moving bullets",function()
    check(not fixture.bot.valid,"robot crossed a one-tile wall")
    check(not fixture.bullet.valid,"bullet crossed a cave wall")
    check(fixture.projectile_target.valid and fixture.projectile_target.health==fixture.projectile_health,"intercepted projectile damaged its target")
  end)
  test("surface exposure runs alongside cave population while caves remain sheltered",function()
    check(fixture.surface_chest.health<fixture.surface_health,"surface exposure stopped after event merge")
    check(fixture.cave_chest.health==fixture.cave_health,"weather damaged a sheltered building")
  end)
  for _,combat in ipairs(fixture.combat) do wall_manager.paint(combat.surface,combat.area,true) end
  fixture.phase="clear";fixture.finish_tick=game.tick+137
  fixture.weather_off_health=fixture.surface_chest.health
  storage.surface_thunderstorm.override=false;storm.clear_views()
end
function suite.tick(event)
  local fixture=storage.deep_caves and storage.deep_caves.integration_fixture
  if not fixture then return end
  for _,combat in ipairs(fixture.combat) do
    if combat.name=="laser-turret" and combat.turret.valid then combat.turret.energy=combat.turret.electric_buffer_size end
  end
  if fixture.bot_move_tick==event.tick and fixture.bot.valid then fixture.bot.teleport({x=4.5,y=.5}) end
  if fixture.phase=="clear" and event.tick>=fixture.finish_tick then
    fixture.phase="done"
    for _,combat in ipairs(fixture.combat) do
      test(combat.name.." resumes normal damage after its wall is erased",function()
        check(not combat.target.valid or combat.target.health<combat.health,"turret remained paused on a clear path")
        check(combat.surface.get_tile(0,0).name=="stone-path","brush did not restore original terrain")
      end)
    end
    test("turning weather off stops surface damage without affecting wall processing",function()
      check(fixture.surface_chest.health==fixture.weather_off_health,"disabled storm kept damaging buildings")
      check(storage.cave_walls~=nil,"weather command cleared wall state")
    end)
    finish()
  end
end
return suite
