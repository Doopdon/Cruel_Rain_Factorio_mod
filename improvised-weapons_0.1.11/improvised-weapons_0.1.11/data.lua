local fire_name = "iw-defense-fire"
local flame_name = "iw-defense-flame"
-- Use the broader vanilla flame-03 frame and enlarge its menu presentation.
local fire_icon = "__base__/graphics/entity/fire-flame/fire-flame-03.png"
local fire_icon_size = 84
local fire_icons = {{icon = fire_icon, icon_size = fire_icon_size, scale = 0.5}}
local coal_sheet = data.raw.resource.coal.stages.sheet

-- A walkable one-tile container gives ordinary inserters a real
-- inventory to target. The paired fire supplies the game's fire visuals/damage.
local fuel_holder = table.deepcopy(data.raw.container["wooden-chest"])
fuel_holder.name = fire_name
fuel_holder.icon = nil
fuel_holder.icons = table.deepcopy(fire_icons)
fuel_holder.icon_size = nil
fuel_holder.minable = {mining_time = 0.2}
fuel_holder.max_health = 100
fuel_holder.resistances = {{type = "fire", percent = 100}}
fuel_holder.corpse = nil
fuel_holder.dying_explosion = nil
fuel_holder.damaged_trigger_effect = nil
fuel_holder.fast_replaceable_group = nil
fuel_holder.next_upgrade = nil
fuel_holder.inventory_size = 1
fuel_holder.inventory_type = "with_filters_and_bar"
fuel_holder.quality_affects_inventory_size = false
fuel_holder.collision_box = {{-0.35, -0.35}, {0.35, 0.35}}
fuel_holder.selection_box = {{-0.5, -0.5}, {0.5, 0.5}}
fuel_holder.collision_mask = {layers = {water_tile = true, object = true, item = true}}
-- Use one full-density frame from the native coal sheet as a static sprite.
-- This is only the fuel holder's picture; no resource entity is created.
fuel_holder.picture = {
  filename = coal_sheet.filename,
  size = coal_sheet.size,
  width = coal_sheet.width,
  height = coal_sheet.height,
  x = 0,
  y = 0,
  scale = coal_sheet.scale or 0.5,
  shift = coal_sheet.shift,
  priority = "extra-high"
}
fuel_holder.circuit_connector = nil
fuel_holder.circuit_wire_max_distance = 0
fuel_holder.draw_circuit_wires = false
fuel_holder.draw_copper_wires = false
fuel_holder.localised_name = {"entity-name.iw-defense-fire"}
fuel_holder.localised_description = {"entity-description.iw-defense-fire"}

-- Copy the vanilla flame for visuals. Scripted square-area damage lets the
-- defense exempt inserters without changing any other weapon's damage.
local flame = table.deepcopy(data.raw.fire["fire-flame"])
flame.name = flame_name
flame.localised_name = {"entity-name.iw-defense-fire"}
flame.damage_per_tick = {amount = 0, type = "fire"}
flame.on_damage_tick_effect = nil
-- Fuel accounting and extinguishing are owned by control.lua. If this very
-- long native lifetime ever expires, the next update recreates the flame.
flame.initial_lifetime = 2147483647
flame.maximum_lifetime = 2147483647
flame.lifetime_increase_by = 0
flame.maximum_spread_count = 0
flame.spawn_entity = nil
flame.maximum_damage_multiplier = 1
flame.damage_multiplier_increase_per_added_fuel = 0
flame.damage_multiplier_decrease_per_tick = 0
flame.emissions_per_second = {pollution = 0}
flame.burnt_patch_pictures = nil
flame.burnt_patch_lifetime = 0
flame.fade_in_duration = 1
flame.smoke_fade_in_duration = 1
flame.render_layer = "higher-object-above"
flame.initial_render_layer = "higher-object-above"

data:extend({
  fuel_holder,
  flame,
  {
    type = "item",
    name = fire_name,
    icons = table.deepcopy(fire_icons),
    subgroup = "defensive-structure",
    order = "a[early-defense]-a[fire]",
    place_result = fire_name,
    stack_size = 50
  },
  {
    type = "recipe",
    name = fire_name,
    enabled = true,
    energy_required = 0.5,
    ingredients = {
      {type = "item", name = "stone", amount = 5},
      {type = "item", name = "coal", amount = 5}
    },
    results = {{type = "item", name = fire_name, amount = 1}}
  }
})

-- Reuse the installed game's roboport rotor and burner-drill body.
local rotor = table.deepcopy(data.raw.roboport.roboport.base_animation)
local drill = data.raw["mining-drill"]["burner-mining-drill"]
local drill_animation = (drill.graphics_set and drill.graphics_set.animation) or drill.animations
local north = drill_animation.north or drill_animation
local function body_layer(animation)
  if animation.layers then
    for _, layer in ipairs(animation.layers) do
      local candidate = body_layer(layer)
      if candidate then return candidate end
    end
  elseif animation.filename and not animation.draw_as_shadow and not animation.draw_as_glow then
    return animation
  end
end
local body = assert(body_layer(north), "Improvised Weapons: burner drill body sprite missing")
local body_width = body.width or (type(body.size) == "number" and body.size or body.size[1])
local body_height = body.height or (type(body.size) == "number" and body.size or body.size[2])
local spinner = {
  type = "radar",
  name = "iw-spinner",
  -- GUI icons require square source regions. A 59px square stays within the
  -- rotor's first 83x59 frame and never reads an adjacent animation frame.
  icons = {{icon = rotor.filename, icon_size = math.min(rotor.width, rotor.height),
    scale = 32 / math.min(rotor.width, rotor.height)}},
  flags = {"placeable-player", "player-creation"},
  minable = {mining_time = 0.2, result = "iw-spinner"},
  max_health = 200,
  collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
  selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
  energy_source = {
    type = "burner", fuel_categories = {"chemical"}, fuel_inventory_size = 1,
    burnt_inventory_size = 1, effectivity = 1, emissions_per_minute = {pollution = 30}
  },
  energy_usage = "400kW",
  energy_per_sector = "1GJ",
  energy_per_nearby_scan = "1GJ",
  max_distance_of_sector_revealed = 0,
  max_distance_of_nearby_sector_revealed = 0,
  connects_to_other_radars = false,
  is_military_target = true,
  rotation_speed = 0.25,
  integration_patch = {
    filename = body.filename, width = body_width, height = body_height,
    x = body.x or 0, y = body.y or 0,
    scale = 32 / math.max(body_width, body_height), shift = {0, 0}, priority = "high",
    -- Mipmaps and linear sampling soften the source art when reduced to 1 tile.
    flags = {"mipmap", "linear-minification", "linear-magnification", "linear-mip-level"}
  },
  pictures = {
    filename = rotor.filename, width = rotor.width, height = rotor.height,
    direction_count = rotor.frame_count, line_length = rotor.line_length or rotor.frame_count,
    scale = 64 / rotor.width, shift = {0, -0.15}, apply_projection = false,
    priority = "extra-high"
  }
}
data:extend({spinner,
  {type = "item", name = "iw-spinner", icons = table.deepcopy(spinner.icons),
    subgroup = "defensive-structure", order = "a[early-defense]-b[spinner]",
    place_result = "iw-spinner", stack_size = 50},
  {type = "recipe", name = "iw-spinner", enabled = true, energy_required = 0.5,
    ingredients = {{type = "item", name = "iron-plate", amount = 10},
      {type = "item", name = "iron-gear-wheel", amount = 5},
      {type = "item", name = "stone", amount = 5}},
    results = {{type = "item", name = "iw-spinner", amount = 1}}}
})

require("trap-prototypes")

require("fence-prototypes")
