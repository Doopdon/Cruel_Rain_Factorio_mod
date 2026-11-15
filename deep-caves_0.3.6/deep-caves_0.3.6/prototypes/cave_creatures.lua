-- Reuse Factorio's body color masks instead of replacing sprite sheets or
-- recreating live enemies. Prototype changes also recolor existing saves.
local seen = {}
local function whiten_masks(value)
  if type(value) ~= "table" or seen[value] then return end
  seen[value] = true

  local sprite = value.filename or value.filenames or value.stripes
  if sprite and not value.draw_as_shadow and not value.draw_as_glow
      and not value.draw_as_light then
    local mask = type(value.filename) == "string"
        and value.filename:find("-mask", 1, true)
    if value.tint or mask then
      value.tint = {r=1, g=1, b=1, a=1}
      value.apply_runtime_tint = false
    end
  end
  for _, child in pairs(value) do
    if type(child) == "table" then whiten_masks(child) end
  end
end

local function recolor(kind, name)
  local prototype = (data.raw[kind] or {})[name]
  if not prototype then return end
  whiten_masks(prototype)
  -- Follow corpse references so dying and decaying creatures use the same
  -- palette, including the spawners' four corpse animation variations.
  local corpses = prototype.corpse
  if type(corpses) == "string" then corpses = {corpses} end
  for _, corpse in pairs(corpses or {}) do
    if type(corpse) == "string" then
      whiten_masks((data.raw.corpse or {})[corpse])
    end
  end
end

for _, size in ipairs({"small", "medium", "big", "behemoth"}) do
  recolor("unit", size .. "-biter")
  recolor("unit", size .. "-spitter")
  recolor("turret", size .. "-worm-turret")
end
recolor("unit-spawner", "biter-spawner")
recolor("unit-spawner", "spitter-spawner")

-- Nests must not trap their own newly spawned units in narrow cave pockets.
-- Keep their footprint/selection and vulnerability, but make it passable.
for _,name in ipairs({"biter-spawner","spitter-spawner"}) do
  local nest=(data.raw["unit-spawner"] or {})[name]
  if nest then nest.collision_mask={layers={}} end
end

-- Native enemy expansion requires all enemy-base structures to share a mask.
-- Match burrowing worms to the passable nests rather than break expansion.
for _,size in ipairs({"small","medium","big","behemoth"}) do
  local worm=(data.raw.turret or {})[size.."-worm-turret"]
  if worm then worm.collision_mask={layers={}} end
end
