local prefix = "__improvised-weapons__/graphics/"
local function cell(mask)
  return {filename = prefix .. "barbed-wire-atlas.png", width = 64, height = 64,
    x = (mask % 4) * 64, y = math.floor(mask / 4) * 64, scale = 0.5}
end
local wire = table.deepcopy(data.raw.wall["stone-wall"])
wire.name = "iw-barbed-wire"
wire.icon = prefix .. "barbed-wire-icon.png"
wire.icons = nil
wire.icon_size = 64
wire.minable = {mining_time = 0.1, result = wire.name}
wire.max_health = 80
wire.resistances = {}
wire.fast_replaceable_group = "iw-wire-wall"
wire.next_upgrade = nil
wire.corpse = nil
wire.dying_explosion = nil
wire.visual_merge_group = 818
-- Complete fence tiles are rendered once per entity by wire-visuals.lua.
-- The native wall compositor expects partial pictures and otherwise repeats
-- the center posts when complete tiles are supplied as "filling" pieces.
local blank = {filename = "__core__/graphics/empty.png", width = 1, height = 1}
wire.pictures = {}
for _, name in ipairs({"single","straight_vertical","straight_horizontal","corner_right_down",
  "corner_left_down","t_up","ending_left","ending_right","filling"}) do
  wire.pictures[name] = table.deepcopy(blank)
end
for mask = 0, 15 do
  local sprite = cell(mask)
  sprite.type = "sprite"
  sprite.name = "iw-barbed-wire-mask-" .. mask
  data:extend({sprite})
end

wire.connected_gate_visualization = nil
wire.wall_diode_green = nil
wire.wall_diode_red = nil
wire.wall_diode_green_light_top = nil
wire.wall_diode_green_light_bottom = nil
wire.wall_diode_green_light_left = nil
wire.wall_diode_green_light_right = nil
wire.wall_diode_red_light_top = nil
wire.wall_diode_red_light_bottom = nil
wire.wall_diode_red_light_left = nil
wire.wall_diode_red_light_right = nil
wire.circuit_connector = nil
wire.circuit_wire_max_distance = 0
wire.draw_circuit_wires = false
local fence = table.deepcopy(data.raw["electric-pole"]["small-electric-pole"])
fence.name = "iw-electric-fence"
fence.icon = prefix .. "electric-fence.png"
fence.icons = nil
fence.icon_size = 64
fence.minable = {mining_time = 0.1, result = fence.name}
fence.max_health = 180
fence.resistances = {}
fence.collision_box = {{-0.49,-0.49},{0.49,0.49}}
fence.selection_box = {{-0.5,-0.5},{0.5,0.5}}
fence.drawing_box_vertical_extension = 1
fence.fast_replaceable_group = nil
fence.next_upgrade = nil
fence.corpse = nil
fence.dying_explosion = nil
fence.quality_indicator_scale = 0.5
fence.pictures = {filename = prefix .. "electric-fence.png", width = 64, height = 64,
  direction_count = 1, scale = 0.5, shift = {0,-0.45}}
fence.water_reflection = nil
fence.maximum_wire_distance = 1.5
fence.supply_area_distance = 2.5
fence.auto_connect_up_to_n_wires = 5
fence.connection_points = {{wire = {copper = {-0.1,-0.65}, red = {-0.1,-0.45}, green = {-0.1,-0.25}},
  shadow = {copper = {0,0}, red = {-0.1,0}, green = {0.1,0}}}}
local function consumer(name, usage, buffer)
  return {
    type = "electric-energy-interface", name = name,
    icon = name == "iw-fence-power" and prefix .. "electric-fence.png" or "__base__/graphics/icons/flamethrower-turret.png", icon_size = 64,
    minable = nil,
    flags = {"placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable", "not-selectable-in-game"},
    hidden = true, max_health = 1, collision_box = {{0,0},{0,0}}, collision_mask = {layers = {}},
    energy_source = {type = "electric", usage_priority = "secondary-input",
      buffer_capacity = buffer, drain = "0W", input_flow_limit = "200kW", output_flow_limit = "0W"},
    energy_usage = usage, energy_production = "0W", gui_mode = "none",
    picture = {filename = "__core__/graphics/empty.png", width = 1, height = 1}
  }
end
data:extend({wire, fence,
  consumer("iw-fence-power", "20kW", "10kJ"),
  consumer("iw-flamethrower-power", "50kW", "10kJ")})
local function item_recipe(name, icon, ingredients, order)
  data:extend({
    {type = "item", name = name, icon = icon, icon_size = 64, subgroup = "defensive-structure",
      order = order, place_result = name, stack_size = 100},
    {type = "recipe", name = name, enabled = true, energy_required = 0.5,
      ingredients = ingredients, results = {{type = "item", name = name, amount = 1}}}
  })
end
item_recipe(wire.name, wire.icon, {{type = "item", name = "iron-stick", amount = 2}}, "a[early-defense]-e[barbed-wire]")
item_recipe(fence.name, fence.icon, {{type = "item", name = "iron-stick", amount = 4},
  {type = "item", name = "copper-cable", amount = 2}}, "a[early-defense]-f[electric-fence]")


-- Reuse only the accumulator's electrical overlay, without its machine body.
local accumulator = data.raw.accumulator.accumulator
local graphics = accumulator.chargable_graphics or accumulator
local function spark_layer(animation)
  if animation.layers then
    for _, layer in ipairs(animation.layers) do
      local found = spark_layer(layer)
      if found then return found end
    end
  elseif animation.filename and animation.draw_as_glow then
    return animation
  end
end
local sparks = table.deepcopy(assert(spark_layer(graphics.discharge_animation),
  "Improvised Weapons: accumulator discharge sparks missing"))
sparks.scale = (sparks.scale or 1) * 0.5
sparks.shift = {0, 0}
sparks.animation_speed = 1
local contact = {
  type = "explosion", name = "iw-fence-contact-sparks",
  flags = {"not-on-map"}, hidden = true,
  animations = {sparks}, render_layer = "higher-object-above",
  light = {intensity = 0.5, size = 2, color = {r = 0.45, g = 0.7, b = 1}},
  light_intensity_factor_final = 0
}
local discharge = table.deepcopy(contact)
discharge.name = "iw-fence-discharge"
discharge.animations[1].shift = {0, -0.65}
discharge.sound = {
  filename = "__base__/sound/accumulator-discharging.ogg", volume = 0.4,
  audible_distance_modifier = 0.5,
  aggregation = {max_count = 3, remove = true, count_already_playing = true}
}
data:extend({contact, discharge})
