local M = {}
local NAME = "iw-spinner"
local DAMAGE_PER_SECOND = 13
local function shove(entity, target)
  if not target.valid or target.type ~= "character" then return end
  if target.player and target.player.vehicle then return end
  local p, q = entity.position, target.position
  local dx, dy = q.x - p.x, q.y - p.y
  local tangent, straight = nil, true
  for _, state in pairs(storage.iw_spinners or {}) do
    local other = state.entity
    if other.valid and other ~= entity and other.surface == entity.surface and other.force == entity.force then
      local ox,oy=other.position.x-p.x,other.position.y-p.y
      local d=math.sqrt(ox*ox+oy*oy)
      if d>0.1 and d<=3.1 then
        if not tangent then tangent={x=ox/d,y=oy/d}
        elseif math.abs(tangent.x*oy-tangent.y*ox)>0.05*d then straight=false end
      end
    end
  end
  -- Project away from a straight bank, including diagonal banks. A corner or
  -- an isolated spinner instead pushes directly away from its own center.
  if tangent and straight then
    local nx,ny=-tangent.y,tangent.x
    local signed=dx*nx+dy*ny
    if signed<0 or (math.abs(signed)<0.0001 and (nx<0 or (nx==0 and ny<0))) then nx,ny=-nx,-ny end
    dx,dy=nx,ny
  end
  local length=math.sqrt(dx*dx+dy*dy)
  if length<0.001 then dx,dy,length=0,1,1 end
  -- Teleport's manual collision check tests the exact point and excludes the
  -- entity being moved. Try shorter straight steps, never search sideways.
  for _, distance in ipairs({0.35,0.25,0.15,0.05}) do
    local desired={x=q.x+dx/length*distance,y=q.y+dy/length*distance}
    if target.teleport(desired,nil,false,false,defines.build_check_type.manual) then return end
  end
end

function M.register(entity)
  if not entity or not entity.valid or entity.name ~= NAME or not entity.unit_number then return end
  storage.iw_spinners = storage.iw_spinners or {}
  storage.iw_spinners[entity.unit_number] = storage.iw_spinners[entity.unit_number]
    or {entity = entity, powered_ticks = 0}
end
function M.rescan()
  storage.iw_spinners = storage.iw_spinners or {}
  for id, state in pairs(storage.iw_spinners) do
    if not state.entity.valid then storage.iw_spinners[id] = nil end
  end
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{name = NAME}) do M.register(entity) end
  end
end
function M.remove(entity)
  if not entity or not entity.valid or entity.name ~= NAME or not entity.unit_number then return end
  if storage.iw_spinners then storage.iw_spinners[entity.unit_number] = nil end
end
function M.surface_removed(event)
  for id, state in pairs(storage.iw_spinners or {}) do
    if not state.entity.valid or state.entity.surface.index == event.surface_index then
      storage.iw_spinners[id] = nil
    end
  end
end
function M.update(tick)
  local pushes = {}
  for id, state in pairs(storage.iw_spinners or {}) do
    local entity = state.entity
    if not entity.valid then storage.iw_spinners[id] = nil
    else
      local burner = entity.burner
      if entity.active and burner and burner.remaining_burning_fuel > 0 then
        state.powered_ticks = state.powered_ticks + 1
      end
      if tick % 30 == 0 then
        local powered = state.powered_ticks
        state.powered_ticks = 0
        if powered > 0 then
          local p = entity.position
          for _, target in pairs(entity.surface.find_entities_filtered{
            area = {{p.x - 1.5, p.y - 1.5}, {p.x + 1.5, p.y + 1.5}}
          }) do
            if not entity.valid then break end
            if target.valid and target.health and target.destructible and target.force
              and (target.type == "character" or
                (target.force ~= entity.force and target.force.name ~= "neutral"
                  and not entity.force.get_friend(target.force)
                  and not entity.force.get_cease_fire(target.force))) then
              target.damage(DAMAGE_PER_SECOND * powered / 60, entity.force, "physical", entity, entity)
              if entity.valid and target.valid and target.type=="character" then
                local dx,dy=target.position.x-entity.position.x,target.position.y-entity.position.y
                local distance=dx*dx+dy*dy
                local previous=pushes[target]
                if not previous or distance<previous.distance then pushes[target]={entity=entity,distance=distance} end
              end
            end
          end
        end
      end
    end
  end
  for target,push in pairs(pushes) do
    if push.entity.valid then shove(push.entity,target) end
  end
end
return M
