local power={}
function power.invalidate(state)
  state=state or storage.deep_caves
  if state then state.power_cache=nil end
end
local function valid(entity) return entity and entity.valid end
-- Vanilla accumulator-priority buffers cannot charge one another. Treat each
-- wire-connected local network plus all of its ramp pairs as one energy pool.
-- Rebuild from actual network IDs; poll saved-wire changes once a second.
local function rebuild(state)
  local nodes={}
  local function add(entity)
    if valid(entity) and not nodes[entity.unit_number] then
      nodes[entity.unit_number]={entity=entity,capacity=entity.electric_buffer_size}
    end
  end
  for _,record in pairs(state.portals) do
    if valid(record.entity) then add(record.power) end
  end
  for id,link in pairs(state.power_links) do
    if valid(link.a) and valid(link.b) then add(link.a);add(link.b)
    else state.power_links[id]=nil end
  end
  local ids={}
  local parent={}
  for id in pairs(nodes) do ids[#ids+1]=id;parent[id]=id end
  table.sort(ids)
  local function root(id)
    while parent[id]~=id do
      parent[id]=parent[parent[id]]
      id=parent[id]
    end
    return id
  end
  local function join(a,b)
    if not parent[a] or not parent[b] then return end
    a,b=root(a),root(b)
    if a~=b then
      if a<b then parent[b]=a else parent[a]=b end
    end
  end
  local networks={}
  for _,id in ipairs(ids) do
    local entity=nodes[id].entity
    local network=entity.electric_network_id
    if network then
      local key=entity.surface.index..":"..network
      if networks[key] then join(id,networks[key]) else networks[key]=id end
    end
  end
  for _,link in pairs(state.power_links) do join(link.a.unit_number,link.b.unit_number) end
  local pools={}
  for _,id in ipairs(ids) do
    local key=root(id)
    local pool=pools[key] or {energy=0,capacity=0,ids={}}
    local node=nodes[id]
    -- Energy is read only in the transfer loop, never during graph construction.
    pool.capacity=pool.capacity+node.capacity
    pool.ids[#pool.ids+1]=node
    pools[key]=pool
  end
  state.power_cache={pools=pools,next_refresh=game.tick+60}
end
-- Topology is polled once a second; newly paired ramps invalidate immediately.
-- Saved cache keeps multiplayer join/reload behavior identical.
function power.equalize(state)
  local cache=state.power_cache
  if not cache or game.tick>=cache.next_refresh then rebuild(state);cache=state.power_cache end
  for _,pool in pairs(cache.pools) do
    if pool.capacity>0 and #pool.ids>1 then
      local total=0
      local stale=false
      for _,node in ipairs(pool.ids) do
        if not valid(node.entity) then stale=true;break end
        node.energy=node.entity.energy;total=total+node.energy
      end
      if stale then power.invalidate(state)
      elseif total>0 then
        total=math.min(total,pool.capacity)
        local assigned=0
        for i,node in ipairs(pool.ids) do
          local energy=i==#pool.ids and total-assigned or total*node.capacity/pool.capacity
          energy=math.max(0,math.min(node.capacity,energy))
          -- Dormant/equal buffers need no native writes or second energy reads.
          if math.abs(node.energy-energy)>0.000001 then node.entity.energy=energy end
          assigned=assigned+energy
        end
      end
    end
  end
end
return power
