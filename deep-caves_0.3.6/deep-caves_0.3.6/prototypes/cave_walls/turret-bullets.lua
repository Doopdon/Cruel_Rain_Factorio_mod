-- Split magazine effects by shooter. Player/vehicle ammunition remains native;
-- turret-only instant hits become real projectiles carrying the same hit effects.
local serial=0
local function list(value) return value.type and {value} or value end
local function convert(action,ammo_name)
  for _,trigger in ipairs(list(action)) do
    local deliveries={}
    for _,delivery in ipairs(list(trigger.action_delivery)) do
      if delivery.type=="instant" and delivery.target_effects then
        serial=serial+1
        local name="cave-wall-turret-bullet-"..ammo_name.."-"..serial
        data:extend({{
          type="projectile",name=name,hidden=true,flags={"not-on-map"},
          acceleration=0,max_speed=.8,turn_speed=1,
          collision_box={{0,0},{0,0}},
          animation={filename="__base__/graphics/entity/bullet/bullet.png",width=3,height=50,
            scale=.24,draw_as_glow=true,priority="high"},
          action={type="direct",action_delivery={type="instant",target_effects=table.deepcopy(delivery.target_effects)}},
          created_effect={type="direct",action_delivery={type="instant",
            target_effects={{type="script",effect_id="cave-wall-bullet-created"}}}}
        }})
        -- Muzzle flash stays at the shooter. Only the projectile applies damage.
        if delivery.source_effects then
          deliveries[#deliveries+1]={type="instant",source_effects=table.deepcopy(delivery.source_effects)}
        end
        deliveries[#deliveries+1]={type="projectile",projectile=name,starting_speed=.8}
      else deliveries[#deliveries+1]=delivery end
    end
    trigger.action_delivery=deliveries
  end
end
for _,name in ipairs({"firearm-magazine","piercing-rounds-magazine","uranium-rounds-magazine"}) do
  local ammo=data.raw.ammo[name]
  if ammo then
    local variants
    if ammo.ammo_type.action or ammo.ammo_type.target_type then
      local original=table.deepcopy(ammo.ammo_type);original.source_type="default"
      local turret=table.deepcopy(original);turret.source_type="turret"
      variants={original,turret}
    else
      variants=table.deepcopy(ammo.ammo_type)
      local turret,fallback
      for _,variant in ipairs(variants) do
        if variant.source_type=="turret" then turret=variant end
        if variant.source_type=="default" then fallback=variant end
      end
      if not turret then
        turret=table.deepcopy(fallback or variants[1]);turret.source_type="turret"
        variants[#variants+1]=turret
      end
    end
    for _,variant in ipairs(variants) do
      if variant.source_type=="turret" and variant.action then convert(variant.action,name) end
    end
    ammo.ammo_type=variants
  end
end
