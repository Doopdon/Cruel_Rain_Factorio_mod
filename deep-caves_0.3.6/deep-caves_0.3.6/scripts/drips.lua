local drips={}
function drips.tick()
  local state=storage.deep_caves
  if not state then return end
  state.drip_audio=state.drip_audio or {players={},random=game.create_random_generator(715993)}
  local audio=state.drip_audio
  local active={}
  for _,player in pairs(game.connected_players) do
    local surface=player.physical_surface
    if surface and surface.name:match("^deep%-caves%-level%-%d+$")
      and player.surface==surface then
      active[player.index]=true
      local record=audio.players[player.index]
      if not record or record.surface~=surface.index then
        record={surface=surface.index,due=game.tick+audio.random(60,180)}
        audio.players[player.index]=record
      end
      if game.tick>=record.due then
        local volume=settings.get_player_settings(player)["deep-caves-drip-volume"].value
        if volume>0 then
          local p=player.physical_position
          local angle=audio.random()*math.pi*2
          local radius=audio.random(2,6)
          player.play_sound{path="deep-caves-drip",
            position={x=p.x+math.cos(angle)*radius,y=p.y+math.sin(angle)*radius},
            volume_modifier=volume}
        end
        -- The recording is 50.3 seconds; leave a short gap and never overlap it.
        record.due=game.tick+audio.random(3120,3480)
      end
    end
  end
  for index in pairs(audio.players) do
    if not active[index] then audio.players[index]=nil end
  end
end
return drips

-- Download refresh: audio behavior unchanged.
-- Second download refresh: no gameplay changes.
