local wall = table.deepcopy(data.raw.tile["out-of-map"])
wall.name = "cave-wall"
wall.localised_name = {"tile-name.cave-wall"}
wall.localised_description = {"tile-description.cave-wall"}
wall.order = "z[other]-b[cave-wall]"
wall.autoplace = nil
wall.minable = nil
wall.map_color = {r=0.025,g=0.025,b=0.025}
local icon = "__deep-caves__/graphics/cave_walls/cave-wall-brush.png"
data:extend({wall,
  {
    type="selection-tool",name="cave-wall-brush",icon=icon,icon_size=64,
    flags={"not-stackable","spawnable","only-in-cursor"},stack_size=1,
    subgroup="tool",order="z[cave-wall-brush]",
    select={border_color={r=.65,g=.45,b=.25},mode={"any-tile"},cursor_box_type="copy"},
    alt_select={border_color={r=.2,g=1,b=.4},mode={"any-tile"},cursor_box_type="copy"},
    reverse_select={border_color={r=.2,g=1,b=.4},mode={"any-tile"},cursor_box_type="copy"}
  },
  {
    type="shortcut",name="cave-wall-brush",action="spawn-item",item_to_spawn="cave-wall-brush",
    associated_control_input="cave-wall-brush",order="z[cave-wall-brush]",style="default",
    icon=icon,icon_size=64,small_icon=icon,small_icon_size=64
  },
  {type="custom-input",name="cave-wall-brush",key_sequence="ALT + W",action="spawn-item",item_to_spawn="cave-wall-brush"}
})

local blocker=table.deepcopy(data.raw["simple-entity"]["huge-rock"])
blocker.type="simple-entity-with-owner"
blocker.name="cave-wall-collision"
blocker.hidden=true
blocker.flags={"placeable-off-grid","not-on-map","not-blueprintable","not-deconstructable"}
blocker.minable=nil
blocker.autoplace=nil
blocker.loot=nil
blocker.max_health=1000000
blocker.collision_mask={layers={player=true}}
blocker.collision_box={{-.5,-.5},{.5,.5}}
blocker.selection_box={{0,0},{0,0}}
blocker.selectable_in_game=false
blocker.pictures=nil
blocker.picture={filename="__core__/graphics/empty.png",width=1,height=1}
blocker.water_reflection=nil

local visual=table.deepcopy(data.raw["simple-entity"]["rock-big"] or data.raw["simple-entity"]["huge-rock"])
visual.type="simple-entity-with-owner"
visual.name="cave-wall-visual"
visual.localised_name={"tile-name.cave-wall"}
visual.localised_description={"tile-description.cave-wall"}
visual.hidden=true
visual.minable=nil
visual.autoplace=nil
visual.loot=nil
visual.max_health=1000000
visual.flags={"placeable-neutral","placeable-off-grid","not-on-map","not-blueprintable","not-deconstructable"}
visual.collision_mask={layers={}}
visual.collision_box={{0,0},{0,0}}
visual.selection_box={{0,0},{0,0}}
visual.selectable_in_game=false
visual.dying_explosion=nil
visual.water_reflection=nil

-- Keep the natural base-game rock artwork, but shrink every sprite layer so
-- exposed cave edges read as low stone protrusions rather than full boulders.
local function shrink_layers(layer)
  if type(layer)~="table" then return end
  if layer.filename or layer.filenames then
    layer.scale=(layer.scale or 1)*0.42
    layer.hr_version=nil
  end
  for _,value in pairs(layer) do
    if type(value)=="table" then shrink_layers(value) end
  end
end
shrink_layers(visual.pictures)
shrink_layers(visual.picture)

data:extend({blocker,visual})
