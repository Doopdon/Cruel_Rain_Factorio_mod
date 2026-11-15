data:extend({
 {type="animation",name="surface-thunderstorm-rain",layers={
  {filename="__deep-caves__/graphics/weather/rain-far.png",width=256,height=256,frame_count=32,line_length=8,animation_speed=.65,draw_as_glow=true},
  {filename="__deep-caves__/graphics/weather/rain-near.png",width=256,height=256,frame_count=32,line_length=8,animation_speed=.65,draw_as_glow=true}
 }},
 {type="sprite",name="surface-thunderstorm-shade",filename="__deep-caves__/graphics/weather/screen.png",width=1,height=1},
 {type="sprite",name="surface-thunderstorm-flash",filename="__deep-caves__/graphics/weather/screen.png",width=1,height=1,draw_as_glow=true},
 {type="sound",name="surface-thunderstorm-rain",variations={{filename="__deep-caves__/sound/weather/rain-1.wav",volume=.7}}},
 -- Alternate named channels so a new clip cannot replace the fading old one.
 {type="sound",name="surface-thunderstorm-rain-a",variations={
  {filename="__deep-caves__/sound/weather/rain-1.wav",volume=.7},
  {filename="__deep-caves__/sound/weather/rain-3.wav",volume=.7}
 }},
 {type="sound",name="surface-thunderstorm-rain-b",variations={
  {filename="__deep-caves__/sound/weather/rain-2.wav",volume=.7},
  {filename="__deep-caves__/sound/weather/rain-4.wav",volume=.7}
 }},
 {type="sound",name="surface-thunderstorm-thunder",priority=10,variations={
  {filename="__deep-caves__/sound/weather/muffled-thunder-1.wav",volume=4.8},
  {filename="__deep-caves__/sound/weather/muffled-thunder-2.wav",volume=4.8}
 }}
})

data:extend({
 {type="sound",name="surface-thunderstorm-muffled-rain-a",variations={
  {filename="__deep-caves__/sound/weather/muffled-rain-1.wav",volume=6.0},
  {filename="__deep-caves__/sound/weather/muffled-rain-3.wav",volume=6.0}}},
 {type="sound",name="surface-thunderstorm-muffled-rain-b",variations={
  {filename="__deep-caves__/sound/weather/muffled-rain-2.wav",volume=6.0},
  {filename="__deep-caves__/sound/weather/muffled-rain-4.wav",volume=6.0}}}
})

-- Weather exposure has its own damage type so small pulses aren't entirely
-- cancelled by flat physical/acid armor resistance. Energy shields still work.
data:extend({{type="damage-type",name="surface-thunderstorm-exposure"}})

-- Low-pass filtered thunder heard through surface openings on Cave 1.
data:extend({{type="sound",name="surface-thunderstorm-muffled-thunder",priority=10,variations={
 {filename="__deep-caves__/sound/weather/muffled-thunder-1.wav",volume=2.55},
 {filename="__deep-caves__/sound/weather/muffled-thunder-2.wav",volume=2.55}
}}})
