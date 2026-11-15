-- Exercise the actual GUI handlers with small player/GUI API stand-ins.
-- Native fluid conservation and plumbing are tested separately in Factorio.
local passed,failed=0,0
local function check(ok,message) assert(ok,message) end
local function test(name,fn)
  local ok,err=pcall(fn)
  if ok then passed=passed+1;print("PASS "..name)
  else failed=failed+1;print("FAIL "..name..": "..tostring(err)) end
end
local function element(spec,parent)
  local e={valid=true,name=spec.name,parent=parent,anchor=spec.anchor,enabled=spec.enabled}
  e.add=function(child)
    local result=element(child,e);e[child.name]=result;return result
  end
  e.destroy=function() e.valid=false;if parent then parent[e.name]=nil end end
  return e
end
local function fixture()
  storage={deep_caves={portals={}}}
  defines={relative_gui_type={linked_container_gui=1,pipe_gui=2},relative_gui_position={right=1}}
  local relative={}
  relative.add=function(spec) local e=element(spec,relative);relative[spec.name]=e;return e end
  local player={index=1,gui={relative=relative}}
  game={players={player},get_player=function(index) if index==1 then return player end end}
  local record={entity={valid=true,unit_number=17},inventory_entity={valid=true},fluid_entity={valid=true}}
  storage.deep_caves.portals[17]=record
  package.loaded['scripts.fluids']=nil;package.loaded['scripts.ramp_gui']=nil;package.loaded['scripts.cargo']=nil
  local gui=require('scripts.ramp_gui')
  local paired=0;gui.set_pair_handler(function() paired=paired+1 end)
  return gui,player,record,function() return paired end
end
test("cargo and fluid buttons preserve the original cargo entity and select the correct window",function()
  local gui,player,record,paired=fixture()
  player.opened=record.inventory_entity;gui.show(player,record,'cargo')
  local panel=player.gui.relative.deep_caves_ramp_tabs
  check(panel.anchor.gui==defines.relative_gui_type.linked_container_gui,'wrong cargo anchor')
  check(panel['deep-caves-open-cargo'].enabled==false,'active cargo button not disabled')
  gui.click{player_index=1,element=panel['deep-caves-open-fluids']}
  panel=player.gui.relative.deep_caves_ramp_tabs
  check(player.opened==record.fluid_entity and paired()==1,'fluid tab did not open the buffer and prepare its mate')
  check(panel.anchor.gui==defines.relative_gui_type.pipe_gui,'wrong fluid anchor')
  gui.click{player_index=1,element=panel['deep-caves-open-cargo']}
  check(player.opened==record.inventory_entity and paired()==1,'returning to cargo changed the inventory')
end)
test("a delayed close event from the prior window preserves the newly opened tab",function()
  local gui,player,record=fixture()
  player.opened=record.inventory_entity;gui.show(player,record,'cargo')
  local panel=player.gui.relative.deep_caves_ramp_tabs
  gui.click{player_index=1,element=panel['deep-caves-open-fluids']}
  gui.closed{player_index=1}
  check(player.gui.relative.deep_caves_ramp_tabs.valid and storage.deep_caves.ramp_gui[1].mode=='fluids','window switch destroyed its own tab')
end)
test("closing or opening another entity clears the ramp controls",function()
  local gui,player,record=fixture()
  player.opened=record.inventory_entity;gui.show(player,record,'cargo')
  player.opened=nil;gui.closed{player_index=1}
  check(player.gui.relative.deep_caves_ramp_tabs==nil and storage.deep_caves.ramp_gui[1]==nil,'closed controls were retained')
  player.opened=record.inventory_entity;gui.show(player,record,'cargo')
  player.opened={valid=true};gui.closed{player_index=1}
  check(player.gui.relative.deep_caves_ramp_tabs==nil,'another entity retained ramp controls')
end)
test("stale controls cannot open a removed ramp or replace another entity window",function()
  local gui,player,record,paired=fixture()
  player.opened=record.inventory_entity;gui.show(player,record,'cargo')
  local button=player.gui.relative.deep_caves_ramp_tabs['deep-caves-open-fluids']
  local other={valid=true};player.opened=other
  gui.click{player_index=1,element=button}
  check(player.opened==other and paired()==0,'stale controls hijacked another window')
  player.opened=record.inventory_entity;gui.show(player,record,'cargo')
  button=player.gui.relative.deep_caves_ramp_tabs['deep-caves-open-fluids'];record.entity.valid=false
  gui.click{player_index=1,element=button}
  check(player.opened==record.inventory_entity and paired()==0,'removed ramp was opened')
end)
test("configuration cleanup removes only this mod's ramp panel",function()
  local gui,player,record=fixture()
  local other=element{name='another_mod_panel'};player.gui.relative.another_mod_panel=other
  player.opened=record.inventory_entity;gui.show(player,record,'cargo');gui.reset()
  check(player.gui.relative.deep_caves_ramp_tabs==nil and other.valid,'cleanup removed an unrelated panel')
end)
print(string.format('RESULT: %d passed, %d failed',passed,failed))
if failed>0 then os.exit(1) end
