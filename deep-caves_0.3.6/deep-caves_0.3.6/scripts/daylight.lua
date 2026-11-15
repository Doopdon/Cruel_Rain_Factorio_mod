local daylight = {}
local function hide(record)
  if record.daylight and record.daylight.valid then record.daylight.visible=false end
  if record.entrance_rain and record.entrance_rain.valid then record.entrance_rain.visible=false end
end
local function valid(object) return object and object.valid end
local function remove(record,field)
  if valid(record[field]) then record[field].destroy() end
  record[field]=nil
end
function daylight.strength(surface)
  if surface.always_day then return 1 end
  local t=surface.daytime
  if t<surface.dusk or t>=surface.dawn then return 1 end
  if t<surface.evening then return 1-(t-surface.dusk)/(surface.evening-surface.dusk) end
  if t<=surface.morning then return 0 end
  return (t-surface.morning)/(surface.dawn-surface.morning)
end
local function weather()
  local interface=remote.interfaces["surface-thunderstorm"]
  if interface and interface.get_weather then
    return remote.call("surface-thunderstorm","get_weather")
  end
  -- Older weather mods still get the blue daylight. Lightning/rain require
  -- the shared clock exported by Surface Thunderstorm 0.1.2 or later.
  return {enabled=false,flash=0}
end
function daylight.update()
  if not storage.deep_caves then return end
  local nauvis=game.surfaces.nauvis
  if not nauvis then return end
  local strength=daylight.strength(nauvis)
  local storm=weather()
  local flash=storm.enabled and math.max(0,math.min(1,storm.flash or 0)) or 0
  local viewers,keys={},{}
  for _,player in pairs(game.connected_players) do
    local surface=player.physical_surface
    if surface and surface.name=="deep-caves-level-1" then
      local p=player.physical_position
      viewers[#viewers+1]=p
      keys[#keys+1]=player.index..":"..math.floor(p.x/32)..":"..math.floor(p.y/32)
    end
  end
  local key=table.concat(keys,"|")
  local state=storage.deep_caves
  local cache=state.daylight_cache
  if not cache or cache.player_key~=key or game.tick>=cache.refresh_tick then
    cache={nearby={},player_key=key,refresh_tick=game.tick+60};state.daylight_cache=cache
    for _,record in pairs(state.portals) do
      if record.from_depth==1 and record.to_depth==0 and valid(record.entity)
        and record.entity.surface.name=="deep-caves-level-1" then
        local p=record.entity.position
        local seen=false
        for _,v in ipairs(viewers) do
          if math.abs(p.x-v.x)<=192 and math.abs(p.y-v.y)<=192 then seen=true;break end
        end
        if seen then cache.nearby[#cache.nearby+1]=record else hide(record) end
      else remove(record,"daylight");remove(record,"entrance_rain") end
    end
  end
  for _,record in ipairs(cache.nearby) do
    if record.from_depth==1 and record.to_depth==0 and valid(record.entity)
      and record.entity.surface.name=="deep-caves-level-1" and record.entity.name=="deep-caves-vent" then
      if valid(record.daylight) and record.daylight.surface~=record.entity.surface then remove(record,"daylight") end
      if valid(record.entrance_rain) and record.entrance_rain.surface~=record.entity.surface then remove(record,"entrance_rain") end
      if not valid(record.daylight) then
        record.daylight=rendering.draw_light{sprite="utility/light_medium",scale=2,
          intensity=0,minimum_darkness=0,color={r=.55,g=.75,b=1},
          target=record.entity,surface=record.entity.surface,render_mode="game"}
      end
      -- A blue sky glow by day; white double-pulse flashes can light the
      -- opening even at night, using the exact surface storm pulse envelope.
      record.daylight.color={r=.55+.45*flash,g=.75+.25*flash,b=1}
      record.daylight.intensity=math.min(1,.8*strength+.95*flash)
      record.daylight.scale=2+.8*flash
      record.daylight.visible=strength>0 or flash>0
      if storm.enabled then
        if not valid(record.entrance_rain) then
          record.entrance_rain=rendering.draw_animation{animation="deep-caves-entrance-rain",
            target=record.entity,surface=record.entity.surface,x_scale=.375,y_scale=.375,
            animation_speed=.8,animation_offset=record.entity.unit_number%32,
            render_layer="light-effect",render_mode="game"}
        end
        local brightness=math.min(1,.23+.55*strength+.65*flash)
        record.entrance_rain.color={r=brightness*(.60+.40*flash),g=brightness*(.80+.20*flash),b=brightness,a=brightness}
        record.entrance_rain.visible=true
      else
        remove(record,"entrance_rain")
      end
    else
      remove(record,"daylight")
      remove(record,"entrance_rain")
    end
  end
end
return daylight
