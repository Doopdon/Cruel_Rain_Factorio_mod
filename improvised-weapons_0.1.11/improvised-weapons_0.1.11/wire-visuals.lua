local M = {}
local directions = {{0,-1,1},{1,0,2},{0,1,4},{-1,0,8}}
local function key(surface, p)
  return (type(surface)=="number" and surface or surface.index) .. ":" .. p.x .. ":" .. p.y
end
local function is_wire(e)
  return e and e.valid and (e.name == "iw-barbed-wire" or
    (e.type == "entity-ghost" and e.ghost_name == "iw-barbed-wire"))
end
local function refresh(state)
  local e = state.entity
  if not e.valid then return end
  local mask = 0
  for _, d in ipairs(directions) do
    local id = storage.iw_wire_tiles[key(e.surface,{x=e.position.x+d[1],y=e.position.y+d[2]})]
    local other = id and storage.iw_wire_visuals[id]
    if other and other.entity.valid and other.entity.force == e.force then mask = mask + d[3] end
  end
  local sprite = "iw-barbed-wire-mask-" .. mask
  if not state.render or not state.render.valid then
    state.render = rendering.draw_sprite{sprite=sprite, surface=e.surface, target=e,
      render_layer="object", tint=e.type=="entity-ghost" and {r=0.3,g=0.7,b=1,a=0.4} or nil}
  elseif state.mask ~= mask then state.render.sprite = sprite end
  state.mask = mask
end
local function neighborhood(surface, position)
  for _, d in ipairs({{0,0},{0,-1},{1,0},{0,1},{-1,0}}) do
    local id=storage.iw_wire_tiles[key(surface,{x=position.x+d[1],y=position.y+d[2]})]
    local state=id and storage.iw_wire_visuals[id]
    if state then refresh(state) end
  end
end
function M.register(e)
  if not is_wire(e) then return end
  storage.iw_wire_visuals=storage.iw_wire_visuals or {}
  storage.iw_wire_tiles=storage.iw_wire_tiles or {}
  local id=e.unit_number
  local state=storage.iw_wire_visuals[id] or {entity=e, surface=e.surface,
    surface_index=e.surface.index, position={x=e.position.x,y=e.position.y}}
  storage.iw_wire_visuals[id]=state
  storage.iw_wire_tiles[key(e.surface,e.position)]=id
  neighborhood(e.surface,e.position)
end
local function remove(id, state)
  if state.render and state.render.valid then state.render.destroy() end
  storage.iw_wire_visuals[id]=nil
  local k=key(state.surface_index,state.position)
  if storage.iw_wire_tiles[k]==id then storage.iw_wire_tiles[k]=nil end
  if state.surface.valid then neighborhood(state.surface,state.position) end
end
function M.remove(e)
  if not e or not e.valid or not e.unit_number then return end
  local state=storage.iw_wire_visuals and storage.iw_wire_visuals[e.unit_number]
  if state then remove(e.unit_number,state) end
end
function M.rescan()
  for _, state in pairs(storage.iw_wire_visuals or {}) do
    if state.render and state.render.valid then state.render.destroy() end
  end
  storage.iw_wire_visuals={};storage.iw_wire_tiles={}
  for _, surface in pairs(game.surfaces) do
    for _, e in pairs(surface.find_entities_filtered{name="iw-barbed-wire"}) do M.register(e) end
    for _, e in pairs(surface.find_entities_filtered{name="entity-ghost",ghost_name="iw-barbed-wire"}) do M.register(e) end
  end
end
function M.surface_removed(event)
  for id,state in pairs(storage.iw_wire_visuals or {}) do
    if not state.entity.valid or state.surface.index==event.surface_index then remove(id,state) end
  end
end
function M.update()
  for id,state in pairs(storage.iw_wire_visuals or {}) do
    if not state.entity.valid then remove(id,state)
    elseif not state.render or not state.render.valid then refresh(state) end
  end
end
return M
