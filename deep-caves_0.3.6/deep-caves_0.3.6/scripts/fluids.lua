local fluids={}
local NAME="deep-caves-ramp-fluid"
local CONNECTION=1
local ensure_pair
function fluids.set_pair_handler(handler) ensure_pair=handler end
local function valid(entity) return entity and entity.valid end
local function center(record)
  local p=record.entity.position
  return {x=math.floor(p.x)+.5,y=math.floor(p.y)+.5}
end

function fluids.ensure(record)
  if not valid(record.entity) then return end
  local tank=record.fluid_entity
  if not valid(tank) then
    local ramp=record.entity
    local p=center(record)
    tank=ramp.surface.find_entities_filtered{name=NAME,position=p,radius=.1,force=ramp.force,limit=1}[1]
    if not valid(tank) then
      tank=ramp.surface.create_entity{name=NAME,position=p,force=ramp.force,create_build_effect_smoke=false}
    end
    record.fluid_entity=tank
  end
  if valid(tank) then
    tank.destructible=false;tank.rotatable=false
    return tank
  end
end

function fluids.connect(a,b)
  local first,second=fluids.ensure(a),fluids.ensure(b)
  local state=storage.deep_caves
  state.fluid_pending=state.fluid_pending or {}
  local key=math.min(a.entity.unit_number,b.entity.unit_number)
  if not (valid(first) and valid(second)) then
    state.fluid_pending[key]=true
    return false
  end
  local existing,id=first.get_fluid_box_linked_connection(CONNECTION)
  if existing==second and id==CONNECTION then
    state.fluid_pending[key]=nil;a.fluid_conflict=nil;b.fluid_conflict=nil
    return true
  end
  -- Never merge two networks containing different fluids or incompatible
  -- fluid locks. Leave both intact and retry after one is emptied/changed.
  local left_contents,right_contents=first.get_fluid(1),second.get_fluid(1)
  local left_filter,right_filter=first.get_fluid_filter(1),second.get_fluid_filter(1)
  local left=(left_contents and left_contents.name) or (left_filter and left_filter.name)
  local right=(right_contents and right_contents.name) or (right_filter and right_filter.name)
  if left and right and left~=right then
    a.fluid_conflict=true;b.fluid_conflict=true;state.fluid_pending[key]=true
    return false
  end
  first.add_fluid_box_linked_connection(CONNECTION,second,CONNECTION)
  state.fluid_pending[key]=nil;a.fluid_conflict=nil;b.fluid_conflict=nil
  return true
end

function fluids.upgrade()
  local state=storage.deep_caves
  state.fluid_pending={}
  local units={}
  for unit,record in pairs(state.portals) do
    if valid(record.entity) then units[#units+1]=unit end
  end
  table.sort(units)
  for _,unit in ipairs(units) do fluids.ensure(state.portals[unit]) end
  for _,unit in ipairs(units) do
    local record=state.portals[unit]
    local pair=record.pair_unit and state.portals[record.pair_unit]
    if pair and valid(pair.entity) and unit<record.pair_unit then fluids.connect(record,pair) end
  end
  -- Existing saves may already have a pipe beside an unused ramp. Pair only
  -- those with real plumbing; empty openings remain lazy as before.
  for _,unit in ipairs(units) do
    local record=state.portals[unit]
    if not record.pair_unit and valid(record.fluid_entity)
      and #record.fluid_entity.get_fluid_box_neighbours(1)>0 then
      ensure_pair(record)
    end
  end
end

function fluids.pipe_built(event)
  local entity=event.entity or event.created_entity
  if not (valid(entity) and entity.type~="entity-ghost" and entity.fluids_count>0) then return end
  for _,ramp in pairs(entity.surface.find_entities_filtered{position=entity.position,radius=6,
    name={"deep-caves-ramp-down","deep-caves-ramp-up","deep-caves-vent"}}) do
    local record=storage.deep_caves.portals[ramp.unit_number]
    if record and not record.pair_unit and valid(record.fluid_entity) then
      for _,connection in pairs(record.fluid_entity.get_fluid_box_neighbours(1)) do
        if connection.entity==entity then ensure_pair(record);break end
      end
    end
  end
end

function fluids.retry_pending()
  local state=storage.deep_caves
  local pending=state.fluid_pending
  if not pending or not next(pending) then return end
  local units={};for unit in pairs(pending) do units[#units+1]=unit end
  table.sort(units)
  for _,unit in ipairs(units) do
    local record=state.portals[unit]
    local pair=record and record.pair_unit and state.portals[record.pair_unit]
    if record and valid(record.entity) and pair and valid(pair.entity) then fluids.connect(record,pair)
    else pending[unit]=nil end
  end
end

return fluids
