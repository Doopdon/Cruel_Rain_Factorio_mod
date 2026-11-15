local native_mine = data.raw["land-mine"]["land-mine"]
local function overlay_picture(base, overlay)
  return {layers = {table.deepcopy(base), {
    filename = "__base__/graphics/icons/" .. overlay .. ".png",
    width = 64, height = 64, scale = 0.30, shift = {0, -0.08},
    flags = {"mipmap", "linear-minification", "linear-magnification"}
  }}}
end
local function make_trap(name, overlay, radius, ingredients, order)
  local mine = table.deepcopy(native_mine)
  mine.name = name
  mine.minable = {mining_time = 0.2, result = name}
  mine.fast_replaceable_group = nil
  mine.next_upgrade = nil
  mine.corpse = nil
  mine.dying_explosion = nil
  mine.timeout = 30
  mine.trigger_interval = 1
  mine.trigger_radius = radius
  mine.trigger_force = "enemy"
  mine.force_die_on_attack = true
  mine.picture_safe = overlay_picture(native_mine.picture_safe, overlay)
  mine.picture_set = overlay_picture(native_mine.picture_set, overlay)
  mine.picture_set_enemy = overlay_picture(native_mine.picture_set_enemy, overlay)
  mine.icon = nil
  mine.icon_size = nil
  mine.icons = {
    {icon = "__base__/graphics/icons/land-mine.png", icon_size = 64},
    {icon = "__base__/graphics/icons/" .. overlay .. ".png", icon_size = 64, scale = 0.3, shift = {0, -2}}
  }
  -- One script event performs the entire outcome before the mine is spent.
  mine.action = {type = "direct", action_delivery = {type = "instant",
    source_effects = {{type = "script", effect_id = name .. "-trigger"}}}}
  return {mine,
    {type = "item", name = name, icons = table.deepcopy(mine.icons),
      subgroup = "defensive-structure", order = order, place_result = name, stack_size = 100},
    {type = "recipe", name = name, enabled = true, energy_required = 0.5,
      ingredients = ingredients, results = {{type = "item", name = name, amount = 1}}}
  }
end
for _, prototype in ipairs(make_trap("iw-claymore", "pipe", 2.5, {
  {type = "item", name = "coal", amount = 5}, {type = "item", name = "stone", amount = 5},
  {type = "item", name = "pipe", amount = 1}
}, "a[early-defense]-c[claymore]")) do data:extend({prototype}) end
for _, prototype in ipairs(make_trap("iw-bear-trap", "iron-gear-wheel", 0.01, {
  {type = "item", name = "iron-plate", amount = 5},
  {type = "item", name = "iron-gear-wheel", amount = 3}
}, "a[early-defense]-d[bear-trap]")) do data:extend({prototype}) end

local dud = table.deepcopy(data.raw.fire["fire-flame"])
dud.name = "iw-claymore-dud-fire"
dud.initial_lifetime = 300
dud.maximum_lifetime = 300
dud.lifetime_increase_by = 0
dud.maximum_spread_count = 0
dud.spawn_entity = nil
dud.maximum_damage_multiplier = 1
dud.damage_multiplier_increase_per_added_fuel = 0
dud.damage_multiplier_decrease_per_tick = 0
dud.on_damage_tick_effect = nil
-- Scripted contact damage in traps.lua limits dud flames to units/characters.
dud.damage_per_tick = {amount = 0, type = "fire"}
dud.burnt_patch_pictures = nil
dud.burnt_patch_lifetime = 0
dud.fade_in_duration = 1
dud.fade_out_duration = 30
data:extend({dud})
