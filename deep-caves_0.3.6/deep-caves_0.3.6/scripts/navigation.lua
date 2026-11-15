local surfaces = require("scripts.surfaces")
local navigation = {}
function navigation.decorate(record)
  if not (record.entity and record.entity.valid) then return end
  record.ramp_direction=nil -- Remove obsolete direction metadata on old saves.
  record.entity.rotatable=false
  if record.label and record.label.valid then record.label.destroy() end
  if record.map_tag and record.map_tag.valid then record.map_tag.destroy() end
  record.label, record.map_tag=nil,nil
end
function navigation.update_player(player)
  local physical_surface=player.physical_surface
  local depth=surfaces.depth_from_surface(physical_surface)
  local frame=player.gui.top.deep_caves_depth
  if not frame then
    frame=player.gui.top.add{type="frame",name="deep_caves_depth",direction="horizontal"}
    local label=frame.add{type="label",name="depth",caption=""}
    label.style.font="default-bold"
  end
  local text=depth==0 and "Surface · Nauvis" or (depth and "Cave Level "..depth or physical_surface.name)
  if frame.depth.caption~=text then frame.depth.caption=text end
end
function navigation.update_all()
  for _,player in pairs(game.connected_players) do navigation.update_player(player) end
end
function navigation.upgrade()
  for _,record in pairs(storage.deep_caves.portals) do navigation.decorate(record) end
  for _,player in pairs(game.players) do navigation.update_player(player) end
end
return navigation
