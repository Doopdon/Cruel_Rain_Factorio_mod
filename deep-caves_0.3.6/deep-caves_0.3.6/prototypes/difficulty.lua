-- Scale complete research units, preserving each unit's ingredients and time.
-- Final fixes runs after the base game and Space Age adjust their costs.
local research=settings.startup["deep-caves-research-cost"].value
local rockets=settings.startup["deep-caves-rocket-cost"].value
local surface_only=settings.startup["deep-caves-surface-silos-only"].value
for _,technology in pairs(data.raw.technology) do
  local unit=technology.unit
  if unit then
    if unit.count then unit.count=math.max(1,math.ceil(unit.count*research)) end
    if unit.count_formula then
      -- Keep the previous default expression stable for existing saves.
      local scale=research==.1 and " / 10" or " * "..tostring(research)
      unit.count_formula="max(1, ("..unit.count_formula..")"..scale..")"
    end
  end
end

-- Native surface conditions require Space Age. The shared build handler also
-- rejects underground placement in the base game and refunds consumed items.
if feature_flags.space_travel then
  data:extend{{type="surface-property",name="deep-caves-above-ground",default_value=1}}
end
for _,silo in pairs(data.raw["rocket-silo"]) do
  silo.rocket_parts_required=math.max(1,math.ceil(silo.rocket_parts_required*rockets))
  if surface_only then
    local hint={"entity-description.deep-caves-surface-silo"}
    silo.localised_description=silo.localised_description and {"",silo.localised_description,"\n",hint} or hint
  end
  if feature_flags.space_travel and surface_only then
    silo.surface_conditions=silo.surface_conditions or {}
    silo.surface_conditions[#silo.surface_conditions+1]={property="deep-caves-above-ground",min=1,max=1}
  end
end
