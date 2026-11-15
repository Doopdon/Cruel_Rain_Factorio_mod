local silos={}
local surfaces=require("scripts.surfaces")
local function valid(entity) return entity and entity.valid end
local function refund_items(event,entity)
  local result={}
  if event.consumed_items and event.consumed_items.valid then
    for i=1,#event.consumed_items do
      local stack=event.consumed_items[i]
      if stack.valid_for_read then
        result[#result+1]={name=stack.name,count=stack.count,quality=stack.quality.name}
      end
    end
  end
  if #result==0 then
    local stack=event.stack
    for _,item in ipairs(entity.prototype.items_to_place_this or {}) do
      if not (stack and stack.valid_for_read) or stack.name==item.name then
        result[1]={name=item.name,count=item.count,quality=entity.quality.name}
        break
      end
    end
  end
  return result
end
function silos.built(event)
  if not settings.startup["deep-caves-surface-silos-only"].value then return end
  local entity=event.entity or event.created_entity or event.destination
  if not valid(entity) then return end
  local ghost=entity.type=="entity-ghost" and entity.ghost_type=="rocket-silo"
  if entity.type~="rocket-silo" and not ghost then return end
  local depth=surfaces.depth_from_surface(entity.surface)
  if not depth or depth==0 then return end
  local surface,position,force=entity.surface,entity.position,entity.force
  local items=ghost and {} or refund_items(event,entity)
  local player=event.player_index and game.get_player(event.player_index)
  local inventory=valid(event.robot) and event.robot.get_inventory(defines.inventory.robot_cargo)
  if not entity.destroy{raise_destroy=true} then return end
  for _,stack in ipairs(items) do
    local inserted=player and player.insert(stack) or inventory and inventory.insert(stack) or 0
    stack.count=stack.count-inserted
    if stack.count>0 then
      surface.spill_item_stack{position=position,stack=stack,force=force,enable_looted=true,allow_belts=false}
    end
  end
  if player then player.create_local_flying_text{text={"deep-caves-gui.silo-surface-only"},position=position} end
end
return silos
