local storm={}
local function valid(object) return object and object.valid end
local function remove(object) if valid(object) then object.destroy() end end
function storm.destroy_view(view)
  if not view then return end
  for _,object in pairs(view.rain or {}) do remove(object) end
  remove(view.shade);remove(view.flash);remove(view.light)
end
function storm.enabled()
  local state=storage.surface_thunderstorm
  if state and state.override~=nil then return state.override end
  return settings.global["surface-thunderstorm-enabled"].value
end
function storm.eligible(surface)
  return surface and surface.valid and surface.name=="nauvis" and storm.enabled()
end
function storm.sheltered_eligible(surface)
  return surface and surface.valid and surface.name=="deep-caves-level-1" and storm.enabled()
end
function storm.surface_player(player)
  return player.connected and storm.eligible(player.physical_surface) and storm.eligible(player.surface)
end
-- Only surface-connected UP openings transmit the storm into Cave 1.
-- Use the nearest one so several holes cannot stack the same audio clip.
function storm.nearest_opening(player)
  if not player.connected or not storm.sheltered_eligible(player.physical_surface)
    or player.surface~=player.physical_surface then return nil end
  local p=player.physical_position
  local nearest,distance
  for _,hole in ipairs(player.physical_surface.find_entities_filtered{
    position=p,radius=24,name={"deep-caves-vent","deep-caves-ramp-up"}}) do
    local d=(hole.position.x-p.x)^2+(hole.position.y-p.y)^2
    if hole.valid and (not distance or d<distance) then nearest,distance=hole,d end
  end
  if not nearest then return nil end
  return nearest.position,math.max(0,1-math.sqrt(distance)/24)^.75
end
function storm.initialize()
  local state=storage.surface_thunderstorm or {}
  storage.surface_thunderstorm=state
  state.views=state.views or {}
  state.sheltered_rain=state.sheltered_rain or {}
  state.pending_thunder=state.pending_thunder or {}
  if state.thunder_due then
    state.pending_thunder[#state.pending_thunder+1]=state.thunder_due
    state.thunder_due=nil
  end
  state.random=state.random or game.create_random_generator(937195)
  state.next_strike=state.next_strike or game.tick+state.random(180,420)
end
function storm.options(player)
  local s=settings.get_player_settings(player)
  return {darkness=s["surface-thunderstorm-darkness"].value,
    rain=s["surface-thunderstorm-rain-intensity"].value,
    lightning=s["surface-thunderstorm-lightning"].value,
    volume=s["surface-thunderstorm-volume"].value}
end
-- Rendering-only view: no entities, no terrain changes, and no interaction layer.
-- Optional players is nil only for tests; real views are private to one player.
function storm.create_view(surface,players)
  return {surface=surface,players=players,rain={},rain_due=game.tick}
end
function storm.update_view(view,position,zoom,resolution,options)
  zoom=math.max(.05,zoom)
  local width=resolution.width or 1920
  local height=resolution.height or 1080
  local tile=8/zoom
  local nx=math.ceil(width/512)+1
  local ny=math.ceil(height/512)+1
  local cx=math.floor(position.x/tile)
  local cy=math.floor(position.y/tile)
  local signature=string.format("%.8f:%d:%d",zoom,nx,ny)
  if view.signature~=signature then
    for _,object in pairs(view.rain) do remove(object) end
    view.rain={};view.grid=nil;view.signature=signature
  end
  local grid=cx..":"..cy
  if view.grid~=grid or view.rain_intensity~=options.rain then
    local needed={}
    if options.rain>0 then
      local alpha=math.min(1,options.rain)
      for x=cx-nx,cx+nx do
        for y=cy-ny,cy+ny do
          local key=x..":"..y
          local object=view.rain[key]
          if not valid(object) then
            object=rendering.draw_animation{animation="surface-thunderstorm-rain",
              target={x=(x+.5)*tile,y=(y+.5)*tile},surface=view.surface,
              players=view.players,x_scale=1/zoom,y_scale=1/zoom,
              animation_speed=.65,animation_offset=0,render_layer="light-effect"}
          end
          object.color={r=alpha,g=alpha,b=alpha,a=alpha}
          needed[key]=object
        end
      end
    end
    for key,object in pairs(view.rain) do if not needed[key] then remove(object) end end
    view.rain=needed;view.grid=grid;view.rain_intensity=options.rain
  end
  local world_width=(width+768)/zoom
  local world_height=(height+768)/zoom
  local function cover(field,sprite,layer)
    if not valid(view[field]) then
      view[field]=rendering.draw_sprite{sprite=sprite,target=position,surface=view.surface,
        players=view.players,x_scale=world_width,y_scale=world_height,render_layer=layer}
    end
    view[field].target=position
    view[field].x_scale=world_width;view[field].y_scale=world_height
  end
  cover("shade","surface-thunderstorm-shade","air-object")
  cover("flash","surface-thunderstorm-flash","light-effect")
  local shade=options.darkness
  view.shade.color={r=.018*shade,g=.03*shade,b=.055*shade,a=shade}
  view.shade.visible=shade>0
  if not valid(view.light) then
    view.light=rendering.draw_light{sprite="utility/light_medium",target=position,
      surface=view.surface,players=view.players,scale=math.max(world_width,world_height)/384,
      color={r=.8,g=.9,b=1},intensity=0,minimum_darkness=0}
  end
  view.light.target=position
  view.light.scale=math.max(world_width,world_height)/384
  view.options=options
  storm.update_flash(view,game.tick)
end
function storm.flash_strength(tick)
  local start=storage.surface_thunderstorm.flash_start
  if not start then return 0 end
  local age=tick-start
  if age<0 or age>=24 then return 0 end
  if age<3 then return 1 end
  if age<7 then return .12 end
  if age<10 then return .65 end
  return .65*(24-age)/14
end
function storm.update_flash(view,tick)
  local strength=view.options and view.options.lightning and storm.flash_strength(tick) or 0
  if valid(view.flash) then
    local alpha=.3*strength
    view.flash.color={r=alpha*.9,g=alpha*.95,b=alpha,a=alpha}
    view.flash.visible=strength>0
  end
  if valid(view.light) then view.light.intensity=.9*strength;view.light.visible=strength>0 end
end
function storm.sync_player(player)
  local state=storage.surface_thunderstorm
  local view=state.views[player.index]
  if not storm.surface_player(player) then
    storm.destroy_view(view);state.views[player.index]=nil
    local opening,gain=storm.nearest_opening(player)
    if opening then
      local rain=state.sheltered_rain[player.index] or {rain_due=game.tick}
      state.sheltered_rain[player.index]=rain
      local opts=storm.options(player)
      if game.tick>=rain.rain_due then
        if opts.volume>0 and opts.rain>0 then
          rain.channel=(rain.channel or 0)%2+1
          player.play_sound{path=rain.channel==1 and "surface-thunderstorm-muffled-rain-a" or "surface-thunderstorm-muffled-rain-b",position=opening,volume_modifier=opts.volume*gain}
        end
        rain.rain_due=game.tick+90
      end
    else state.sheltered_rain[player.index]=nil end
    return
  end
  state.sheltered_rain[player.index]=nil
  if not view or not valid(view.surface) or view.surface~=player.surface then
    storm.destroy_view(view)
    view=storm.create_view(player.surface,{player.index});state.views[player.index]=view
  end
  storm.update_view(view,player.position,player.zoom,player.display_resolution,storm.options(player))
  if game.tick>=view.rain_due then
    if view.options.volume>0 and view.options.rain>0 then
      view.rain_channel=(view.rain_channel or 0)%2+1
      player.play_sound{path=view.rain_channel==1 and "surface-thunderstorm-rain-a" or "surface-thunderstorm-rain-b",position=player.position,volume_modifier=view.options.volume}
    end
    view.rain_due=game.tick+90
  end
end
function storm.sync_all()
  for _,player in pairs(game.connected_players) do storm.sync_player(player) end
end
function storm.clear_views()
  for _,view in pairs(storage.surface_thunderstorm.views) do storm.destroy_view(view) end
  storage.surface_thunderstorm.views={}
  storage.surface_thunderstorm.sheltered_rain={}
end
function storm.strike()
  if not storm.enabled() then return end
  local state=storage.surface_thunderstorm
  state.flash_start=game.tick
  state.pending_thunder[#state.pending_thunder+1]=game.tick+state.random(60,600)
  state.next_strike=game.tick+state.random(420,1200)
end
function storm.tick()
  local state=storage.surface_thunderstorm
  if not storm.enabled() then return end
  if game.tick>=state.next_strike then storm.strike() end
  -- Remove cached views before flashing: a remote map camera must never
  -- carry the outdoor overlay into a cave, even between six-tick refreshes.
  for index,view in pairs(state.views) do
    local player=game.get_player(index)
    if not player or not storm.surface_player(player) or view.surface~=player.surface then
      storm.destroy_view(view);state.views[index]=nil
    else storm.update_flash(view,game.tick) end
  end
  -- A later flash must not overwrite thunder waiting for an earlier flash.
  for i=#state.pending_thunder,1,-1 do
    if game.tick>=state.pending_thunder[i] then
      for _,player in pairs(game.connected_players) do
        if storm.surface_player(player) then
          local opts=storm.options(player)
          if opts.volume>0 then
            player.play_sound{path="surface-thunderstorm-thunder",position=player.position,volume_modifier=opts.volume}
          end
        else
          local opening,gain=storm.nearest_opening(player)
          if opening then
            local opts=storm.options(player)
            if opts.volume>0 and gain>0 then
              player.play_sound{path="surface-thunderstorm-muffled-thunder",position=opening,volume_modifier=opts.volume*gain}
            end
          end
        end
      end
      table.remove(state.pending_thunder,i)
    end
  end
end
return storm

-- Download refresh: audio behavior unchanged.
-- Second download refresh: no gameplay changes.
