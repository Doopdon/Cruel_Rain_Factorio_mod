local generation = require("scripts.generation")
local surfaces = require("scripts.surfaces")
local features = require("scripts.features")

local navigation = require("scripts.navigation")
local cargo = require("scripts.cargo")
local puddles = require("scripts.puddles")
local power_transfer = require("scripts.power")
local fluids = require("scripts.fluids")
local ramp_gui = require("scripts.ramp_gui")

local portals = {}

local PORTAL_NAMES = {
  ["deep-caves-ramp-down"] = true,
  ["deep-caves-ramp-up"] = true,
  ["deep-caves-vent"] = true
}

local function init_storage()
  storage.deep_caves = storage.deep_caves or {}
  storage.deep_caves.portals = storage.deep_caves.portals or {}
  storage.deep_caves.power_links = storage.deep_caves.power_links or {}
  storage.deep_caves.player_cooldown = storage.deep_caves.player_cooldown or {}
  storage.deep_caves.next_link_id = storage.deep_caves.next_link_id or 1
end

portals.init_storage = init_storage

local function valid(e)
  return e and e.valid
end

local function make_helper_entities(surface, position)
  generation.carve_circle(surface, position, 6.5)

  local power = surface.create_entity{
    name = "deep-caves-power-interface",
    position = position,
    force = "player",
    create_build_effect_smoke = false
  }
  if valid(power) then
    power.destructible = false
  end
  return nil, power
end

function portals.migrate_ramp_entities()
  local registry=storage.deep_caves.portals
  local replacements={}
  local remap={}
  for unit, record in pairs(registry) do
    local old=record.entity
    if valid(old) and old.type=="simple-entity-with-owner" then
      local kind=old.name=="deep-caves-entrance-up" and "up" or "down"
      local entity=old.surface.create_entity{name="deep-caves-ramp-"..kind,
        position=old.position, force=old.force,
        create_build_effect_smoke=false}
      if valid(entity) then
        entity.destructible=false
        record.entity=entity
        replacements[entity.unit_number]=record
        remap[unit]=entity.unit_number
        old.destroy()
      end
    end
  end
  for oldunit in pairs(remap) do registry[oldunit]=nil end
  for unit,record in pairs(replacements) do registry[unit]=record end
  for _,record in pairs(registry) do
    if remap[record.pair_unit] then record.pair_unit=remap[record.pair_unit] end
  end
  local state=storage.deep_caves
  if remap[state.second_starting_entrance] then state.second_starting_entrance=remap[state.second_starting_entrance] end
end

-- Upgrade existing ramps without replacing their inventories or paired power buffers.
function portals.upgrade_integrated_power()
  for _, record in pairs(storage.deep_caves.portals) do
    if valid(record.entity) then
      local old = record.pole
      if valid(old) then
        for id, connector in pairs(old.get_wire_connectors(false)) do
          local replacement = record.entity.get_wire_connector(id, true)
          if replacement then
            for _, connection in pairs(connector.connections) do
              if connection.target.valid then replacement.connect_to(connection.target, false, connection.origin) end
            end
          end
        end
        old.destroy()
      end
      record.pole = nil
      cargo.ensure(record)
      if valid(record.power) then record.power.teleport(record.entity.position) end
      -- Shrinking the prototype reach does not reliably remove saved wires.
      -- Enforce the new range when upgrading, including old helper-pole wires.
      for _, connector in pairs(record.entity.get_wire_connectors(false)) do
        for _, connection in pairs(connector.connections) do
          if connection.target.valid and not connector.can_wire_reach(connection.target) then
            connector.disconnect_from(connection.target, connection.origin)
          end
        end
      end
      record.ramp_direction=nil
      record.entity.rotatable=false
    end
  end
end

function portals.open_inventory(event)
  local player = game.get_player(event.player_index)
  local entity = event.entity or (event.gui_type == defines.gui_type.electric_network and player and player.selected)
  if not valid(entity) or not PORTAL_NAMES[entity.name] then return end
  local record = storage.deep_caves.portals[entity.unit_number]
  if record and player then
    player.opened = cargo.ensure(record)
    ramp_gui.show(player,record,"cargo")
  end
end

function portals.create_endpoint(surface, position, kind, from_depth, to_depth)
  if to_depth>from_depth and to_depth>surfaces.MAX_DEPTH then return nil end
  init_storage()
  if kind=="deep-caves-ramp-up" and from_depth==1 and to_depth==0
    and surface.name=="deep-caves-level-1" then kind="deep-caves-vent" end
  generation.carve_circle(surface, position, 6.5)

  local ent = surface.create_entity{
    name = kind,
    position = position,
    force = "player",
    create_build_effect_smoke = false
  }
  if not valid(ent) then return nil end
  ent.destructible = false

  local pole, power = make_helper_entities(surface, position)
  local record = {
    entity = ent,
    from_depth = from_depth,
    to_depth = to_depth,
    pair_unit = nil,
    pole = pole,
    power = power
  }
  storage.deep_caves.portals[ent.unit_number] = record
  power_transfer.invalidate()
  cargo.ensure(record)
  fluids.ensure(record)
  navigation.decorate(record)
  puddles.add(record)
  record.needs_access = false -- Unused entrances must not recursively explore more chunks.
  return record
end

-- Replace only the visible pole. Paired inventories and energy buffers remain
-- the same objects; remap registry links and copy saved copper/circuit wires.
function portals.upgrade_surface_vents()
  init_storage()
  local registry=storage.deep_caves.portals
  local replacements,remap={},{}
  for unit,record in pairs(registry) do
    local old=record.entity
    if valid(old) and old.name=="deep-caves-ramp-up"
      and old.surface.name=="deep-caves-level-1" and record.from_depth==1 and record.to_depth==0 then
      local wires={}
      for id,connector in pairs(old.get_wire_connectors(false)) do
        for _,connection in pairs(connector.connections) do
          wires[#wires+1]={id=id,target=connection.target,origin=connection.origin}
        end
      end
      local entity=old.surface.create_entity{name="deep-caves-vent",position=old.position,
        force=old.force,quality=old.quality,create_build_effect_smoke=false}
      if valid(entity) then
        entity.destructible=false;        entity.rotatable=false
        -- Creating a pole may auto-connect it. Restore exactly the saved wires.
        for _,connector in pairs(entity.get_wire_connectors(false)) do
          for _,connection in pairs(connector.connections) do
            connector.disconnect_from(connection.target,connection.origin)
          end
        end
        for _,wire in ipairs(wires) do
          if wire.target.valid then
            entity.get_wire_connector(wire.id,true).connect_to(wire.target,false,wire.origin)
          end
        end
        record.entity=entity
        replacements[entity.unit_number]=record;remap[unit]=entity.unit_number
        old.destroy()
      end
    end
  end
  for unit in pairs(remap) do registry[unit]=nil end
  for unit,record in pairs(replacements) do registry[unit]=record end
  for _,record in pairs(registry) do
    if remap[record.pair_unit] then record.pair_unit=remap[record.pair_unit] end
  end
  if next(remap) then
    storage.deep_caves.daylight_cache=nil
    power_transfer.invalidate()
  end
end

local function avoids_starter_pads(surface,p)
  if surface.name~="deep-caves-level-1" then return true end
  for _,x in ipairs({-8.5,9.5}) do for _,y in ipairs({-8.5,9.5}) do
    if math.abs(p.x-x)<5.5 and math.abs(p.y-y)<5.5 then return false end
  end end
  return true
end

local function choose_pair_position(target_surface, source_position)
  local function safe_landing(p)
    if not avoids_starter_pads(target_surface,p) then return false end
    -- New return ramps can arrive after a cave has already populated its nests.
    if target_surface.count_entities_filtered{position=p,radius=22,force="enemy",type={"unit-spawner","turret"}}>0 then return false end
    if target_surface.count_entities_filtered{position=p,radius=2.5,name={"deep-caves-ramp-down","deep-caves-ramp-up","deep-caves-vent"}}>0 then return false end
    generation.carve_circle(target_surface,p,7)
    return target_surface.can_place_entity{name="deep-caves-ramp-up",position=p,force="player"}
  end
  if safe_landing(source_position) then return source_position end
  for r=8,48,4 do
    for i=0,7 do
      local a=i*math.pi/4
      local p={x=source_position.x+math.cos(a)*r,y=source_position.y+math.sin(a)*r}
      if safe_landing(p) then return p end
    end
  end
  -- Existing factories can occupy a whole search ring. Avoid overwriting them;
  -- an unavailable landing is retried later by the normal pairing queue.
  return nil
end

local function connect_helpers(a, b)
  cargo.connect(a,b)
  fluids.connect(a,b)

  if valid(a.power) and valid(b.power) then
    local id = storage.deep_caves.next_link_id
    storage.deep_caves.next_link_id = id + 1
    storage.deep_caves.power_links[id] = {a = a.power, b = b.power}
    power_transfer.invalidate()
  end
end

function portals.ensure_pair(record)
  init_storage()
  if record.to_depth>record.from_depth and record.to_depth>surfaces.MAX_DEPTH then return nil end
  if record.from_depth>surfaces.MAX_DEPTH then
    -- Legacy upper ramps remain an escape route, without recreating a down ramp.
    local best,nearest,unit
    local p=record.entity and record.entity.valid and record.entity.position
    if not p then return nil end
    for id,candidate in pairs(storage.deep_caves.portals) do
      if valid(candidate.entity) and candidate.from_depth==surfaces.MAX_DEPTH
        and candidate.to_depth<surfaces.MAX_DEPTH then
        local q=candidate.entity.position;local distance=(p.x-q.x)^2+(p.y-q.y)^2
        if not nearest or distance<nearest or (distance==nearest and id<unit) then best,nearest,unit=candidate,distance,id end
      end
    end
    return best
  end
  if record.pair_unit then
    local pair = storage.deep_caves.portals[record.pair_unit]
    if pair and valid(pair.entity) then
      if record.entity and record.entity.unit_number==storage.deep_caves.starting_entrance and record.to_depth==1 then
        storage.deep_caves.level1_start_position=pair.entity.position
      end
      return pair
    end
  end
  if not valid(record.entity) then return nil end

  -- Track forced pair generation so expensive/background return preparation
  -- can still avoid recursively queueing Level 1 surface-return work. Random
  -- downward entrances are no longer suppressed here: a generated chunk only
  -- receives on_chunk_generated once, so suppressing its roll made permanent
  -- entrance-free regions around paired ramps.
  storage.deep_caves.pair_generation = (storage.deep_caves.pair_generation or 0) + 1
  local target_surface = surfaces.ensure(record.to_depth)
  local source_position = record.entity.position
  target_surface.request_to_generate_chunks(source_position, 1)
  target_surface.force_generate_chunk_requests()

  local pair_position = choose_pair_position(target_surface, source_position)
  if not pair_position then
    storage.deep_caves.pair_generation = math.max(0, storage.deep_caves.pair_generation - 1)
    return nil
  end
  local pair_kind = record.to_depth > record.from_depth
      and "deep-caves-ramp-up"
      or "deep-caves-ramp-down"

  local pair = portals.create_endpoint(target_surface, pair_position, pair_kind, record.to_depth, record.from_depth)
  if not pair then storage.deep_caves.pair_generation = storage.deep_caves.pair_generation - 1; return nil end

  record.pair_unit = pair.entity.unit_number
  pair.pair_unit = record.entity.unit_number
  if record.entity.unit_number==storage.deep_caves.starting_entrance and record.to_depth==1 then
    storage.deep_caves.level1_start_position=pair.entity.position
    features.enforce_level1_safe_zone()
  end
  connect_helpers(record, pair)
  record.needs_access = nil
  generation.connect_entrance(record.entity.surface, record.entity.position, record.from_depth, surfaces.seed_for_depth(record.from_depth))
  pair.needs_access = nil
  generation.connect_entrance(target_surface, pair.entity.position, pair.from_depth, surfaces.seed_for_depth(pair.from_depth))
  if record.to_depth==1 then features.ensure_level1_starter_resources() end
  storage.deep_caves.pair_generation = storage.deep_caves.pair_generation - 1
  return pair
end

local function teleport_player(player, source, target)
  local destination = {x=target.entity.position.x, y=target.entity.position.y-3.2}
  generation.carve_circle(target.entity.surface, target.entity.position, 7)

  local character_name = (player.character and player.character.valid and player.character.name) or "character"
  local safe = target.entity.surface.find_non_colliding_position(character_name, destination, 6, 0.5) or destination
  player.teleport(safe, target.entity.surface)
  storage.deep_caves.player_cooldown[player.index] = game.tick + 75

  portals.activate_surface(target.entity.surface)
  navigation.update_player(player)
  local depth = surfaces.depth_from_surface(target.entity.surface) or 0
  if depth == 0 then
    player.print("Returned to Nauvis.")
  else
    player.print("Entered Cave Level " .. depth .. ".")
  end
end

function portals.tick_players()
  init_storage()
  for _, player in pairs(game.connected_players) do portals.activate_surface(player.physical_surface) end
  local pending = {}
  for _, record in pairs(storage.deep_caves.portals) do
    if record.needs_access and valid(record.entity) then pending[#pending + 1] = record end
  end
  for _, record in ipairs(pending) do
    record.needs_access = nil
    generation.connect_entrance(record.entity.surface, record.entity.position, record.from_depth, surfaces.seed_for_depth(record.from_depth))
  end
  for _, player in pairs(game.connected_players) do
    local cooldown = storage.deep_caves.player_cooldown[player.index] or 0
    -- Remote view has its own surface/position. Browsing a ramp must never
    -- teleport that camera or the stashed character; cutscenes/editors also skip.
    if player.controller_type == defines.controllers.character
      and game.tick >= cooldown and not player.opened and player.character and player.character.valid then
      local nearby = player.character.surface.find_entities_filtered{
        position = player.character.position,
        radius = 2.15,
        name = {"deep-caves-ramp-down","deep-caves-ramp-up","deep-caves-vent"}
      }
      -- Test the character's position, not its collision box: only the
      -- single terrain tile containing the ramp's center activates travel.
      local position = player.character.position
      for _, ent in ipairs(nearby) do
        if PORTAL_NAMES[ent.name]
          and math.floor(position.x) == math.floor(ent.position.x)
          and math.floor(position.y) == math.floor(ent.position.y) then
          local record = storage.deep_caves.portals[ent.unit_number]
          if record then
            local pair = portals.ensure_pair(record)
            if pair then teleport_player(player, record, pair); break end
          end
        end
      end
    end
  end
end

function portals.equalize_power()
  init_storage()
  power_transfer.equalize(storage.deep_caves)
end

function portals.spawn_random_entrance(surface, area, depth, seed)
  if depth>=surfaces.MAX_DEPTH then return end
  init_storage()
  local chunk_x = math.floor(area.left_top.x / 32)
  local chunk_y = math.floor(area.left_top.y / 32)
  storage.deep_caves.entrance_chunks = storage.deep_caves.entrance_chunks or {}
  local marks = storage.deep_caves.entrance_chunks[surface.index] or {}
  storage.deep_caves.entrance_chunks[surface.index] = marks
  local key = chunk_x .. ":" .. chunk_y
  if marks[key]==2 then return end
  -- Half the former candidate density; paired up ramps follow their down ramp.
  if generation.hash01(chunk_x, chunk_y, seed + 25013) >= 0.5 then marks[key]=2;return end
  -- Retrofitting/revisiting a chunk must not duplicate an existing entrance.
  if surface.count_entities_filtered{area = area, name = "deep-caves-ramp-down"} > 0 then marks[key]=2;return end

  local pos
  if depth == 0 then
    local wanted = {
      x = area.left_top.x + 5 + generation.hash01(chunk_x, chunk_y, seed + 12101) * 22,
      y = area.left_top.y + 5 + generation.hash01(chunk_x, chunk_y, seed + 12203) * 22
    }
    pos = surface.find_non_colliding_position("deep-caves-ramp-down", wanted, 14, 1)
  else
    local function landing(p)
      return {x=math.max(area.left_top.x+7.5,math.min(area.right_bottom.x-7.5,p.x)),
        y=math.max(area.left_top.y+7.5,math.min(area.right_bottom.y-7.5,p.y))}
    end
    local anchor = generation.find_floor_in_chunk(area, depth, seed,function(p)
      local c=landing(p)
      return avoids_starter_pads(surface,c) and surface.count_entities_filtered{position=c,radius=7,force="player"}==0
        and surface.count_entities_filtered{position=c,radius=5,force="enemy"}==0
        and surface.count_entities_filtered{position=c,radius=2,type="resource"}==0
    end)
    if anchor then
      pos=landing(anchor)
      generation.carve_circle(surface, pos, 6.5)
      -- A short, in-chunk spur joins an edge-only or one-tile tunnel to its
      -- landing without any recursive chunk requests during generation.
      generation.connect_positions(surface,pos,anchor,depth,seed,1.35,true)
      if not surface.can_place_entity{name="deep-caves-ramp-down",position=pos,force="player"} then pos=nil end
    end
  end

  if pos then
    local record=portals.create_endpoint(surface, pos, "deep-caves-ramp-down", depth, depth + 1)
    if record then marks[key]=2;return record end
  end
end

function portals.ensure_starting_entrance()
  init_storage()
  local nauvis = game.surfaces["nauvis"]
  if not nauvis then return end

  local saved=storage.deep_caves.portals[storage.deep_caves.starting_entrance or -1]
  if saved and valid(saved.entity) then return saved end

  local spawn = game.forces.player.get_spawn_position(nauvis)
  nauvis.request_to_generate_chunks(spawn, 2)
  nauvis.force_generate_chunk_requests()

  local wanted = {x = spawn.x + 10, y = spawn.y}
  local nearby=nauvis.find_entities_filtered{name="deep-caves-ramp-down",position=wanted,radius=24}
  table.sort(nearby,function(a,b)
    local da=(a.position.x-wanted.x)^2+(a.position.y-wanted.y)^2
    local db=(b.position.x-wanted.x)^2+(b.position.y-wanted.y)^2
    return da<db or (da==db and a.unit_number<b.unit_number)
  end)
  for _,entity in ipairs(nearby) do
    local record=storage.deep_caves.portals[entity.unit_number]
    if record then
      storage.deep_caves.starting_entrance=entity.unit_number
      storage.deep_caves.level1_start_position=storage.deep_caves.level1_start_position or entity.position
      return record
    end
  end
  local pos = nauvis.find_non_colliding_position("deep-caves-ramp-down", wanted, 24, 1)
  if pos then
    local record=portals.create_endpoint(nauvis, pos, "deep-caves-ramp-down", 0, 1)
    if record then
      storage.deep_caves.starting_entrance=record.entity.unit_number
      storage.deep_caves.level1_start_position=storage.deep_caves.level1_start_position or record.entity.position
      game.forces.player.add_chart_tag(nauvis, {position = pos, text = "Cave Entrance"})
      return record
    end
  end
end

function portals.rebuild_registry()
  init_storage()
  -- Helper for migrations/debugging. Existing registered portals are retained.
  for _, surface in pairs(game.surfaces) do
    for _, ent in pairs(surface.find_entities_filtered{name = {"deep-caves-ramp-down","deep-caves-ramp-up","deep-caves-vent"}}) do
      if not storage.deep_caves.portals[ent.unit_number] then
        local depth = surfaces.depth_from_surface(surface) or 0
        local to_depth = ent.name == "deep-caves-ramp-down" and depth + 1 or math.max(0, depth - 1)
        storage.deep_caves.portals[ent.unit_number] = {
          entity = ent,
          from_depth = depth,
          to_depth = to_depth
        }
      end
    end
  end
end

function portals.ensure_second_starting_entrance()
  init_storage()
  local nauvis = game.surfaces["nauvis"]
  if not nauvis or storage.deep_caves.second_starting_entrance then return end
  local spawn = game.forces.player.get_spawn_position(nauvis)
  local wanted = {x = spawn.x - 96, y = spawn.y}
  nauvis.request_to_generate_chunks(wanted, 1)
  nauvis.force_generate_chunk_requests()
  local pos = nauvis.find_non_colliding_position("deep-caves-ramp-down", wanted, 32, 1)
  if pos then
    local record = portals.create_endpoint(nauvis, pos, "deep-caves-ramp-down", 0, 1)
    if record then
      storage.deep_caves.second_starting_entrance = record.entity.unit_number
      game.forces.player.add_chart_tag(nauvis, {position = pos, text = "Cave Entrance"})
    end
  end
end

function portals.upgrade_entrance_density()
  init_storage()
  if storage.deep_caves.entrance_density_version == 2 then return end
  -- Snapshot generated chunks before adding endpoints; do not expand exploration.
  local chunks = {}
  for _, surface in pairs(game.surfaces) do
    local depth = surfaces.depth_from_surface(surface)
    if depth then
      for chunk in surface.get_chunks() do
        if surface.is_chunk_generated(chunk) then
          chunks[#chunks + 1] = {surface = surface, depth = depth, x = chunk.x, y = chunk.y}
        end
      end
    end
  end
  table.sort(chunks, function(a,b)
    if a.surface.index ~= b.surface.index then return a.surface.index < b.surface.index end
    if a.x ~= b.x then return a.x < b.x end
    return a.y < b.y
  end)
  for _, chunk in ipairs(chunks) do
    local area = {left_top = {x = chunk.x * 32, y = chunk.y * 32}, right_bottom = {x = chunk.x * 32 + 32, y = chunk.y * 32 + 32}}
    portals.spawn_random_entrance(chunk.surface, area, chunk.depth, surfaces.seed_for_depth(chunk.depth))
  end
  storage.deep_caves.entrance_density_version = 2
end

function portals.activate_surface(surface)
  init_storage()
  local depth = surfaces.depth_from_surface(surface)
  if not depth or depth == 0 then return end
  storage.deep_caves.activated_surfaces = storage.deep_caves.activated_surfaces or {}
  if storage.deep_caves.activated_surfaces[surface.index] then return end
  storage.deep_caves.activated_surfaces[surface.index] = true
  for chunk in surface.get_chunks() do
    if surface.is_chunk_generated(chunk) then
      local area={left_top={x=chunk.x*32,y=chunk.y*32},right_bottom={x=chunk.x*32+32,y=chunk.y*32+32}}
      portals.spawn_random_entrance(surface,area,depth,surfaces.seed_for_depth(depth))
    end
  end
end

-- Exploring Level 1 must also discover the surface columns above it.
-- Otherwise only the initially generated Nauvis area has returning UP ramps.
-- Keep the ordinary Nauvis candidate density and pair those exact entrances;
-- never create a separate independently branching set of cave exits.
local function surface_return_state(surface)
  local state=storage.deep_caves
  if not state.surface_returns or state.surface_returns.surface_index~=surface.index then
    state.surface_returns={surface_index=surface.index,pending={},scheduled={}}
  end
  return state.surface_returns
end

function portals.queue_surface_return(surface,area)
  init_storage()
  if surfaces.depth_from_surface(surface)~=1 then return end
  local state=surface_return_state(surface)
  local x,y=math.floor(area.left_top.x/32),math.floor(area.left_top.y/32)
  local key=x..":"..y
  if state.scheduled[key] then return end
  state.scheduled[key]=true
  state.pending[key]={x=x,y=y}
end

function portals.upgrade_surface_returns()
  init_storage()
  local surface=game.surfaces[surfaces.name(1)]
  if not surface then return end
  local state=surface_return_state(surface)
  if state.backfilled then return end
  for chunk in surface.get_chunks() do
    if surface.is_chunk_generated(chunk) then
      portals.queue_surface_return(surface,{left_top={x=chunk.x*32,y=chunk.y*32}})
    end
  end
  state.backfilled=true
end

local function nearby_return_columns(players)
  local positions={}
  for _,player in pairs(players or game.connected_players) do
    local character=player.character
    if valid(character) and surfaces.depth_from_surface(character.surface)==1 then
      local p=character.position
      positions[#positions+1]=p
      local cx,cy=math.floor(p.x/32),math.floor(p.y/32)
      -- Also catch exploration requests flushed by return-pair generation,
      -- where on_chunk_generated intentionally suppresses recursive spawning.
      for x=cx-4,cx+4 do for y=cy-4,cy+4 do
        if character.surface.is_chunk_generated({x=x,y=y}) then
          portals.queue_surface_return(character.surface,{left_top={x=x*32,y=y*32}})
        end
      end end
    end
  end
  return positions
end

-- One expensive preparation job per half second across all players/layers.
-- Travel itself remains immediate and does not depend on this background budget.
local function background_ready()
  return game.tick>=(storage.deep_caves.next_background_preparation_tick or 0)
end
local function spend_background_budget()
  storage.deep_caves.next_background_preparation_tick=game.tick+30
end
function portals.prepare_surface_returns(players)
  init_storage()
  if not background_ready() then return end
  local positions=nearby_return_columns(players)
  if #positions==0 then return end
  local state=storage.deep_caves.surface_returns
  if not state then return end
  local surface=game.surfaces[state.surface_index]
  local nauvis=game.surfaces.nauvis
  if not surface or not nauvis then return end
  -- Look up only nearby queued columns; never sort or drain the entire map.
  local best_key,best,best_distance
  for _,p in ipairs(positions) do
    local cx,cy=math.floor(p.x/32),math.floor(p.y/32)
    for x=cx-3,cx+3 do for y=cy-3,cy+3 do
      local key=x..":"..y;local column=state.pending[key]
      if column and game.tick>=(column.retry_tick or 0) then
        local distance=(x*32+16-p.x)^2+(y*32+16-p.y)^2
        if distance<=96*96 and (not best_distance or distance<best_distance
          or (distance==best_distance and (x<best.x or (x==best.x and y<best.y)))) then
          best_key,best,best_distance=key,column,distance
        end
      end
    end end
  end
  if not best then return end
  spend_background_budget()
  local center={x=best.x*32+16,y=best.y*32+16}
  if not nauvis.is_chunk_generated{x=best.x,y=best.y} then
    -- Let normal map generation complete this single surface column. Forcing
    -- requests would also flush unrelated exploration requests on Nauvis.
    nauvis.request_to_generate_chunks(center,0)
    return
  end
  local area={left_top={x=best.x*32,y=best.y*32},right_bottom={x=best.x*32+32,y=best.y*32+32}}
  portals.spawn_random_entrance(nauvis,area,0,surfaces.seed_for_depth(0))
  local endpoints=nauvis.find_entities_filtered{area=area,name="deep-caves-ramp-down"}
  table.sort(endpoints,function(a,b) return a.unit_number<b.unit_number end)
  local attempted=false
  for _,entity in ipairs(endpoints) do
    local record=storage.deep_caves.portals[entity.unit_number]
    if record and not record.pair_unit then
      if attempted then return end -- Remaining endpoint stays queued for later.
      attempted=true
      if not portals.ensure_pair(record) then best.retry_tick=game.tick+300;return end
    end
  end
  state.pending[best_key]=nil
end

-- Prefetch only on the player's physical layer and within two chunks.
-- Unused ramps on distant/empty layers no longer generate their destinations.
function portals.prepare_return_ramps(players)
  init_storage()
  if not background_ready() then return end
  local best,best_unit,best_distance
  for _,player in pairs(players or game.connected_players) do
    local character=player.character
    if valid(character) then
      for unit,record in pairs(storage.deep_caves.portals) do
        if valid(record.entity) and record.entity.surface==character.surface
          and record.to_depth>record.from_depth and record.to_depth<=surfaces.MAX_DEPTH and not record.pair_unit
          and game.tick>=(record.background_retry_tick or 0) then
          local dx,dy=record.entity.position.x-character.position.x,record.entity.position.y-character.position.y
          local distance=dx*dx+dy*dy
          if distance<=64*64 and (not best_distance or distance<best_distance
            or (distance==best_distance and unit<best_unit)) then
            best,best_unit,best_distance=record,unit,distance
          end
        end
      end
    end
  end
  if best then
    spend_background_budget()
    if not portals.ensure_pair(best) then best.background_retry_tick=game.tick+300 end
  end
end


function portals.enforce_depth_limit()
  init_storage()
  local state=storage.deep_caves
  local retired={}
  for unit,record in pairs(state.portals) do
    if record.to_depth>record.from_depth and record.to_depth>surfaces.MAX_DEPTH then retired[#retired+1]=unit end
  end
  table.sort(retired)
  for _,unit in ipairs(retired) do
    local record=state.portals[unit]
    local ramp=record.entity
    local inventory_entity=record.inventory_entity
    if valid(inventory_entity) then
      local inventory=inventory_entity.get_inventory(defines.inventory.chest)
      if not inventory.is_empty() then
        local chest=inventory_entity.surface.create_entity{name="steel-chest",position=inventory_entity.position,force=inventory_entity.force}
        assert(chest,"Could not preserve retired ramp inventory")
        for i=1,#inventory do
          local stack=inventory[i]
          if stack.valid_for_read then
            local inserted=chest.insert(stack)
            if inserted<stack.count then
              local remainder=stack.count-inserted;stack.count=remainder
              inventory_entity.surface.spill_item_stack{position=inventory_entity.position,stack=stack,enable_looted=true,force=inventory_entity.force,allow_belts=false}
            end
            stack.clear()
          end
        end
      end
      inventory_entity.destroy()
    end
    local pair=record.pair_unit and state.portals[record.pair_unit]
    if pair then pair.pair_unit=nil end
    local buffer=record.power
    for id,link in pairs(state.power_links) do
      if link.a==buffer or link.b==buffer then state.power_links[id]=nil end
    end
    for _,field in ipairs{"fluid_entity","power","pole","left_belt","right_belt","daylight","entrance_rain","label","map_tag"} do
      local entity=record[field];if entity and entity.valid then entity.destroy() end
    end
    if valid(ramp) then ramp.destroy() end
    state.portals[unit]=nil
  end
  power_transfer.invalidate()
  state.daylight_cache=nil
  if #retired>0 then game.print("Cruel Rain: Cave 5 is the final flooded level. Removed "..#retired.." deeper-going ramps; their stored items were moved to steel chests.") end
end

fluids.set_pair_handler(portals.ensure_pair)
ramp_gui.set_pair_handler(portals.ensure_pair)
return portals
