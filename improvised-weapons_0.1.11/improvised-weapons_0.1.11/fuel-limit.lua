-- Boiler-style automatic refill policy; manual inserts retain normal capacity.
local M = {}
local FIRE = "iw-defense-fire"
local function target_of(e)
  local target = e.drop_target
  if target and target.valid and target.name == FIRE then return target end
  if e.drop_position then
    return e.surface.find_entities_filtered{name = FIRE, position = e.drop_position}[1]
  end
end
local function release(state)
  local e = state.entity
  if not e.valid then return end
  if state.paused then e.disabled_by_script = state.original_disabled end
  if e.inserter_stack_size_override == 1 then
    e.inserter_stack_size_override = state.original_stack_size
  end
end
function M.register(e)
  if not e or not e.valid then return end
  storage.iw_feeders = storage.iw_feeders or {}
  if e.type == "inserter" then
    if not storage.iw_feeders[e.unit_number] and target_of(e) then
      storage.iw_feeders[e.unit_number] = {
        entity = e, original_disabled = e.disabled_by_script,
        original_stack_size = e.inserter_stack_size_override, paused = false
      }
      e.inserter_stack_size_override = 1
    end
  elseif e.name == FIRE then
    -- Includes inserters placed first, plus nonstandard/modded reach lengths.
    for _, arm in pairs(e.surface.find_entities_filtered{type = "inserter"}) do M.register(arm) end
  end
end
function M.rescan()
  for _, state in pairs(storage.iw_feeders or {}) do release(state) end
  storage.iw_feeders = {}
  for _, surface in pairs(game.surfaces) do
    for _, arm in pairs(surface.find_entities_filtered{type = "inserter"}) do M.register(arm) end
  end
  M.update()
end
function M.update()
  local reservations = {}
  for id, state in pairs(storage.iw_feeders or {}) do
    local e = state.entity
    local target = e.valid and target_of(e)
    if not target then
      release(state)
      storage.iw_feeders[id] = nil
    else
      local inventory = target.get_inventory(defines.inventory.chest)
      local stack = inventory[1]
      local count = stack.valid_for_read and stack.name == "coal" and stack.count or 0
      local held = e.held_stack
      local amount = held and held.valid_for_read and held.count or 0
      if not state.paused then state.original_disabled = e.disabled_by_script end
      if e.inserter_stack_size_override ~= 1 then
        state.original_stack_size = e.inserter_stack_size_override
        e.inserter_stack_size_override = 1
      end
      local reserved = reservations[target.unit_number] or 0
      -- Reserve each hand's capacity so simultaneous drops cannot overfill.
      local pause = count >= 5 or count + reserved + amount > 5
      if not pause and not state.original_disabled and not e.disabled_by_control_behavior and not e.frozen then
        reservations[target.unit_number] = reserved + amount
      end
      if pause and not state.original_disabled then
        e.disabled_by_script = true
        state.paused = true
      elseif state.paused then
        e.disabled_by_script = state.original_disabled
        state.paused = false
      end
    end
  end
end
function M.remove(e)
  if not e or not e.valid or not e.unit_number then return end
  local state = storage.iw_feeders and storage.iw_feeders[e.unit_number]
  if state then release(state); storage.iw_feeders[e.unit_number] = nil end
  if e.name == FIRE then M.update() end
end
return M
