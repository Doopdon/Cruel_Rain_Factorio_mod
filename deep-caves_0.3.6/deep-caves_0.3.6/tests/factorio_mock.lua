-- Small, deterministic substitute for the Factorio APIs used by generation.
-- This tests real mod Lua, not a rewritten generation algorithm. Engine tile
-- correction, prototype loading, pathfinding and Cave Walls still need Factorio.
local mock={}
local resource={['iron-ore']=true,['copper-ore']=true,coal=true,stone=true,
  ['uranium-ore']=true,['crude-oil']=true}
local function position(p) return {x=p.x or p[1],y=p.y or p[2]} end
local function matches(value,wanted)
  if not wanted then return true end
  if type(wanted)=='table' then
    if wanted.name then return value==wanted.name end
    for _,v in pairs(wanted) do if value==v then return true end end
    return false
  end
  return value==wanted
end
local function dimensions(name)
  if name=='deep-caves-vent' or (name:match('^deep%-caves%-ramp%-[ud]') and not name:find('inventory',1,true)) then return 1.49 end
  if name=='crude-oil' then return 1.4 end
  if name:find('spawner',1,true) then return 2.4 end
  if name=='big-rock' or name=='huge-rock' or name=='big-sand-rock' then return .9 end
  if resource[name] then return .49 end
  if name=='deep-caves-power-interface' or name:find('inventory',1,true) then return 0 end
  return .4
end
local function entity_type(name)
  if resource[name] then return 'resource' end
  if name:find('spawner',1,true) then return 'unit-spawner' end
  if name:find('worm',1,true) then return 'turret' end
  if name:find('rock',1,true) then return 'simple-entity' end
  if name:find('inventory',1,true) then return 'linked-container' end
  if name=='deep-caves-power-interface' then return 'electric-energy-interface' end
  if name=='deep-caves-vent' or name:find('ramp',1,true) then return 'electric-pole' end
  if name=='character' then return 'character' end
  return 'assembling-machine'
end
local function ground(name)
  return not (name=='out-of-map' or name=='cave-wall' or name=='deep-caves-shallow-water'
    or name=='water' or name=='deepwater')
end

function mock.reset(preset,seed)
  for name in pairs(package.loaded) do
    if name:match('^scripts%.') then package.loaded[name]=nil end
  end
  storage={deep_caves={}}
  settings={startup={}}
  local p=preset or {1,12,4,3,10,1}
  for i,name in ipairs({'large','small','web'}) do
    settings.startup['deep-caves-'..name..'-density']={value=p[i*2-1]}
    settings.startup['deep-caves-'..name..'-width']={value=p[i*2]}
  end
  settings.startup['deep-caves-enemy-density']={value=.1}
  defines={events={on_chunk_generated=1,on_gui_opened=2,on_tick=3,on_biter_base_built=4},
    inventory={chest=1},controllers={character=1},gui_type={electric_network=1}}
  mock.events={};mock.nth_ticks={};mock.commands={};mock.messages={}
  mock.next_surface=1;mock.next_entity=1;mock.on_init=nil;mock.generated_events=0
  mock.pending_events={};mock.initializing=false
  mock.next_fail=nil
  script={
    on_init=function(fn)
      mock.on_init=function()
        mock.initializing=true
        local ok,err=pcall(fn)
        mock.initializing=false
        if not ok then error(err) end
        for _,event in ipairs(mock.pending_events) do
          if mock.events[defines.events.on_chunk_generated] then mock.events[defines.events.on_chunk_generated](event) end
        end
        mock.pending_events={}
      end
    end,
    on_configuration_changed=function(fn) mock.on_configuration_changed=fn end,
    on_event=function(id,fn) mock.events[id]=fn end,
    on_nth_tick=function(id,fn) mock.nth_ticks[id]=fn end
  }
  commands={add_command=function(name,_,fn) mock.commands[name]=fn end}
  remote={interfaces={['cave-walls']={}},call=function() end}
  mock.surfaces_by_name={}
  game={tick=0,default_map_gen_settings={seed=seed or 12345},
    surfaces=setmetatable({},{__index=function(_,name) return mock.surfaces_by_name[name] end}),
    forces={},players={},connected_players={}}
  game.print=function(message) mock.messages[#mock.messages+1]=message end
  game.get_player=function(id) return game.players[id] end
  game.forces.player={name='player',index=1,
    get_spawn_position=function() return {x=0,y=0} end,
    add_chart_tag=function() return {valid=true,destroy=function() end} end}
  game.forces.enemy={name='enemy',index=2}
  game.forces.neutral={name='neutral',index=3}
  prototypes={autoplace_control={}}
  game.create_surface=function(name,options) return mock.surface(name,'out-of-map',options) end
  rendering={draw_light=function() return {valid=true} end,draw_animation=function() return {valid=true} end}
  -- GUI/audio/power/inventory mechanics are outside this generation suite.
  -- The actual portal registry, pairing and travel code are never substituted.
  package.loaded['scripts.navigation']={decorate=function() end,update_player=function() end,
    update_all=function() end,upgrade=function() end}
  package.loaded['scripts.cargo']={ensure=function() end,connect=function() end,upgrade=function() end}
  package.loaded['scripts.fluids']={ensure=function() end,connect=function() end,upgrade=function() end,retry_pending=function() end,set_pair_handler=function() end}
  package.loaded['scripts.ramp_gui']={show=function() end,click=function() end,closed=function() end,reset=function() end,set_pair_handler=function() end}
  package.loaded['scripts.daylight']={update=function() end}
  package.loaded['scripts.drips']={tick=function() end}
  package.loaded['scripts.cave_walls.control']=true
  package.loaded['scripts.weather.control']=true
  return mock.surface('nauvis','grass-1',{seed=seed or 12345})
end

function mock.surface(name,default_tile,options)
  local surface={valid=true,name=name,index=mock.next_surface,tiles={},entities={},chunks={},requests={},
    default_tile=default_tile or 'cave-wall',map_gen_settings=options or {},peaceful_mode=false,
    daytime=0,always_day=false,dusk=.25,evening=.45,morning=.55,dawn=.75,write_count=0}
  mock.next_surface=mock.next_surface+1
  mock.surfaces_by_name[name]=surface;game.surfaces[surface.index]=surface
  surface.get_tile=function(x,y)
    if type(x)=='table' then local p=position(x);x,y=p.x,p.y end
    x,y=math.floor(x),math.floor(y)
    return {valid=true,name=surface.tiles[x..':'..y] or surface.default_tile,position={x=x,y=y}}
  end
  surface.set_tiles=function(tiles)
    surface.write_count=surface.write_count+#tiles
    for _,tile in ipairs(tiles) do
      local p=position(tile.position)
      surface.tiles[math.floor(p.x)..':'..math.floor(p.y)]=tile.name
    end
  end
  surface.set_hidden_tile=function() end
  surface.destroy_decoratives=function() end
  surface.find_tiles_filtered=function(filter)
    local found={};local a=filter.area
    local lt,rb=position(a.left_top or a[1]),position(a.right_bottom or a[2])
    for x=math.floor(lt.x),math.ceil(rb.x)-1 do for y=math.floor(lt.y),math.ceil(rb.y)-1 do
      local tile=surface.get_tile(x,y)
      if matches(tile.name,filter.name) then found[#found+1]=tile end
    end end
    return found
  end
  surface.find_entities_filtered=function(filter)
    local found={}
    for _,e in ipairs(surface.entities) do
      local ok=e.valid and e.surface==surface and matches(e.name,filter.name) and matches(e.type,filter.type)
        and matches(e.force.name,filter.force)
      if ok and filter.position then
        local p=position(filter.position);local dx,dy=e.position.x-p.x,e.position.y-p.y
        ok=dx*dx+dy*dy<=(filter.radius or 0)^2
      end
      if ok and filter.area then
        local a=filter.area;local lt,rb=position(a.left_top or a[1]),position(a.right_bottom or a[2])
        local r=dimensions(e.name)
        ok=e.position.x+r>lt.x and e.position.x-r<rb.x and e.position.y+r>lt.y and e.position.y-r<rb.y
      end
      if ok then
        found[#found+1]=e
        if filter.limit and #found>=filter.limit then break end
      end
    end
    return found
  end
  surface.count_entities_filtered=function(filter) return #surface.find_entities_filtered(filter) end
  surface.can_place_entity=function(spec)
    local p=position(spec.position);local r=dimensions(spec.name)
    if spec.name=='biter-spawner' or spec.name=='spitter-spawner' then return true end
    if r==0 then return true end
    -- Ramp collision_mask has no water_tile layer; oil, ores, nests and rocks do.
    local ramp=spec.name=='deep-caves-vent' or spec.name:match('^deep%-caves%-ramp%-[ud]')~=nil
    for x=math.floor(p.x-r),math.ceil(p.x+r)-1 do for y=math.floor(p.y-r),math.ceil(p.y+r)-1 do
      local name=surface.get_tile(x,y).name
      if not ground(name) and not (ramp and name=='deep-caves-shallow-water') then return false end
    end end
    for _,e in ipairs(surface.entities) do
      if e.valid then
        local er=dimensions(e.name)
        if e.name=='biter-spawner' or e.name=='spitter-spawner' then er=0 end
        local both_resources=resource[spec.name] and resource[e.name]
        local neither_resources=not resource[spec.name] and not resource[e.name]
        if er>0 and (both_resources or neither_resources)
          and math.abs(p.x-e.position.x)<r+er and math.abs(p.y-e.position.y)<r+er then return false end
      end
    end
    return true
  end
  surface.create_entity=function(spec)
    if mock.next_fail==spec.name then mock.next_fail=nil;return nil end
    if not surface.can_place_entity(spec) then return nil end
    local p=position(spec.position);local r=dimensions(spec.name)
    local force=spec.force
    if type(force)=='table' then force=force.name end
    local e={valid=true,name=spec.name,type=entity_type(spec.name),surface=surface,position=p,
      amount=spec.amount,unit_number=mock.next_entity,force=game.forces[force or 'enemy'],
      bounding_box={left_top={x=p.x-r,y=p.y-r},right_bottom={x=p.x+r,y=p.y+r}},
      electric_buffer_size=40000000,energy=0}
    mock.next_entity=mock.next_entity+1
    e.destroy=function() e.valid=false end
    e.teleport=function(target) e.position=position(target);return true end
    e.get_wire_connectors=function() return {} end
    surface.entities[#surface.entities+1]=e
    return e
  end
  surface.find_non_colliding_position=function(name,wanted,radius,step)
    local p=position(wanted)
    if surface.can_place_entity{name=name,position=p} then return p end
    step=step or 1
    for r=step,radius,step do
      for dx=-r,r,step do for _,dy in ipairs({-r,r}) do
        local q={x=p.x+dx,y=p.y+dy}
        if surface.can_place_entity{name=name,position=q} then return q end
      end end
      for dy=-r+step,r-step,step do for _,dx in ipairs({-r,r}) do
        local q={x=p.x+dx,y=p.y+dy}
        if surface.can_place_entity{name=name,position=q} then return q end
      end end
    end
  end
  surface.is_chunk_generated=function(p) return surface.chunks[p.x..':'..p.y]~=nil end
  surface.request_to_generate_chunks=function(p,radius)
    p=position(p);local cx,cy=math.floor(p.x/32),math.floor(p.y/32)
    for x=cx-(radius or 0),cx+(radius or 0) do for y=cy-(radius or 0),cy+(radius or 0) do
      local key=x..':'..y
      if not surface.chunks[key] then surface.requests[key]={x=x,y=y} end
    end end
  end
  surface.force_generate_chunk_requests=function()
    local requests=surface.requests;surface.requests={}
    local keys={};for key in pairs(requests) do keys[#keys+1]=key end;table.sort(keys)
    for _,key in ipairs(keys) do mock.generate(surface,requests[key].x,requests[key].y) end
  end
  surface.get_chunks=function()
    local chunks={};for _,chunk in pairs(surface.chunks) do chunks[#chunks+1]=chunk end
    table.sort(chunks,function(a,b) return a.x<b.x or (a.x==b.x and a.y<b.y) end)
    local i=0;return function() i=i+1;return chunks[i] end
  end
  return surface
end

function mock.area(x,y) return {left_top={x=x*32,y=y*32},right_bottom={x=x*32+32,y=y*32+32}} end
function mock.generate(surface,x,y)
  local key=x..':'..y
  if surface.chunks[key] then return end
  surface.chunks[key]={x=x,y=y}
  mock.generated_events=mock.generated_events+1
  assert(mock.generated_events<15000,'unbounded recursive chunk generation')
  local event={surface=surface,area=mock.area(x,y)}
  if mock.initializing then mock.pending_events[#mock.pending_events+1]=event
  elseif mock.events[defines.events.on_chunk_generated] then
    mock.events[defines.events.on_chunk_generated](event)
  end
end
function mock.advance(ticks)
  for _=1,ticks do
    game.tick=game.tick+1
    for interval,fn in pairs(mock.nth_ticks) do if game.tick%interval==0 then fn() end end
  end
end
function mock.player(surface,p)
  local e=assert(surface.create_entity{name='character',position=p,force='player'})
  local player={index=1,valid=true,admin=true,character=e,surface=surface,physical_surface=surface,
    position=position(p),physical_position=position(p),controller_type=defines.controllers.character}
  player.print=game.print
  player.teleport=function(target,new_surface)
    if e.surface~=new_surface then new_surface.entities[#new_surface.entities+1]=e end
    e.surface=new_surface;e.position=position(target)
    player.surface=new_surface;player.physical_surface=new_surface
    player.position=position(target);player.physical_position=position(target)
    return true
  end
  game.players[1]=player;game.connected_players[1]=player
  return player
end
return mock
