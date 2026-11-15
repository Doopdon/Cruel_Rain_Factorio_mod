local WALL="biter-caution-pathing-wall"
local CELL=3
local function state()
  storage.biter_caution=storage.biter_caution or {walls={},expiry={},count=0,enabled=true,debug=false}
  return storage.biter_caution
end
local function destroy(entry)
  if entry.entity and entry.entity.valid then entry.entity.destroy() end
  if entry.marker and entry.marker.valid then entry.marker.destroy() end
end
local function mark(entry)
  if entry.marker and entry.marker.valid then entry.marker.destroy() end
  entry.marker=nil
  if not state().debug or not entry.entity.valid then return end
  local p=entry.entity.position
  entry.marker=rendering.draw_rectangle{color={r=1,g=.4,b=.05,a=.9},filled=false,width=2,
    left_top={x=p.x-1.5,y=p.y-1.5},right_bottom={x=p.x+1.5,y=p.y+1.5},
    surface=entry.entity.surface,draw_on_ground=true}
end
local function near_nest(surface,position)
  local radius=settings.global["biter-caution-nest-radius"].value
  if radius<=0 then return false end
  local nests=surface.find_entities_filtered{position=position,radius=radius,type="unit-spawner",force="enemy",limit=1}
  return #nests>0
end
local function clear()
  local s=state()
  for _,entry in pairs(s.walls) do destroy(entry) end
  s.walls={};s.expiry={};s.count=0
end
local function on_death(event)
  local unit=event.entity
  if not (unit and unit.valid and unit.type=="unit" and unit.force.name=="enemy") then return end
  local s=state();if not s.enabled then return end
  local x,y=math.floor(unit.position.x/CELL),math.floor(unit.position.y/CELL)
  local key=unit.surface.index..":"..x..":"..y
  local entry=s.walls[key]
  if entry and not entry.entity.valid then destroy(entry);s.walls[key]=nil;s.count=s.count-1;entry=nil end
  -- Deaths near enemy spawners represent nest defense, where biters should
  -- remain aggressive instead of learning to avoid the combat area.
  if near_nest(unit.surface,unit.position) then
    if entry then destroy(entry);s.walls[key]=nil;s.count=s.count-1 end
    return
  end
  if not entry then
    if s.count>=settings.global["biter-caution-limit"].value then return end
    local entity=unit.surface.create_entity{name=WALL,position={x=x*CELL+1.5,y=y*CELL+1.5},force=unit.force}
    if not entity then return end
    entity.destructible=false
    entry={entity=entity};s.walls[key]=entry;s.count=s.count+1;mark(entry)
  end
  -- Expiration is bucketed to seconds. Repeated deaths refresh one cell,
  -- rather than creating one helper per corpse or scanning the whole map.
  local expires=(math.floor(game.tick/60)+1+settings.global["biter-caution-duration"].value)*60
  entry.expires=expires
  local bucket=s.expiry[expires] or {};s.expiry[expires]=bucket;bucket[key]=true
end
script.on_init(function() state() end)
local function configuration_changed(event)
  local s=state()
  local change=event.mod_changes and event.mod_changes["biter-caution"]
  if change and change.old_version=="0.1.0" then
    local duration=settings.global["biter-caution-duration"].value
    if duration==60 then
      settings.global["biter-caution-duration"]={value=600}
      duration=600
    end
    if duration==600 then
      -- Upgrade existing default-duration danger cells as well as new deaths.
      local expires=(math.floor(game.tick/60)+601)*60
      s.expiry={};s.expiry[expires]={}
      for key,entry in pairs(s.walls) do entry.expires=expires;s.expiry[expires][key]=true end
    end
  end
end
script.on_configuration_changed(configuration_changed)
script.on_event(defines.events.on_entity_died,on_death,{{filter="type",type="unit"}})
script.on_nth_tick(60,function(event)
  local s=state();local bucket=s.expiry[event.tick]
  if not bucket then return end
  for key in pairs(bucket) do
    local entry=s.walls[key]
    if entry and entry.expires<=event.tick then destroy(entry);s.walls[key]=nil;s.count=s.count-1 end
  end
  s.expiry[event.tick]=nil
end)
local function command_handler(command)
  local player=command.player_index and game.get_player(command.player_index)
  local function reply(message) if player then player.print(message) else game.print(message) end end
  local action=(command.parameter or "status"):match("^%s*(.-)%s*$"):lower()
  local s=state()
  if action=="status" or action=="" then
    reply("Biter Caution: "..(s.enabled and "ON" or "OFF").." | active 3x3 danger cells: "..s.count
      .." | lifetime: "..settings.global["biter-caution-duration"].value.." seconds (refreshed by deaths) | nest aggression radius: "..settings.global["biter-caution-nest-radius"].value.." tiles.")
    return
  end
  if player and not player.admin then reply("Only an admin can change Biter Caution.");return end
  if action=="show" or action=="hide" then
    s.debug=action=="show";for _,entry in pairs(s.walls) do mark(entry) end
    reply("Biter Caution outlines "..(s.debug and "shown." or "hidden."))
  elseif action=="clear" then clear();reply("Biter Caution danger cells cleared.")
  elseif action=="off" then s.enabled=false;clear();reply("Biter Caution OFF; existing danger cells removed.")
  elseif action=="on" then s.enabled=true;reply("Biter Caution ON.")
  else reply("Usage: /biter-caution status | show | hide | clear | off | on") end
end
commands.add_command("biter-caution","Biter caution: status, show, hide, clear, off, on.",command_handler)
