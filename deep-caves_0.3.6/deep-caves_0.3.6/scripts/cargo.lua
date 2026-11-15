local cargo = {}
local function valid(e) return e and e.valid end
function cargo.ensure(record)
  if valid(record.inventory_entity) then return record.inventory_entity end
  local state=storage.deep_caves
  state.next_inventory_link_id=state.next_inventory_link_id or 1
  local id=state.next_inventory_link_id
  state.next_inventory_link_id=id+1
  local entity=record.entity.surface.create_entity{name="deep-caves-ramp-inventory-12",position=record.entity.position,force=record.entity.force}
  assert(entity,"Could not create ramp inventory")
  entity.link_id=id
  entity.destructible=false
  record.inventory_entity=entity
  return entity
end
local function preserve_stack(stack,inventory,surface,position,force)
  local inserted=inventory.insert(stack)
  if inserted>=stack.count then stack.clear();return end
  stack.count=stack.count-inserted
  -- Spill just outside the travel trigger, on the ramp's dry landing pad.
  surface.spill_item_stack{position={x=position.x,y=position.y-4},stack=stack,
    enable_looted=true,force=force,allow_belts=false}
  stack.clear()
end
function cargo.connect(a,b)
  local ea,eb=cargo.ensure(a),cargo.ensure(b)
  if ea.link_id==eb.link_id then return end
  local source=eb.get_inventory(defines.inventory.chest)
  local destination=ea.get_inventory(defines.inventory.chest)
  for i=1,#source do
    if source[i].valid_for_read then preserve_stack(source[i],destination,eb.surface,eb.position,eb.force) end
  end
  eb.link_id=ea.link_id
end
function cargo.remove_belts(record)
  local entity=cargo.ensure(record)
  local inventory=entity.get_inventory(defines.inventory.chest)
  for _,key in ipairs({"left_belt","right_belt"}) do
    local belt=record[key]
    if valid(belt) then
      for lane=1,2 do
        local line=belt.get_transport_line(lane)
        for i=#line,1,-1 do
          if line[i].valid_for_read then preserve_stack(line[i],inventory,belt.surface,belt.position,belt.force) end
        end
      end
      belt.destroy()
    end
    record[key]=nil
  end
end
function cargo.upgrade_filtered_slots()
  local state=storage.deep_caves
  if state.filtered_inventory_version==1 then return end
  local groups={}
  for _,record in pairs(state.portals) do
    local old=record.inventory_entity
    if valid(record.entity) and valid(old) and old.name=="deep-caves-ramp-inventory" then
      local key=old.force.index..":"..old.link_id
      local group=groups[key]
      if not group then
        group={records={},link_id=old.link_id,force=old.force}
        groups[key]=group
      end
      group.records[#group.records+1]=record
    end
  end
  local keys={}
  for key in pairs(groups) do keys[#keys+1]=key end
  table.sort(keys)
  local spilled=0
  for _,key in ipairs(keys) do
    local group=groups[key]
    table.sort(group.records,function(a,b) return a.entity.unit_number<b.entity.unit_number end)
    local first=group.records[1]
    local source_entity=first.inventory_entity
    local source=source_entity.get_inventory(defines.inventory.chest)
    local bar=source.supports_bar() and source.get_bar() or 49
    local old_entities={}
    for _,record in ipairs(group.records) do
      old_entities[#old_entities+1]=record.inventory_entity
      local replacement=record.entity.surface.create_entity{
        name="deep-caves-ramp-inventory-12",position=record.entity.position,force=group.force}
      assert(replacement,"Could not migrate ramp inventory")
      replacement.link_id=group.link_id
        replacement.destructible=false
      record.inventory_entity=replacement
    end
    local destination=first.inventory_entity.get_inventory(defines.inventory.chest)
    -- One copy per shared inventory, not one per endpoint. Native inserts
    -- compact compatible stacks and preserve qualities/item metadata.
    for i=1,#source do
      local stack=source[i]
      if stack.valid_for_read then
        local count=stack.count
        local inserted=destination.insert(stack)
        if inserted>=count then stack.clear()
        else
          stack.count=count-inserted
          spilled=spilled+stack.count
          first.entity.surface.spill_item_stack{
            position={x=first.entity.position.x,y=first.entity.position.y-4},
            stack=stack,enable_looted=true,force=group.force,allow_belts=false}
          stack.clear()
        end
      end
    end
    destination.set_bar(math.min(bar,13))
    for _,old in ipairs(old_entities) do if valid(old) then old.destroy() end end
    state.next_inventory_link_id=math.max(state.next_inventory_link_id or 1,group.link_id+1)
  end
  state.filtered_inventory_version=1
  if spilled>0 then game.print("Cruel Rain: "..spilled.." overflow items placed beside ramps during the inventory upgrade.") end
end

function cargo.upgrade()
  cargo.upgrade_filtered_slots()
  local state=storage.deep_caves
  if state.inventory_version==1 then return end
  for _,record in pairs(state.portals) do if valid(record.entity) then cargo.ensure(record) end end
  for _,record in pairs(state.portals) do
    local pair=record.pair_unit and state.portals[record.pair_unit]
    if valid(record.entity) and pair and valid(pair.entity) then cargo.connect(record,pair) end
  end
  for _,record in pairs(state.portals) do if valid(record.entity) then cargo.remove_belts(record) end end
  state.inventory_version=1
end
return cargo
