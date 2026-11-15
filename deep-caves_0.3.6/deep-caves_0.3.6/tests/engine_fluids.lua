-- Actual engine plumbing, GUI and filled-save checks; never loaded in production.
local portals=require("scripts.portals")
local cargo=require("scripts.cargo")
local major,minor,patch=script.active_mods["deep-caves"]:match("^(%d+)%.(%d+)%.(%d+)$")
local has_fluids=tonumber(major)>0 or tonumber(minor)>3 or (tonumber(minor)==3 and tonumber(patch)>=1)
local fluids=has_fluids and require("scripts.fluids")
local compact_ports=tonumber(major)>0 or tonumber(minor)>3 or (tonumber(minor)==3 and tonumber(patch)>=3)
local port_distance=compact_ports and 2 or 3
local suite={}
local passed,failed=0,0
local function check(ok,message) assert(ok,message) end
local function close(a,b) return math.abs(a-b)<.0001 end
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
local function center(record)
  return {x=math.floor(record.entity.position.x)+.5,y=math.floor(record.entity.position.y)+.5}
end
local function pipe(record,dx,dy,raised)
  local p=center(record);p.x=p.x+dx;p.y=p.y+dy
  check(record.entity.surface.can_place_entity{name="pipe",position=p,force="player"},"pipe port overlaps the protected ramp")
  return assert(record.entity.surface.create_entity{name="pipe",position=p,force="player",raise_built=raised})
end
local function amount(entities,name)
  local total=0;for _,entity in ipairs(entities) do if entity.valid then total=total+entity.get_fluid_count(name) end end
  return total
end
local function save_fixture(old)
  local source,record=primary()
  local inventory=record.inventory_entity.get_inventory(defines.inventory.chest)
  check(inventory.insert{name="coal",count=37}==37,"saved cargo setup failed")
  inventory.set_filter(1,"coal")
  source.power.energy=8000000;record.power.energy=8000000
  local p=record.entity.position
  local pole=record.entity.surface.create_entity{name="medium-electric-pole",position={x=p.x+2.5,y=p.y},force="player"}
  check(pole~=nil,"saved wire target missing")
  for _,connector in pairs(pole.get_wire_connectors(false)) do
    for _,connection in pairs(connector.connections) do connector.disconnect_from(connection.target,connection.origin) end
  end
  for _,id in ipairs({defines.wire_connector_id.pole_copper,defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}) do
    check(record.entity.get_wire_connector(id,true).connect_to(pole.get_wire_connector(id,true),false,defines.wire_origin.player),"saved wire failed")
  end
  local first,second=pipe(source,0,-port_distance),pipe(record,0,-port_distance)
  check(close(first.add_fluid(1,{name="water",amount=75,temperature=25}),75),"first saved fluid insertion failed")
  check(close(second.add_fluid(1,{name="water",amount=40,temperature=75}),40),"second saved fluid insertion failed")
  storage.deep_caves.fluid_save_fixture={old=old,source=source.entity,vent=record.entity,
    inventory=record.inventory_entity,power=record.power,pole=pole,pipes={first,second},
    source_fluid=source.fluid_entity,target_fluid=record.fluid_entity,expected=115,temperature=(75*25+40*75)/115}
  log("DC_ENGINE SAVED "..(old and "legacy pipes" or "native linked fluid buffers")..", 115 water, 37 coal, filter, 8 MJ and wires")
end
function suite.setup_upgrade_fixture() save_fixture(true) end
function suite.setup_save_fixture() save_fixture(false) end
local function empty_surface(name)
  local surface=game.create_surface(name,{width=128,height=128,
    autoplace_settings={entity={treat_missing_as_default=false,settings={}},decorative={treat_missing_as_default=false,settings={}}}})
  surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
  for _,entity in pairs(surface.find_entities_filtered{}) do entity.destroy() end
  local tiles={};for x=-64,63 do for y=-64,63 do tiles[#tiles+1]={name="stone-path",position={x,y}} end end
  surface.set_tiles(tiles,false,false,false)
  return surface
end
function suite.prepare()
  local source,record=primary()
  local saved=storage.deep_caves.fluid_save_fixture
  test("filled save reload or 0.3.0 upgrade preserves ramp identities, cargo, power and wires",function()
    check(source.entity==saved.source and record.entity==saved.vent,"ramp was replaced")
    check(record.inventory_entity==saved.inventory and record.power==saved.power,"existing helpers were replaced")
    local inventory=saved.inventory.get_inventory(defines.inventory.chest)
    check(inventory.get_item_count("coal")==37 and inventory.get_filter(1).name=="coal","cargo or filter lost")
    check(close(saved.power.energy,8000000),"saved power changed")
    for _,id in ipairs({defines.wire_connector_id.pole_copper,defines.wire_connector_id.circuit_red,defines.wire_connector_id.circuit_green}) do
      local found=false
      for _,connection in pairs(record.entity.get_wire_connector(id,true).connections) do
        if connection.target==saved.pole.get_wire_connector(id,true) then found=true end
      end
      check(found,"saved wire lost")
    end
  end)
  test("fluid survives filled-save reload and existing pipes connect on upgrade",function()
    local first,second=source.fluid_entity,record.fluid_entity
    check(first and second and first.valid and second.valid,"fluid buffer missing")
    check(first.get_fluid_box_linked_connection(1)==second,"saved fluid link missing")
    local entities={first,second,saved.pipes[1],saved.pipes[2]}
    check(close(amount(entities,"water"),saved.expected),"saved water was lost or duplicated")
    check(close(first.get_fluid(1).temperature,saved.temperature),"saved fluid heat changed")
    if not saved.old then check(first==saved.source_fluid and second==saved.target_fluid,"saved buffers were replaced") end
  end)
  test("fluid upgrade is idempotent and recovers existing native buffer references",function()
    local first,second=source.fluid_entity,record.fluid_entity
    local before=amount({first,second,saved.pipes[1],saved.pipes[2]},"water")
    record.fluid_entity=nil
    check(fluids.ensure(record)==second,"reference recovery created a duplicate")
    fluids.upgrade();fluids.upgrade()
    check(source.fluid_entity==first and record.fluid_entity==second,"upgrade recreated a buffer")
    check(close(amount({first,second,saved.pipes[1],saved.pipes[2]},"water"),before),"upgrade changed fluid amount")
  end)
  test("legacy outer pipes can reconnect through a new inner pipe without moving them",function()
    local entities={source.fluid_entity,record.fluid_entity,saved.pipes[1],saved.pipes[2]}
    for i,ramp in ipairs({source,record}) do
      local p=center(ramp)
      if saved.pipes[i].position.y==p.y-3 then
        local inner=pipe(ramp,0,-2);entities[#entities+1]=inner
        check(inner.get_fluid_segment_id(1)==ramp.fluid_entity.get_fluid_segment_id(1),"inner adapter did not connect")
        check(saved.pipes[i].get_fluid_segment_id(1)==inner.get_fluid_segment_id(1),"old pipe remains isolated")
      end
    end
    check(close(amount(entities,"water"),saved.expected),"adapters lost or duplicated water")
  end)
  local left,right=empty_surface("deep-caves-fluid-left"),empty_surface("deep-caves-fluid-right")
  local function pair(x,y,offgrid)
    local p={x=x+(offgrid and .17 or .5),y=y+(offgrid and .92 or .5)}
    local a=portals.create_endpoint(left,p,"deep-caves-ramp-down",0,1)
    local b=portals.create_endpoint(right,p,"deep-caves-ramp-up",1,0)
    check(a and b,"fluid fixture ramp creation failed")
    a.pair_unit=b.entity.unit_number;b.pair_unit=a.entity.unit_number
    cargo.connect(a,b)
    return a,b
  end
  local fixtures={}
  local a,b=pair(-40,-40,true)
  check(fluids.connect(a,b),"native fluid link failed")
  local pipes={}
  test("all four pipe ports work beside older off-grid ramps",function()
    for _,offset in ipairs({{0,-2},{2,0},{0,2},{-2,0}}) do pipes[#pipes+1]=pipe(a,offset[1],offset[2]) end
    pipes[#pipes+1]=pipe(b,2,0)
    check(not left.can_place_entity{name="pipe",position=center(a),force="player"},"ramp center no longer blocks construction")
    local id=a.fluid_entity.get_fluid_segment_id(1)
    for _,p in ipairs(pipes) do check(p.get_fluid_segment_id(1)==id,"side pipe did not join the ramp network") end
  end)
  fixtures.water={a=a,b=b,pipes=pipes,entities={a.fluid_entity,b.fluid_entity,table.unpack(pipes)}}
  check(close(a.fluid_entity.add_fluid(1,{name="water",amount=1000,temperature=30}),1000),"water fixture insertion failed")
  local oil_a,oil_b=pair(-16,-40)
  check(fluids.connect(oil_a,oil_b),"oil link failed")
  check(close(oil_a.fluid_entity.add_fluid(1,{name="crude-oil",amount=500}),500),"oil fixture insertion failed")
  fixtures.oil={a=oil_a,b=oil_b}
  local steam_a,steam_b=pair(8,-40)
  local hot=steam_a.fluid_entity.add_fluid(1,{name="steam",amount=900,temperature=500})
  local cool=steam_b.fluid_entity.add_fluid(1,{name="steam",amount=900,temperature=165})
  check(close(hot,900),"hot steam insertion failed")
  check(close(cool,900),"cool steam insertion failed")
  check(fluids.connect(steam_a,steam_b),"steam link failed")
  local extra=steam_a.fluid_entity.add_fluid(1,{name="steam",amount=500,temperature=500})
  if extra<500 then
    extra=extra+steam_b.fluid_entity.add_fluid(1,{name="steam",amount=500-extra,temperature=500})
  end
  local overflow=steam_a.fluid_entity.add_fluid(1,{name="steam",amount=500,temperature=500})
  if overflow<500 then
    overflow=overflow+steam_b.fluid_entity.add_fluid(1,{name="steam",amount=500-overflow,temperature=500})
  end
  local steam_amount=amount({steam_a.fluid_entity,steam_b.fluid_entity},"steam")
  check(steam_amount>1800 and steam_amount<=2000,"native buffers exceeded their combined capacity")
  check(extra+overflow<=200,"native buffers accepted more than their remaining capacity")
  fixtures.steam={a=steam_a,b=steam_b,amount=steam_amount,
    temperature=(900*500+900*165+(extra+overflow)*500)/steam_amount}
  local conflict_a,conflict_b=pair(32,-40)
  check(close(conflict_a.fluid_entity.add_fluid(1,{name="water",amount=500}),500),"conflict water setup failed")
  check(close(conflict_b.fluid_entity.add_fluid(1,{name="crude-oil",amount=300}),300),"conflict oil setup failed")
  test("different fluids block linking without deleting or converting either network",function()
    check(not fluids.connect(conflict_a,conflict_b),"conflicting networks were linked")
    check(conflict_a.fluid_entity.get_fluid_box_linked_connection(1)==nil,"conflicting link was created")
    check(close(conflict_a.fluid_entity.get_fluid_count("water"),500),"water changed on conflict")
    check(close(conflict_b.fluid_entity.get_fluid_count("crude-oil"),300),"oil changed on conflict")
  end)
  conflict_b.fluid_entity.clear_fluid(1)
  fixtures.conflict={a=conflict_a,b=conflict_b}
  local lazy=portals.create_endpoint(left,{x=-40.5,y=-8.5},"deep-caves-ramp-down",0,1)
  test("building a pipe activates an unused ramp's destination",function()
    check(lazy.pair_unit==nil,"unused ramp paired too early")
    local connected=pipe(lazy,2,0,true)
    check(connected.valid and lazy.pair_unit~=nil,"native build event did not prepare the matching ramp")
    local target=storage.deep_caves.portals[lazy.pair_unit]
    check(lazy.fluid_entity.get_fluid_box_linked_connection(1)==target.fluid_entity,"new destination has no fluid link")
  end)
  test("fluid inventory uses native tank storage alongside the existing cargo inventory",function()
    check(a.fluid_entity.type=="storage-tank" and a.inventory_entity.type=="linked-container","inventory entity types changed")
    check(a.fluid_entity.get_fluid_box_prototype(1).get_volume()==1000,"native endpoint capacity changed")
    check(defines.relative_gui_type.pipe_gui and defines.relative_gui_type.linked_container_gui,"native inventory GUI anchors missing")
  end)
  storage.deep_caves.fluid_engine_fixture=fixtures
  log("DC_ENGINE PREPARED native water, oil, steam, fluid conflict and four-side ports")
end
function suite.run()
  local fixtures=storage.deep_caves.fluid_engine_fixture
  local water=fixtures.water
  test("native pipe flow crosses cave layers and conserves fluid",function()
    check(water.b.fluid_entity.get_fluid_count("water")>0 and water.pipes[5].get_fluid_count("water")>0,"destination stayed dry")
    check(close(amount(water.entities,"water"),1000),"native flow lost or duplicated water")
  end)
  test("fluid transfer works in both directions and preserves temperature",function()
    check(close(water.b.fluid_entity.remove_fluid(1,100).amount,100),"destination could not draw fluid")
    check(close(water.b.fluid_entity.add_fluid(1,{name="water",amount=250,temperature=30}),250),"reverse insertion failed")
    check(close(amount(water.entities,"water"),1150),"bidirectional transfer changed the total")
    check(close(water.a.fluid_entity.get_fluid(1).temperature,30),"water temperature changed")
  end)
  test("separate ramp pairs retain separate fluids",function()
    local oil=fixtures.oil
    check(oil.b.fluid_entity.get_fluid_count("crude-oil")>0,"oil did not cross layers")
    check(close(amount({oil.a.fluid_entity,oil.b.fluid_entity},"crude-oil"),500),"oil amount changed")
    check(water.a.fluid_entity.get_fluid_count("crude-oil")==0 and oil.a.fluid_entity.get_fluid_count("water")==0,"different ramp pairs mixed fluids")
  end)
  test("native buffers enforce capacity and mix steam heat by amount",function()
    local steam=fixtures.steam
    check(close(amount({steam.a.fluid_entity,steam.b.fluid_entity},"steam"),steam.amount),"steam amount changed")
    check(close(steam.b.fluid_entity.get_fluid(1).temperature,steam.temperature),"steam heat was not conserved")
  end)
  test("a conflicting pair reconnects after its other fluid is flushed",function()
    local conflict=fixtures.conflict
    check(conflict.a.fluid_entity.get_fluid_box_linked_connection(1)==conflict.b.fluid_entity,"cleared conflict never retried")
    check(close(amount({conflict.a.fluid_entity,conflict.b.fluid_entity},"water"),500),"reconnection changed the retained water")
    check(conflict.b.fluid_entity.get_fluid_count("crude-oil")==0,"flushed oil returned")
  end)
  log(string.format("DC_ENGINE RESULT %d passed, %d failed",passed,failed))
  if failed>0 then error("Cruel Rain native fluid checks failed") end
end
return suite
