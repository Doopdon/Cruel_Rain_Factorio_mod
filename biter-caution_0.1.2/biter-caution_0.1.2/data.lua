data:extend({{type="collision-layer",name="biter-caution-only"}})
local wall=table.deepcopy(data.raw["simple-entity"]["huge-rock"])
wall.type="simple-entity-with-owner";wall.name="biter-caution-pathing-wall"
wall.hidden=true;wall.is_military_target=false
wall.flags={"placeable-off-grid","not-on-map","not-blueprintable","not-deconstructable"}
wall.minable=nil;wall.autoplace=nil;wall.loot=nil;wall.max_health=1
wall.collision_mask={layers={["biter-caution-only"]=true}}
wall.collision_box={{-1.5,-1.5},{1.5,1.5}}
wall.selection_box={{0,0},{0,0}};wall.selectable_in_game=false
wall.pictures=nil;wall.picture={filename="__core__/graphics/empty.png",width=1,height=1}
wall.water_reflection=nil
data:extend({wall})
