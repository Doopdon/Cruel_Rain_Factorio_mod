-- Exercise the production placement handler with player inventory stand-ins.
local silos=require("scripts.silos")
local passed,failed=0,0
local function check(ok,message) assert(ok,message) end
local function test(name,fn)
 local ok,err=pcall(fn)
 if ok then passed=passed+1;print("PASS "..name)
 else failed=failed+1;print("FAIL "..name..": "..tostring(err)) end
end
local function fixture(surface_name,kind,quality)
 settings={startup={["deep-caves-surface-silos-only"]={value=true}}}
 local drops,inserted={},{ }
 local surface={name=surface_name,spill_item_stack=function(spec) drops[#drops+1]=spec.stack end}
 local entity={valid=true,type=kind or "rocket-silo",ghost_type="rocket-silo",surface=surface,
  position={x=0,y=0},force="player",quality={name=quality or "normal"},
  prototype={items_to_place_this={{name="rocket-silo",count=1}}}}
 entity.destroy=function() entity.valid=false;return true end
 local player={insert=function(stack) inserted[#inserted+1]={name=stack.name,count=stack.count,quality=stack.quality};return stack.count end,
  create_local_flying_text=function() end}
 game={get_player=function() return player end};defines={inventory={robot_cargo=1}}
 return entity,player,drops,inserted
end
test("above-ground silos and unrelated underground entities remain placeable",function()
 for _,name in ipairs{"nauvis","vulcanus","other-outdoor-map"} do
  local entity,_,drops,inserted=fixture(name);silos.built{entity=entity,player_index=1}
  check(entity.valid and #drops==0 and #inserted==0,"rejected outdoor silo")
 end
 local entity=fixture("deep-caves-level-1","assembling-machine");silos.built{entity=entity,player_index=1}
 check(entity.valid,"rejected another machine")
end)
test("all five cave levels reject silos and return their consumed quality items",function()
 for depth=1,5 do
  local entity,_,drops,inserted=fixture("deep-caves-level-"..depth,nil,"epic")
  local items={valid=true,{valid_for_read=true,name="rocket-silo",count=1,quality={name="epic"}}}
  silos.built{entity=entity,player_index=1,consumed_items=items}
  check(not entity.valid and #drops==0 and #inserted==1 and inserted[1].count==1 and inserted[1].quality=="epic","lost or duplicated item")
 end
end)
test("full player inventory spills exactly the remaining refund",function()
 local entity,player,drops=fixture("deep-caves-level-1")
 player.insert=function() return 1 end
 silos.built{entity=entity,player_index=1,consumed_items={valid=true,
  {valid_for_read=true,name="rocket-silo",count=3,quality={name="normal"}}}}
 check(not entity.valid and #drops==1 and drops[1].count==2,"overflow refund was lost or duplicated")
end)
test("robots refund only one consumed silo even when their source stack contains more",function()
 local entity,_,drops=fixture("deep-caves-level-2",nil,"rare")
 local returned
 local robot={valid=true,get_inventory=function() return {insert=function(stack) returned=stack.count;return stack.count end} end}
 silos.built{entity=entity,robot=robot,stack={valid_for_read=true,name="rocket-silo",count=20}}
 check(not entity.valid and returned==1 and #drops==0,"refunded the robot's entire stack")
end)
test("underground silo ghosts are removed without creating free refund items",function()
 local entity,_,drops,inserted=fixture("deep-caves-level-5","entity-ghost")
 silos.built{entity=entity,player_index=1}
 check(not entity.valid and #drops==0 and #inserted==0,"ghost created free items")
end)
test("script builds, revived ghosts and clones spill one quality silo",function()
 for _,field in ipairs{"entity","created_entity","destination"} do
  local entity,_,drops=fixture("deep-caves-level-3",nil,"legendary")
  silos.built{[field]=entity}
  check(not entity.valid and #drops==1 and drops[1].count==1 and drops[1].quality=="legendary","script placement bypassed the rule")
  silos.built{[field]=entity};check(#drops==1,"repeated callback duplicated refund")
 end
end)
test("disabling the surface-only setting permits underground silos and ghosts",function()
 for _,kind in ipairs{"rocket-silo","entity-ghost"} do
  local entity,_,drops,inserted=fixture("deep-caves-level-5",kind)
  settings.startup["deep-caves-surface-silos-only"].value=false
  silos.built{entity=entity,player_index=1}
  check(entity.valid and #drops==0 and #inserted==0,"disabled restriction still rejected placement")
 end
end)
print(string.format("RESULT: %d passed, %d failed",passed,failed))
if failed>0 then os.exit(1) end
