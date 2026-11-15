local masks=require("collision-mask-util")
-- Add a dedicated layer while preserving all existing mask layers/options.
-- Characters, vehicles, trains, robots and buildings never get this layer.
for _,unit in pairs(data.raw.unit or {}) do
  unit.collision_mask=table.deepcopy(masks.get_mask(unit))
  unit.collision_mask.layers["biter-caution-only"]=true
end
