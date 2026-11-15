require("prototypes.difficulty")

-- Land transitions need to recognize the custom void-like tile; otherwise
-- their normal ground overlay makes narrow painted walls walkable.
for _,tile in pairs(data.raw.tile) do
  for _,transition in ipairs(tile.transitions or {}) do
    local edge,already=false,false
    for _,name in ipairs(transition.to_tiles or {}) do
      if name=="out-of-map" then edge=true end
      if name=="cave-wall" then already=true end
    end
    if edge and not already then transition.to_tiles[#transition.to_tiles+1]="cave-wall" end
  end
end

-- Script-destroyed targeted projectiles leave predicted damage on their
-- intended victims in Factorio 2.0.76. There is no runtime reset API.
-- Keep health-based targets eligible despite those stale reservations.
-- This also restores targeting for existing affected entities on reload.
-- Actual damage, health and resistance calculations are unchanged.
for _,prototypes in pairs(data.raw) do
  for _,prototype in pairs(prototypes) do
    if prototype.max_health then prototype.overkill_fraction=1e30 end
  end
end

require("prototypes.cave_walls.turret-bullets")

require("prototypes.cave_walls.flamethrowers")

-- Track native deployments/shots when they are created instead of searching
-- every generated surface every tick. Preserve all existing creation actions.
for _,kind in ipairs({"construction-robot","logistic-robot","combat-robot","capture-robot","projectile","artillery-projectile"}) do
  for _,prototype in pairs(data.raw[kind] or {}) do
    local hook={type="direct",action_delivery={type="instant",target_effects={{type="script",effect_id="cave-wall-flying-created"}}}}
    local old=prototype.created_effect
    if old then
      old=old.type and {old} or old
      old[#old+1]=hook;prototype.created_effect=old
    else prototype.created_effect=hook end
  end
end

-- Apply the cave-creature palette after other prototype construction.
require("prototypes.cave_creatures")
