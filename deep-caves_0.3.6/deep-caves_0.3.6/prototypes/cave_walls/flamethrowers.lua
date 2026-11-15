-- Keep native stream particles, fuel bonuses, fire and research calculations.
-- A source effect records the muzzle; stream position is the source/target midpoint.
local turret=data.raw["fluid-turret"]["flamethrower-turret"]
if not turret then return end
local stream=table.deepcopy(data.raw.stream["flamethrower-fire-stream"])
stream.name="cave-wall-flamethrower-stream"
local hook={type="direct",action_delivery={type="instant",target_effects={{type="script",effect_id="cave-wall-flame-created"}}}}
if stream.created_effect then
  local old=stream.created_effect
  if old.type then old={old} end
  old[#old+1]=hook;stream.created_effect=old
else stream.created_effect=hook end
data:extend({stream})
local function visit(action)
  local actions=action.type and {action} or action
  for _,trigger in ipairs(actions) do
    local deliveries=trigger.action_delivery
    if deliveries then
      deliveries=deliveries.type and {deliveries} or deliveries
      for _,delivery in ipairs(deliveries) do
        if delivery.type=="stream" and delivery.stream=="flamethrower-fire-stream" then
          delivery.stream=stream.name
          local effects=delivery.source_effects or {}
          if effects.type then effects={effects} end
          table.insert(effects,1,{type="script",effect_id="cave-wall-flame-source"})
          delivery.source_effects=effects
        end
      end
    end
  end
end
visit(turret.attack_parameters.ammo_type.action)
