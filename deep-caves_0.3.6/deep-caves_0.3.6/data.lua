require("prototypes.cave_walls.data")
require("prototypes.weather.data")
local down = table.deepcopy(data.raw["electric-pole"]["medium-electric-pole"])
-- Each visible ramp is a native electric pole with a stable unit number.
down.type = "electric-pole"
down.pictures = nil
down.name = "deep-caves-ramp-down"
down.localised_name = {"entity-name.deep-caves-ramp-down"}
down.localised_description = {"entity-description.deep-caves-ramp-down"}
down.minable = nil
down.autoplace = nil
down.flags = {"placeable-neutral", "placeable-off-grid", "get-by-unit-number", "not-deconstructable", "not-blueprintable", "not-rotatable"}
down.max_health = 1000000
down.collision_box = {{-0.7, -0.7}, {0.7, 0.7}}
down.selection_box = {{-1.2, -1.2}, {1.2, 1.2}}

local up = table.deepcopy(data.raw["electric-pole"]["medium-electric-pole"])
up.type = "electric-pole"
up.pictures = nil
up.name = "deep-caves-ramp-up"
up.localised_name = {"entity-name.deep-caves-ramp-up"}
up.localised_description = {"entity-description.deep-caves-ramp-up"}
up.minable = nil
up.autoplace = nil
up.flags = {"placeable-neutral", "placeable-off-grid", "get-by-unit-number", "not-deconstructable", "not-blueprintable", "not-rotatable"}
up.max_health = 1000000
up.collision_box = {{-0.7, -0.7}, {0.7, 0.7}}
up.selection_box = {{-1.2, -1.2}, {1.2, 1.2}}

local linked_belt = table.deepcopy(data.raw["linked-belt"]["linked-belt"])
linked_belt.name = "deep-caves-linked-belt"
linked_belt.localised_name = {"entity-name.deep-caves-linked-belt"}
linked_belt.minable = nil
linked_belt.hidden = true
linked_belt.max_health = 1000000
linked_belt.allow_clone_connection = false
linked_belt.allow_blueprint_connection = false

local power = table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
power.name = "deep-caves-power-interface"
power.localised_name = {"entity-name.deep-caves-power-interface"}
power.minable = nil
power.hidden = true
power.gui_mode = "none"
power.energy_production = "0W"
power.energy_usage = "0W"
power.energy_source = {
  type = "electric",
  buffer_capacity = "40MJ",
  usage_priority = "tertiary",
  input_flow_limit = "12MW",
  output_flow_limit = "12MW",
  render_no_network_icon = false,
  render_no_power_icon = false
}


for _, entrance in ipairs({down, up}) do
  local kind = entrance == down and "down" or "up"
  entrance.selectable_in_game = true
  entrance.selection_priority = 60
  entrance.picture = nil
  entrance.pictures = {filename="__core__/graphics/empty.png",
    width=1,height=1,direction_count=1}
  -- Pole artwork normally occupies the object layer, covering characters.
  -- A stationary native visual keeps the ramp on the ground for every entity,
  -- including existing entrances, without maintaining Lua rendering objects.
  entrance.stateless_visualisation = {{count=1,render_layer="floor",animation={
    filename="__deep-caves__/graphics/ramp-"..kind.."-north.png",
    width=256,height=256,frame_count=1,line_length=1,scale=0.375}}}
  -- Block structures and ground belts/rails without blocking characters.
  entrance.collision_mask = {layers = {object=true, floor=true, elevated_rail=true}}
  -- Off-grid entrances can lie half a tile from the plumbing grid. Leave
  -- clearance for the closer pipes while still blocking the ramp's center.
  entrance.collision_box = {{-0.99,-0.99},{0.99,0.99}}
  entrance.selection_box = {{-0.99,-0.99},{0.99,0.99}}
  -- Reach the first buildable tile outside the full three-tile footprint,
  -- including ramps that sit between tile centers.
  entrance.maximum_wire_distance = 2.75
  entrance.supply_area_distance = 1
  -- One frame and one wire attachment: native pole auto-orientation has
  -- no alternate artwork to select when neighboring wires change.
  local wire_y = kind == "up" and -1.25 or -0.5
  entrance.connection_points = {{
    wire={copper={0,wire_y},red={-0.2,wire_y},green={0.2,wire_y}},
    shadow={copper={0,wire_y},red={-0.2,wire_y},green={0.2,wire_y}}}}
  entrance.water_reflection = nil
  entrance.fast_replaceable_group = nil
  entrance.next_upgrade = nil
  entrance.drawing_box_vertical_extension = 0
  entrance.icon = "__deep-caves__/graphics/ramp-"..kind.."-north.png"
  entrance.icon_size = 256
  entrance.icons = nil
end
-- Surface openings clean their cave chunk passively, through the same native
-- negative-emissions mechanism used by trees. Ordinary ascents stay distinct.
local vent = table.deepcopy(up)
vent.name = "deep-caves-vent"
vent.localised_name = {"entity-name.deep-caves-vent"}
vent.localised_description = {"entity-description.deep-caves-vent"}
vent.emissions_per_second = {pollution = -settings.startup["deep-caves-vent-absorption"].value / 60}
vent.localised_description = {"entity-description.deep-caves-vent",tostring(settings.startup["deep-caves-vent-absorption"].value)}

-- A native fluid buffer under each ramp connects to its mate with a linked
-- fluidbox connection. The engine owns flow, temperature and conservation.
-- Grid-aligned plumbing also works under older off-grid ramp positions.
local fluid = table.deepcopy(data.raw["storage-tank"]["storage-tank"])
fluid.name = "deep-caves-ramp-fluid"
fluid.localised_name = {"entity-name.deep-caves-ramp-fluid"}
fluid.localised_description = {"entity-description.deep-caves-ramp-fluid"}
fluid.minable = nil
fluid.max_health = 1000000
fluid.flags = {"placeable-neutral","player-creation","not-on-map","not-blueprintable","not-deconstructable","not-upgradable","not-rotatable"}
fluid.collision_mask = {layers={}}
fluid.collision_box = {{-1.49,-1.49},{1.49,1.49}}
fluid.selection_box = {{-1.5,-1.5},{1.5,1.5}}
fluid.selectable_in_game = false
fluid.two_direction_only = false
fluid.fast_replaceable_group = nil
fluid.next_upgrade = nil
fluid.circuit_connector = nil
fluid.circuit_wire_max_distance = 0
fluid.draw_copper_wires = false
fluid.draw_circuit_wires = false
fluid.show_fluid_icon = false
fluid.working_sound = nil
fluid.water_reflection = nil
fluid.fluid_box.volume = 1000
fluid.fluid_box.hide_connection_info = true
fluid.fluid_box.pipe_covers = nil
fluid.fluid_box.pipe_picture = nil
fluid.fluid_box.always_draw_covers = false
fluid.fluid_box.pipe_connections = {
  {direction=defines.direction.north,position={0,-1}},
  {direction=defines.direction.east,position={1,0}},
  {direction=defines.direction.south,position={0,1}},
  {direction=defines.direction.west,position={-1,0}},
  {connection_type="linked",linked_connection_id=1}
}
local empty = {filename="__core__/graphics/empty.png",width=1,height=1}
fluid.pictures = {picture={north=empty,east=empty,south=empty,west=empty},
  fluid_background=empty,window_background=empty,flow_sprite=empty,
  gas_flow={filename="__core__/graphics/empty.png",width=1,height=1,frame_count=1}}
fluid.window_bounding_box = {{0,0},{0,0}}

power.picture = {filename="__core__/graphics/empty.png",width=1,height=1}
power.pictures = nil
power.animation = nil
power.animations = nil
power.collision_mask = {layers={}}
power.collision_box = {{0,0},{0,0}}
power.selectable_in_game = false
power.flags = {"placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable"}

local floors = {}
for depth = 1, 12 do
  local floor = table.deepcopy(data.raw.tile["nuclear-ground"])
  floor.name = "deep-caves-stone-" .. depth
  floor.localised_name = {"tile-name.deep-caves-stone", tostring(depth)}
  floor.minable = nil
  floor.walking_speed_modifier = 1
  floor.tint = {r = 0.92 - (depth-1)*0.05, g = 0.94 - (depth-1)*0.05, b = 0.96 - (depth-1)*0.048, a=1}
  floor.map_color = {r=0.43-(depth-1)*0.023, g=0.45-(depth-1)*0.023, b=0.47-(depth-1)*0.023}
  floors[#floors+1] = floor
end
for depth=1,12 do
  for _,kind in ipairs({"earth","sand"}) do
    local tile=table.deepcopy(data.raw.tile[kind=="earth" and "dirt-5" or "sand-2"])
    tile.name="deep-caves-"..kind.."-"..depth
    tile.localised_name={"tile-name.deep-caves-"..kind,tostring(depth)}
    tile.minable=nil
    tile.autoplace=nil
    tile.walking_speed_modifier=1
    local shade=math.max(0.42,1-(depth-1)*0.05)
    tile.tint={r=shade,g=shade,b=shade,a=1}
    tile.map_color=kind=="earth" and {r=.40*shade,g=.30*shade,b=.21*shade} or {r=.49*shade,g=.42*shade,b=.29*shade}
    floors[#floors+1]=tile
  end
end
data:extend(floors)

-- The cave terminals are script-created.  They intentionally have no player-placeable items yet.
-- The invisible container serves inserters and the native inventory GUI.
-- Clicking the visible pole redirects to this pair's private shared inventory.
local cargo=table.deepcopy(data.raw["linked-container"]["linked-chest"])
cargo.name="deep-caves-ramp-inventory-12"
cargo.localised_name={"entity-name.deep-caves-ramp-inventory"}
cargo.localised_description={"entity-description.deep-caves-ramp-inventory"}
cargo.inventory_size=12
cargo.inventory_type="with_filters_and_bar"
cargo.gui_mode="none"
cargo.selectable_in_game=false
cargo.minable=nil
cargo.max_health=1000000
cargo.flags={"placeable-neutral","placeable-off-grid","player-creation","not-deconstructable","not-blueprintable","not-upgradable"}
-- The inventory spans the entire ramp, so ordinary inserters can target
-- its near edge from outside the protected footprint.
cargo.collision_box={{-1.49,-1.49},{1.49,1.49}}
-- Keep the full inserter target area without obstructing the closer pipes.
-- The visible ramp protects the center from buildings.
cargo.collision_mask={layers={}}
cargo.selection_box={{-1.5,-1.5},{1.5,1.5}}
cargo.picture={filename="__core__/graphics/empty.png",width=1,height=1}
cargo.draw_inventory_content=false
cargo.circuit_connector=nil
cargo.circuit_wire_max_distance=0
cargo.fast_replaceable_group=nil
cargo.next_upgrade=nil
cargo.allow_copy_paste=false
cargo.icons=nil
cargo.icon="__base__/graphics/icons/linked-chest-icon.png"
cargo.icon_size=64
-- Preserve the 48-slot prototype until the configuration migration has copied
-- its contents. Shrinking it in place can truncate saved stacks before Lua runs.
local legacy_cargo=table.deepcopy(cargo)
legacy_cargo.name="deep-caves-ramp-inventory"
legacy_cargo.inventory_size=48
legacy_cargo.inventory_type="with_bar"
legacy_cargo.hidden=true
data:extend({down, up, vent, linked_belt, power, cargo, legacy_cargo, fluid})

-- Retain the previous entity types until configuration migration has replaced
-- them; changing a prototype's type in place makes Factorio delete saved ramps.
for _, kind in ipairs({"up", "down"}) do
  local legacy=table.deepcopy(data.raw["simple-entity"]["huge-rock"])
  legacy.type="simple-entity-with-owner"
  legacy.name="deep-caves-entrance-"..kind
  legacy.hidden=true
  legacy.minable=nil
  legacy.autoplace=nil
  legacy.pictures=nil
  legacy.picture={filename="__core__/graphics/empty.png",width=1,height=1}
  legacy.collision_mask={layers={}}
  data:extend({legacy})
end

-- Nauvis becomes a barren mixture of cracked ash, dry soil and dusty sand.
local wastes={}
for _,kind in ipairs({"ash","earth","dust"}) do
  local source=kind=="ash" and "nuclear-ground" or kind=="earth" and "dry-dirt" or "sand-3"
  local tile=table.deepcopy(data.raw.tile[source])
  tile.name="deep-caves-waste-"..kind
  tile.localised_name={"tile-name.deep-caves-waste-"..kind}
  tile.autoplace=nil
  tile.minable=nil
  tile.walking_speed_modifier=1
  tile.tint=kind=="ash" and {r=.67,g=.66,b=.64,a=1} or kind=="earth" and {r=.72,g=.69,b=.64,a=1} or {r=.72,g=.68,b=.58,a=1}
  tile.map_color=kind=="ash" and {r=.29,g=.29,b=.28} or kind=="earth" and {r=.32,g=.26,b=.19} or {r=.43,g=.37,b=.25}
  wastes[#wastes+1]=tile
end
data:extend(wastes)

data:extend({{type="animation",name="deep-caves-entrance-rain",
 filename="__deep-caves__/graphics/entrance-rain.png",width=256,height=256,
 frame_count=32,line_length=8,animation_speed=.8,draw_as_glow=true}})

-- Regular opaque water artwork, with shallow-water movement and collision.
-- Characters use the player layer; structures collide with these layers.
local shallow=table.deepcopy(data.raw.tile["water"])
local wading=data.raw.tile["water-shallow"]
shallow.walking_speed_modifier=wading.walking_speed_modifier
shallow.walking_sound=table.deepcopy(wading.walking_sound)
shallow.driving_sound=table.deepcopy(wading.driving_sound)
shallow.particle_tints=table.deepcopy(wading.particle_tints)
shallow.transition_merges_with_tile="water"
-- Keep the normal full-opacity water effect, with a cooler blue secondary.
shallow.effect_color_secondary={36,96,118}
shallow.name="deep-caves-shallow-water"
shallow.localised_name={"tile-name.deep-caves-shallow-water"}
shallow.autoplace=nil
shallow.collision_mask={layers={water_tile=true,resource=true,floor=true,elevated_rail=true}}
data:extend({shallow})
-- Include the custom water in existing land/water shore transitions, including
-- cave floor clones whose transition lists were copied before this tile existed.
for _,tile in pairs(data.raw.tile) do
  for _,transition in ipairs(tile.transitions or {}) do
    local water_edge,already=false,false
    for _,name in ipairs(transition.to_tiles or {}) do
      if name=="water" then water_edge=true end
      if name==shallow.name then already=true end
    end
    if water_edge and not already then transition.to_tiles[#transition.to_tiles+1]=shallow.name end
  end
end

-- User-supplied water-drop ambience.
data:extend({
 {type="sound",name="deep-caves-drip",filename="__deep-caves__/sound/water-drops.wav",volume=1.0}
})
