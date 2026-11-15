local integration={}
-- Factorio 2.0 keeps the native entities when a former companion is disabled,
-- but discards that companion's private Lua storage. Recover the existing
-- boundary helpers before rebuilding so the merge does not duplicate them.
function integration.adopt()
  if storage.cave_walls then return end
  local recovered
  for _,surface in pairs(game.surfaces) do
    for _,entity in pairs(surface.find_entities_filtered{name={"cave-wall-collision","cave-wall-visual"}}) do
      if not recovered then
        recovered={surfaces={},originals={},previous={},blockers={},visuals={}}
      end
      local field=entity.name=="cave-wall-collision" and "blockers" or "visuals"
      local list=recovered[field][surface.index] or {}
      recovered[field][surface.index]=list
      local p=entity.position;local key=math.floor(p.x)..":"..math.floor(p.y)
      if list[key] and list[key].valid then entity.destroy()
      else list[key]=entity end
    end
  end
  if recovered then storage.cave_walls=recovered end
end
return integration
