-- Loaded only by the disposable native-engine runner, never ordinary games.
local portals=require("scripts.portals")
local suite={}
local passed,failed=0,0
local function check(ok,message) assert(ok,message) end
local function test(name,fn)
  local ok,err=pcall(fn)
  if ok then passed=passed+1;log("DC_ENGINE PASS "..name)
  else failed=failed+1;log("DC_ENGINE FAIL "..name..": "..tostring(err)) end
end
local function connector(entity,id) return entity.get_wire_connector(id,true) end

-- Runs in 0.2.19 on_init before that save is written. The new mod's actual
-- on_configuration_changed handler must retain these objects and connections.
function suite.setup_upgrade_fixture()
  local state=storage.deep_caves
  local source=state.portals[state.starting_entrance]
  local record=state.portals[source.pair_unit]
  local old=record.entity
  check(old.name=="deep-caves-ramp-up","upgrade fixture is not an old ascent")
  local inventory=record.inventory_entity.get_inventory(defines.inventory.chest)
  check(inventory.insert{name="coal",count=37}==37,"could not fill old shared cargo")
  inventory.set_filter(1,"coal")
  source.power.energy=8000000;record.power.energy=8000000
  local p=old.position
  local pole=old.surface.create_entity{name="medium-electric-pole",position={x=p.x+2.5,y=p.y},force=old.force}
  check(pole~=nil,"could not create saved wire target")
  for _,c in pairs(pole.get_wire_connectors(false)) do
    for _,wire in pairs(c.connections) do c.disconnect_from(wire.target,wire.origin) end
  end
  for _,id in ipairs({defines.wire_connector_id.pole_copper,
    defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}) do
    check(connector(old,id).connect_to(connector(pole,id),false,defines.wire_origin.player),"could not create saved wire on connector "..id)
  end
  state.vent_upgrade_fixture={source_unit=source.entity.unit_number,old_unit=old.unit_number,
    inventory=record.inventory_entity,power=record.power,pole=pole,position=old.position}
  log("DC_ENGINE UPGRADE FIXTURE saved 37 coal, a slot filter, 8 MJ and copper/red/green wires")
end

function suite.prepare()
  local state=storage.deep_caves
  test("new and upgraded surface openings are registered native vents",function()
    local source=state.portals[state.starting_entrance]
    local record=state.portals[source.pair_unit]
    check(record.entity.name=="deep-caves-vent","primary opening was not renamed to a vent")
    check(record.entity.localised_name[1]=="entity-name.deep-caves-vent","vent name key missing")
    check(record.pair_unit==source.entity.unit_number,"asymmetric vent pairing")
    check(record.inventory_entity.link_id==source.inventory_entity.link_id,"vent cargo link changed")
  end)
  if state.vent_upgrade_fixture then
    test("real 0.2.19 save upgrade retains cargo, filters, power and all saved wires",function()
      local saved=state.vent_upgrade_fixture
      local source=state.portals[saved.source_unit]
      local record=state.portals[source.pair_unit]
      check(state.portals[saved.old_unit]==nil,"old pole remains registered")
      check(record.entity.name=="deep-caves-vent","old ascent was not converted")
      check(record.entity.position.x==saved.position.x and record.entity.position.y==saved.position.y,"vent moved")
      check(record.inventory_entity==saved.inventory and saved.inventory.valid,"cargo entity was replaced")
      local inventory=saved.inventory.get_inventory(defines.inventory.chest)
      check(inventory.get_item_count("coal")==37,"saved coal lost")
      check(inventory.get_filter(1).name=="coal","saved slot filter lost")
      check(record.power==saved.power and saved.power.valid,"energy buffer was replaced")
      check(math.abs(saved.power.energy-8000000)<1,"stored energy changed")
      for _,id in ipairs({defines.wire_connector_id.pole_copper,
        defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}) do
        local found=false
        local expected=connector(saved.pole,id)
        for _,wire in pairs(connector(record.entity,id).connections) do
          if wire.target==expected then found=true end
        end
        check(found,"saved wire lost on connector "..id)
      end
      local unit=record.entity.unit_number;portals.upgrade_surface_vents()
      check(record.entity.unit_number==unit,"repeat upgrade recreated the vent")
    end)
  end
  local surface=game.create_surface("deep-caves-vent-tests",{width=1024,height=64,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},
      decorative={treat_missing_as_default=false,settings={}}}})
  surface.request_to_generate_chunks({0,0},12);surface.force_generate_chunk_requests()
  -- Clear unrelated native entities; the mock does not model this mechanism.
  for _,entity in pairs(surface.find_entities_filtered{}) do entity.destroy() end
  game.map_settings.pollution.enabled=true
  game.map_settings.pollution.ageing=0
  game.map_settings.pollution.diffusion_ratio=0
  local positions={single={x=16,y=16},double={x=80,y=16},empty={x=144,y=16},
    low={x=208,y=16},ascent={x=272,y=16},descent={x=336,y=16}}
  for name,p in pairs(positions) do surface.pollute(p,name=="low" and .01 or 100) end
  for _,p in ipairs({positions.single,positions.double,{x=88,y=16},positions.low}) do
    check(surface.create_entity{name="deep-caves-vent",position=p,force="player"}~=nil,"vent fixture creation failed")
  end
  check(surface.create_entity{name="deep-caves-ramp-up",position=positions.ascent,force="player"}~=nil,"ascent fixture creation failed")
  check(surface.create_entity{name="deep-caves-ramp-down",position=positions.descent,force="player"}~=nil,"descent fixture creation failed")
  state.vent_pollution_fixture={surface=surface,positions=positions,start_tick=game.tick}
  log("DC_ENGINE PREPARED native vent absorption")
end

function suite.run()
  local fixture=storage.deep_caves.vent_pollution_fixture
  local surface,positions=fixture.surface,fixture.positions
  local single=100-surface.get_pollution(positions.single)
  local double=100-surface.get_pollution(positions.double)
  log(string.format("DC_ENGINE SAMPLE %.6f pollution removed by one vent; %.6f by two over %d ticks",
    single,double,game.tick-fixture.start_tick))
  test("unpowered vents absorb cave pollution through native negative emissions",function()
    local rate=settings.startup["deep-caves-vent-absorption"].value
    check(math.abs(single-rate*3/60)<.00001,"vent did not absorb at the configured native cadence")
    check(surface.get_pollution(positions.empty)==100,"control chunk lost pollution without a vent")
  end)
  test("multiple vents in one chunk add their absorption",function()
    check(math.abs(double-2*single)<.00001,"two vents did not absorb twice as much")
  end)
  test("vents stop at zero pollution without producing negative pollution",function()
    local rate=settings.startup["deep-caves-vent-absorption"].value
    check(math.abs(surface.get_pollution(positions.low)-math.max(0,.01-rate*3/60))<.00001,"near-empty chunk did not respect the configured rate")
  end)
  test("ordinary ascents and descents do not acquire surface ventilation",function()
    check(surface.get_pollution(positions.ascent)==100,"ordinary ascent absorbed pollution")
    check(surface.get_pollution(positions.descent)==100,"descent absorbed pollution")
  end)
  log(string.format("DC_ENGINE RESULT %d passed, %d failed",passed,failed))
  if failed>0 then error("Deep Caves native vent checks failed") end
end
return suite
