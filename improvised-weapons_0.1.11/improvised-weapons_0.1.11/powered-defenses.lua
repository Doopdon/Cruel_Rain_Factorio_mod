local M = {}
local IDLE_WATTS, SHOCK_WATTS, PULSE_TICKS = 20000, 200000, 30
local function set_fence_demand(state, tick)
  if state.entity.name == "iw-electric-fence" and state.consumer and state.consumer.valid then
    -- ElectricEnergyInterface.power_usage is joules per tick, rather than watts.
    state.consumer.power_usage = ((state.shocking_until or 0) > tick and SHOCK_WATTS or IDLE_WATTS) / 60
  end
end
local roles = {
  ["iw-barbed-wire"] = {damage = 4, damage_type = "physical"},
  ["iw-electric-fence"] = {damage = 40, damage_type = "electric", consumer = "iw-fence-power"},
  ["flamethrower-turret"] = {consumer = "iw-flamethrower-power", gate = true}
}
local consumers = {["iw-fence-power"] = true, ["iw-flamethrower-power"] = true}
local function ensure_consumer(state)
  local entity, role = state.entity, roles[state.entity.name]
  if not role.consumer or not entity.valid then return end
  if not state.consumer or not state.consumer.valid then
    state.consumer = entity.surface.create_entity{name = role.consumer,
      position = entity.position, force = entity.force}
    if state.consumer then
      state.consumer.destructible = false
      state.consumer.operable = false
    end
  end
  if state.consumer and state.consumer.valid and state.consumer.force ~= entity.force then
    state.consumer.force = entity.force
  end
end
local function release(state)
  if state.consumer and state.consumer.valid then state.consumer.destroy() end
  if state.gated and state.entity.valid then state.entity.disabled_by_script = state.original_disabled end
end
function M.register(entity)
  if not entity or not entity.valid or not roles[entity.name] then return end
  storage.iw_powered_defenses = storage.iw_powered_defenses or {}
  local state = storage.iw_powered_defenses[entity.unit_number]
  if not state then
    state = {entity = entity, powered_ticks = 0, original_disabled = entity.disabled_by_script, gated = false}
    storage.iw_powered_defenses[entity.unit_number] = state
  end
  ensure_consumer(state)
  set_fence_demand(state, game.tick)
  if roles[entity.name].gate and not state.original_disabled then
    entity.disabled_by_script = not (state.consumer and state.consumer.valid and state.consumer.energy > 0)
    state.gated = entity.disabled_by_script
  end
end
function M.remove(entity)
  if not entity or not entity.valid or not entity.unit_number then return end
  local state = storage.iw_powered_defenses and storage.iw_powered_defenses[entity.unit_number]
  if state then release(state); storage.iw_powered_defenses[entity.unit_number] = nil end
end
function M.cloned(event)
  if consumers[event.destination.name] then event.destination.destroy(); return true
  else M.register(event.destination) end
end
function M.rescan()
  storage.iw_powered_defenses = storage.iw_powered_defenses or {}
  for id, state in pairs(storage.iw_powered_defenses) do
    if not state.entity.valid then release(state); storage.iw_powered_defenses[id] = nil end
  end
  for _, surface in pairs(game.surfaces) do
    for name in pairs(consumers) do
      for _, entity in pairs(surface.find_entities_filtered{name = name}) do entity.destroy() end
    end
    for name in pairs(roles) do
      for _, entity in pairs(surface.find_entities_filtered{name = name}) do M.register(entity) end
    end
  end
end
function M.surface_removed(event)
  for id, state in pairs(storage.iw_powered_defenses or {}) do
    if not state.entity.valid or state.entity.surface.index == event.surface_index then
      release(state); storage.iw_powered_defenses[id] = nil
    end
  end
end
local function bounds(entity)
  local b = entity.bounding_box
  if b then
    local a, c = b.left_top or b[1], b.right_bottom or b[2]
    return a.x or a[1], a.y or a[2], c.x or c[1], c.y or c[2]
  end
  local p = entity.position
  return p.x - 0.29, p.y - 0.29, p.x + 0.29, p.y + 0.29
end
local function touching(owner, target)
  local ax, ay, bx, by = bounds(owner)
  local cx, cy, dx, dy = bounds(target)
  local gap_x, gap_y = math.max(0, ax - dx, cx - bx), math.max(0, ay - dy, cy - by)
  return gap_x * gap_x + gap_y * gap_y <= 0.15 ^ 2
end
local function near_span(target, a, b)
  local dx,dy=b.x-a.x,b.y-a.y
  local length=dx*dx+dy*dy
  if length<0.0001 then return false end
  local q=target.position
  local t=math.max(0,math.min(1,((q.x-a.x)*dx+(q.y-a.y)*dy)/length))
  local x,y=a.x+t*dx,a.y+t*dy
  local ax,ay,bx,by=bounds(target)
  local radius=math.max((bx-ax)/2,(by-ay)/2)+0.15
  return (q.x-x)^2+(q.y-y)^2<=radius^2
end
function M.update(tick)
  local shocks, active_poles = {}, {}
  local function shock(target,amount,owner)
    active_poles[owner.unit_number] = owner
    local old=shocks[target]
    if not old or amount>old.amount then shocks[target]={amount=amount,owner=owner} end
  end
  for id, state in pairs(storage.iw_powered_defenses or {}) do
    local entity = state.entity
    if not entity.valid then release(state); storage.iw_powered_defenses[id] = nil
    else
      local role = roles[entity.name]
      ensure_consumer(state)
      set_fence_demand(state, tick)
      local powered = not role.consumer or (state.consumer and state.consumer.valid and state.consumer.energy > 0)
      if role.gate then
        if not state.gated then state.original_disabled = entity.disabled_by_script end
        if not powered and not state.original_disabled then
          entity.disabled_by_script = true; state.gated = true
        elseif powered and state.gated then
          entity.disabled_by_script = state.original_disabled; state.gated = false
        end
      elseif role.damage then
        if powered then state.powered_ticks = state.powered_ticks + 1 end
        if tick % PULSE_TICKS == 0 then
          local duration = state.powered_ticks
          state.powered_ticks = 0
          if duration > 0 then
            local p = entity.position
            for _, target in pairs(entity.surface.find_entities_filtered{
              area = {{p.x - 0.9,p.y - 0.9},{p.x + 0.9,p.y + 0.9}}
            }) do
              if not entity.valid then break end
              if target.valid and (target.type == "unit" or target.type == "character")
                and target.health and target.destructible and touching(entity, target) then
                if entity.name=="iw-electric-fence" then shock(target,role.damage*duration/60,entity)
                else target.damage(role.damage * duration / 60, entity.force, role.damage_type, entity, entity) end
              end
            end
            if entity.name=="iw-electric-fence" and entity.get_wire_connector then
              local connector=entity.get_wire_connector(defines.wire_connector_id.pole_copper,false)
              for _,connection in pairs(connector and connector.connections or {}) do
                local other=connection.target and connection.target.owner
                if other and other.valid and other.name=="iw-electric-fence" then
                  local q=other.position
                  for _,target in pairs(entity.surface.find_entities_filtered{
                    area={{math.min(p.x,q.x)-0.65,math.min(p.y,q.y)-0.65},
                      {math.max(p.x,q.x)+0.65,math.max(p.y,q.y)+0.65}}
                  }) do
                    if target.valid and (target.type=="unit" or target.type=="character")
                      and target.health and target.destructible and near_span(target,p,q) then
                      shock(target,role.damage*duration/60,entity)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  -- A shared wire or junction shocks once per pulse, rather than once for
  -- every endpoint that reports the same electrical connection.
  for target,hit in pairs(shocks) do
    if target.valid and hit.owner.valid then
      -- Capture the contact position before damage can kill/destroy the target.
      local p = {x = target.position.x, y = target.position.y}
      hit.owner.surface.create_entity{name = "iw-fence-contact-sparks", position = p}
      target.damage(hit.amount,hit.owner.force,"electric",hit.owner,hit.owner)
    end
  end
  for id, entity in pairs(active_poles) do
    local state = storage.iw_powered_defenses[id]
    if entity.valid and state then
      state.shocking_until = tick + PULSE_TICKS
      set_fence_demand(state, tick)
      -- One audible discharge per pole per pulse, regardless of target count.
      entity.surface.create_entity{name = "iw-fence-discharge", position = entity.position}
    end
  end
end
return M
