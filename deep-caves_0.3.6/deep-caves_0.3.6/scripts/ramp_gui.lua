local gui={}
local fluids=require("scripts.fluids")
local cargo=require("scripts.cargo")
local FRAME="deep_caves_ramp_tabs"
local ensure_pair
function gui.set_pair_handler(handler) ensure_pair=handler end
local function valid(entity) return entity and entity.valid end
local function sessions()
  local state=storage.deep_caves
  state.ramp_gui=state.ramp_gui or {}
  return state.ramp_gui
end
function gui.clear(player)
  local panel=player.gui.relative[FRAME]
  if panel and panel.valid then panel.destroy() end
  sessions()[player.index]=nil
end
function gui.show(player,record,mode)
  gui.clear(player)
  sessions()[player.index]={unit=record.entity.unit_number,mode=mode}
  local panel=player.gui.relative.add{type="frame",name=FRAME,direction="vertical",
    caption={"deep-caves-gui.ramp-inventory"},anchor={
      gui=mode=="fluids" and defines.relative_gui_type.pipe_gui or defines.relative_gui_type.linked_container_gui,
      position=defines.relative_gui_position.right}}
  panel.add{type="button",name="deep-caves-open-cargo",caption={"deep-caves-gui.cargo"},enabled=mode~="cargo"}
  panel.add{type="button",name="deep-caves-open-fluids",caption={"deep-caves-gui.fluids"},enabled=mode~="fluids",
    tooltip={"deep-caves-gui.fluid-help"}}
end
function gui.click(event)
  local element=event.element
  if not (element and element.valid) then return end
  local mode=element.name=="deep-caves-open-fluids" and "fluids" or element.name=="deep-caves-open-cargo" and "cargo"
  if not mode then return end
  local player=game.get_player(event.player_index)
  local session=player and sessions()[player.index]
  local record=session and storage.deep_caves.portals[session.unit]
  if not (record and valid(record.entity)) then if player then gui.clear(player) end;return end
  if player.opened~=record.inventory_entity and player.opened~=record.fluid_entity then gui.clear(player);return end
  if mode=="fluids" then ensure_pair(record) end
  local target=mode=="fluids" and fluids.ensure(record) or cargo.ensure(record)
  if valid(target) then player.opened=target;gui.show(player,record,mode) end
end
function gui.closed(event)
  local player=game.get_player(event.player_index)
  local session=player and sessions()[player.index]
  if not session then return end
  local record=storage.deep_caves.portals[session.unit]
  if not record or (player.opened~=record.inventory_entity and player.opened~=record.fluid_entity) then gui.clear(player) end
end
function gui.reset()
  for _,player in pairs(game.players) do gui.clear(player) end
end
return gui
