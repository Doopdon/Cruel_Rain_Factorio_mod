local checks=require("scripts.cave_walls.checks")
local profiler=require("scripts.cave_walls.profiler")
local guns={}
local TURRETS={"gun-turret","laser-turret","flamethrower-turret"}
local walls=require("scripts.cave_walls.walls")
local function state()
  storage.cave_wall_paused_guns=storage.cave_wall_paused_guns or {}
  return storage.cave_wall_paused_guns
end
local function range(turret)
  return turret.prototype.attack_parameters.range*turret.quality.range_multiplier
end
local function in_range(turret,target)
  local dx,dy=target.position.x-turret.position.x,target.position.y-turret.position.y
  local params=turret.prototype.attack_parameters
  local distance=dx*dx+dy*dy
  if distance>range(turret)^2 or distance<(params.min_range or 0)^2 then return false end
  if params.turn_range and params.turn_range<1 then
    local angle=math.atan2(dx,-dy)/(2*math.pi)
    local facing=turret.direction/16
    local delta=(angle-facing+.5)%1-.5
    if math.abs(delta)>params.turn_range/2 then return false end
  end
  return true
end
local function clear(turret,target)
  return target and target.valid and target.surface==turret.surface
    and not walls.crosses(turret.surface,turret.position,target.position)
end
local function alternative(turret)
  -- Only hostile military targets are candidates, never neutral wall helpers.
  local hostile={}
  for _,force in pairs(game.forces) do
    if force~=turret.force and not turret.force.get_friend(force)
      and not turret.force.get_cease_fire(force) then hostile[#hostile+1]=force end
  end
  if #hostile==0 then return end
  local priorities={}
  for index,prototype in ipairs(turret.priority_targets) do priorities[prototype.name]=index end
  local best,distance,best_rank,blocked
  for _,target in ipairs(turret.surface.find_entities_filtered{
    position=turret.position,radius=range(turret),force=hostile,is_military_target=true}) do
    local rank=priorities[target.name]
    if (rank or not turret.ignore_unprioritised_targets) and target.destructible
      and target.health and target.health>0 and in_range(turret,target) then
      if not clear(turret,target) then blocked=true else
        local dx,dy=target.position.x-turret.position.x,target.position.y-turret.position.y
        local d=dx*dx+dy*dy
        rank=rank or math.huge
        if not best_rank or rank<best_rank or (rank==best_rank and d<distance) then
          best=target;distance=d;best_rank=rank
        end
      end
    end
  end
  return best,blocked
end
function guns.track(turret)
  if not (turret and turret.valid and turret.unit_number) then return end
  if turret.name~="gun-turret" and turret.name~="laser-turret" and turret.name~="flamethrower-turret" then return end
  storage.cave_wall_turrets=storage.cave_wall_turrets or {}
  storage.cave_wall_turrets[turret.unit_number]=turret
end
function guns.scan(surface,area)
  if not checks.enabled() then return end
  for _,turret in ipairs(surface.find_entities_filtered{name=TURRETS,area=area}) do guns.track(turret) end
end
function guns.rebuild()
  if not checks.enabled() then return end
  storage.cave_wall_turrets={}
  for _,surface in pairs(game.surfaces) do guns.scan(surface) end
end
function guns.suspend()
  -- Only restore turrets this mod paused, preserving intentionally inactive ones.
  local paused=state()
  for id,turret in pairs(paused) do
    if turret.valid then turret.disabled_by_script=false end
    paused[id]=nil
  end
end
function guns.tick()
  if not checks.enabled() then return end
  local paused=state()
  -- Restore only turrets this module paused when their surface loses its walls.
  for id,turret in pairs(paused) do
    if not turret.valid then paused[id]=nil
    elseif not walls.has_walls(turret.surface) then turret.disabled_by_script=false;paused[id]=nil end
  end
  if not storage.cave_wall_turrets then guns.rebuild() end
  for id,turret in pairs(storage.cave_wall_turrets) do
    if not turret.valid then storage.cave_wall_turrets[id]=nil
    elseif walls.has_walls(turret.surface) then
        local owned=paused[turret.unit_number]
        if turret.active or owned then
          local target=turret.shooting_target
          if owned or not target or not clear(turret,target) then
            local next_target=clear(turret,target) and target
            local blocked=target~=nil
            -- A paused turret with no clear target only searches six times per second.
            if not next_target and (not owned or game.tick%10==turret.unit_number%10) then
              next_target,blocked=alternative(turret)
            end
            if next_target then
              turret.shooting_target=next_target
              if owned then turret.disabled_by_script=false;paused[turret.unit_number]=nil end
            elseif not owned and blocked then
              turret.disabled_by_script=true;paused[turret.unit_number]=turret
            end
          end
        end
    end
  end
end
local measured_scan=guns.scan
function guns.scan(...) return profiler.measure("Turret discovery",measured_scan,...) end
local measured_tick=guns.tick
function guns.tick(...) return profiler.measure("Turret target and line of sight",measured_tick,...) end
return guns
