local exposure={}
local skipped={
 ['construction-robot']=true,['logistic-robot']=true,['combat-robot']=true,['unit']=true,
 ['straight-rail']=true,['half-diagonal-rail']=true,['curved-rail-a']=true,['curved-rail-b']=true,
 ['legacy-straight-rail']=true,['legacy-curved-rail']=true,
 ['elevated-straight-rail']=true,['elevated-half-diagonal-rail']=true,
 ['elevated-curved-rail-a']=true,['elevated-curved-rail-b']=true,
 ['rail-ramp']=true,['rail-support']=true
}
local function sheltered_ship(entity)
  return entity.name=='crash-site-spaceship'
    or string.find(entity.name,'crash-site-spaceship-',1,true)==1
end
function exposure.tick()
  local state=storage.surface_thunderstorm
  local enabled=state and state.override
  if enabled==nil then enabled=settings.global['surface-thunderstorm-enabled'].value end
  if not enabled then return end
  local surface=game.surfaces.nauvis
  if not surface then return end
  local character_rate=settings.global['surface-thunderstorm-character-damage'].value
  local building_rate=settings.global['surface-thunderstorm-building-damage'].value
  if character_rate<=0 and building_rate<=0 then return end
  -- Physical entities, not players' remote cameras. Natural terrain and enemy
  -- creatures are excluded. Indestructible ramp infrastructure stays usable.
  for _,entity in ipairs(surface.find_entities_filtered{force={'enemy','neutral'},invert=true}) do
    if entity.valid and entity.destructible and entity.health and entity.health>0 then
      local amount=0
      if entity.type=='character' then amount=character_rate
      elseif not skipped[entity.type] and not sheltered_ship(entity) and entity.prototype.has_flag('player-creation') then amount=building_rate end
      if amount>0 then entity.damage(amount,'neutral','surface-thunderstorm-exposure') end
    end
  end
end
return exposure
