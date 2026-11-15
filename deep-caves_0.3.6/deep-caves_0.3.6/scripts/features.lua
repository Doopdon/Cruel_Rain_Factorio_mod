local generation=require("scripts.generation")
local walls=require("scripts.walls")
local surfaces=require("scripts.surfaces")
local features={}
local hash=generation.hash01
local function inside(area,p)
  return p.x>=area.left_top.x and p.x<area.right_bottom.x and p.y>=area.left_top.y and p.y<area.right_bottom.y
end
local function near_ramp(surface,p,radius)
  return surface.count_entities_filtered{position=p,radius=radius,name={"deep-caves-ramp-down","deep-caves-ramp-up","deep-caves-vent"}}>0
end
local function clear_ground(surface,p)
  return generation.is_cave_ground(surface.get_tile(p).name)
end

local RESOURCE_VERSION=5

-- Scatter resources directly across the current cave-floor mesh.  This does
-- not depend on the old chamber-site grid, so deposits follow all three
-- configurable tunnel networks and remain deterministic for a world seed.
function features.populate_resources(surface,area,depth,seed,force)
  local state=storage.deep_caves
  state.resource_chunks=state.resource_chunks or {}
  local marks=state.resource_chunks[surface.index] or {}
  state.resource_chunks[surface.index]=marks
  local cx,cy=math.floor(area.left_top.x/32),math.floor(area.left_top.y/32)
  local key=cx..":"..cy
  if not force and marks[key]==RESOURCE_VERSION then return 0 end
  local roll=hash(cx,cy,seed+30001)
  local patch_count=roll<.55 and 0 or (roll<.93 and 1 or 2)
  if patch_count==0 then marks[key]=RESOURCE_VERSION;return 0 end

  -- One snapshot instead of thousands of engine entity queries per chunk.
  local border={{area.left_top.x-8,area.left_top.y-8},{area.right_bottom.x+8,area.right_bottom.y+8}}
  local ramps=surface.find_entities_filtered{area=border,name={"deep-caves-ramp-up","deep-caves-ramp-down","deep-caves-vent"}}
  local players=surface.find_entities_filtered{area=border,force="player"}
  local nests=surface.find_entities_filtered{area=border,force="enemy",type={"unit-spawner","turret"}}
  local function nearby(list,p,radius)
    for _,e in ipairs(list) do
      local dx,dy=e.position.x-p.x,e.position.y-p.y
      if dx*dx+dy*dy<radius*radius then return true end
    end
    return false
  end
  local function protected(p)
    return nearby(ramps,p,7) or nearby(players,p,3.5) or nearby(nests,p,5)
  end
  local suffix=tostring(math.min(depth,12))
  local floor=surface.find_tiles_filtered{area=area,name={"deep-caves-stone-"..suffix,
    "deep-caves-earth-"..suffix,"deep-caves-sand-"..suffix,"deep-caves-shallow-water"}}
  local function find_site(target,ore)
    local candidates={}
    local wet=false
    for _,tile in ipairs(floor) do
      local p={x=tile.position.x+.5,y=tile.position.y+.5}
      if tile.name=="deep-caves-shallow-water" then wet=true end
      if not protected(p) then
        candidates[#candidates+1]={p=p,wet=tile.name=="deep-caves-shallow-water",
          d=(p.x-target.x)^2+(p.y-target.y)^2}
      end
    end
    table.sort(candidates,function(a,b)
      return a.d<b.d or (a.d==b.d and (a.p.x<b.p.x or (a.p.x==b.p.x and a.p.y<b.p.y)))
    end)
    for _,c in ipairs(candidates) do
      if not c.wet and surface.can_place_entity{name=ore,position=c.p,force="neutral"} then return c.p end
    end
    -- Oil needs a full footprint, and wet-only tunnels cannot hold solid ore.
    -- Give these deposits a small dry pad beside their existing walkable route.
    -- Pads stay inside this chunk; this never force-generates neighboring caves.
    if #floor==0 or (ore~="crude-oil" and not wet) then return nil end
    -- Clamping an edge tunnel's center inward can move the entire footprint
    -- into a ramp exclusion. Search the interior for a side pad instead, then
    -- connect it to the nearest actual floor tile. Only one pad is normally cut.
    local pads={}
    for x=area.left_top.x+3,area.right_bottom.x-4 do
      for y=area.left_top.y+3,area.right_bottom.y-4 do
        local p={x=x+.5,y=y+.5}
        if not protected(p) then pads[#pads+1]={p=p,d=(p.x-target.x)^2+(p.y-target.y)^2} end
      end
    end
    table.sort(pads,function(a,b)
      return a.d<b.d or (a.d==b.d and (a.p.x<b.p.x or (a.p.x==b.p.x and a.p.y<b.p.y)))
    end)
    for _,c in ipairs(pads) do
      local p=c.p
      if surface.count_entities_filtered{position=p,radius=3,type="resource"}==0 then
        local anchor,best
        for _,tile in ipairs(floor) do
          local a={x=tile.position.x+.5,y=tile.position.y+.5}
          local d=(a.x-p.x)^2+(a.y-p.y)^2
          if not best or d<best or (d==best and (a.x<anchor.x or (a.x==anchor.x and a.y<anchor.y))) then
            anchor,best=a,d
          end
        end
        generation.carve_circle(surface,p,2.5)
        generation.connect_positions(surface,p,anchor,depth,seed,1.35,true)
        if surface.can_place_entity{name=ore,position=p,force="neutral"} then return p end
      end
    end
  end

  state.resource_progress=state.resource_progress or {}
  local chunks=state.resource_progress[surface.index] or {};state.resource_progress[surface.index]=chunks
  local progress=chunks[key]
  if not progress or progress.version~=RESOURCE_VERSION or force then
    progress={version=RESOURCE_VERSION,done={}};chunks[key]=progress
  end
  local made,complete=0,true
  for i=1,patch_count do
    if not progress.done[i] then
      local pick=hash(cx,cy,seed+30031+i*101)
      local ore
      if depth==1 then
        ore=pick<.22 and "iron-ore" or pick<.42 and "copper-ore" or pick<.62 and "stone" or "coal"
      elseif depth==2 then
        ore=pick<.29 and "iron-ore" or pick<.55 and "copper-ore" or pick<.76 and "stone" or "coal"
      elseif depth==3 then
        ore=pick<.27 and "iron-ore" or pick<.51 and "copper-ore" or pick<.69 and "stone"
          or pick<.88 and "coal" or "crude-oil"
      else
        ore=pick<.25 and "iron-ore" or pick<.47 and "copper-ore" or pick<.64 and "stone"
          or pick<.80 and "coal" or pick<.91 and "crude-oil" or "uranium-ore"
      end
      local target={x=area.left_top.x+4+hash(cx*17+i,cy,seed+30011)*24,
        y=area.left_top.y+4+hash(cx,cy*19+i,seed+30013)*24}
      local center=find_site(target,ore)
      local patch_made=0
      if center then
        local radius=2.6+hash(cx,cy,seed+30047+i*103)*2.8+math.min(depth,5)*.12
        local base=700+depth*330
        if ore=="crude-oil" then
          local wells=hash(cx+i*31,cy-i*17,seed+30201)<.72 and 1 or 2
          for w=1,wells do
            local angle=hash(cx+i*13+w,cy,seed+30211)*math.pi*2
            local dist=w==1 and 0 or 2.4+hash(cx,cy+i*19+w,seed+30213)*2.2
            local p={x=center.x+math.cos(angle)*dist,y=center.y+math.sin(angle)*dist}
            if inside(area,p) and clear_ground(surface,p) and not protected(p)
              and surface.can_place_entity{name=ore,position=p,force="neutral"} then
              local amount=math.floor((90000+depth*18000)*(0.8+hash(cx+w,cy-w,seed+30217)*.5))
              if surface.create_entity{name=ore,position=p,amount=amount,force="neutral"} then patch_made=patch_made+1 end
            end
          end
        else
          for x=math.max(area.left_top.x,math.floor(center.x-radius-1)),math.min(area.right_bottom.x-1,math.ceil(center.x+radius+1)) do
            for y=math.max(area.left_top.y,math.floor(center.y-radius-1)),math.min(area.right_bottom.y-1,math.ceil(center.y+radius+1)) do
              local p={x=x+.5,y=y+.5}
              local dist=math.sqrt((p.x-center.x)^2+(p.y-center.y)^2)
              local edge=radius*(.78+generation.smooth_noise(p.x/3.5,p.y/3.5,seed+30101+i*107)*.42)
              if dist<edge and clear_ground(surface,p) and not nearby(ramps,p,5)
                and not nearby(players,p,1.5) and not nearby(nests,p,4)
                and surface.can_place_entity{name=ore,position=p,force="neutral"} then
                local amount=math.floor(base*(.55+math.max(0,1-dist/math.max(edge,.01))*.9)
                  *(.8+hash(x,y,seed+30133+i*109)*.4))
                if ore=="uranium-ore" then amount=math.floor(amount*.7) end
                if surface.create_entity{name=ore,position=p,amount=amount,force="neutral"} then patch_made=patch_made+1 end
              end
            end
          end
        end
      end
      if patch_made>0 then progress.done[i]=true else complete=false end
      made=made+patch_made
    end
  end
  -- Preserve successful patches when a second patch fails and is retried.
  if complete then marks[key]=RESOURCE_VERSION;chunks[key]=nil end
  return made
end

function features.populate(surface,area,depth,seed)
  features.populate_resources(surface,area,depth,seed)
  features.populate_enemies(surface,area,depth,seed)
end

-- Establish the safe center before the first cave chunks generate. Discovering
-- it from an up-ramp allowed nests to appear before that ramp had been created.
local LEVEL1_SAFE_RADIUS=64
local function level1_start(surface)
  if not (surface and surface.valid and surface.name=="deep-caves-level-1") then return nil end
  local nauvis=game.surfaces["nauvis"]
  if not nauvis then return nil end
  return storage.deep_caves.level1_start_position or game.forces.player.get_spawn_position(nauvis)
end
local function in_level1_safe_zone(surface,p,margin)
  local center=level1_start(surface)
  if not center then return false end
  local r=LEVEL1_SAFE_RADIUS+(margin or 0)
  local dx,dy=p.x-center.x,p.y-center.y
  return dx*dx+dy*dy<r*r
end

function features.in_level1_nest_safe_zone(surface,p)
  return in_level1_safe_zone(surface,p,0)
end

-- The Level 1 starter circle bans nests only.  Units and worms are deliberately
-- untouched: enemies can wander in, and combat near the entrance remains possible.
function features.enforce_level1_safe_zone()
  local surface=game.surfaces["deep-caves-level-1"]
  if not surface then return 0 end
  local center=level1_start(surface)
  if not center then return 0 end
  local removed=0
  for _,enemy in ipairs(surface.find_entities_filtered{
    position=center,radius=LEVEL1_SAFE_RADIUS,force="enemy",type="unit-spawner"}) do
    if enemy.valid then enemy.destroy();removed=removed+1 end
  end
  return removed
end

local STARTER_RESOURCE_VERSION=3
local STARTER_PATCHES={
  {name="iron-ore",   x= 9, y=-9},
  {name="copper-ore", x=-9, y=-9},
  {name="coal",       x= 9, y= 9},
  {name="stone",      x=-9, y= 9}
}

-- Four guaranteed starter deposits near world (0,0) on cave Level 1.
-- These are deliberately placed rather than discovered from natural cave
-- geometry: each site first overwrites a 5x5 square with ordinary cave floor,
-- then a compact 3x3 deposit is placed in the middle.  This guarantees the
-- starter ores are visible and mineable even if cave generation would have
-- put rock walls or a narrow crevasse through the location.
function features.ensure_level1_starter_resources()
  local state=storage.deep_caves
  if state.starter_resource_version==STARTER_RESOURCE_VERSION then return 0 end
  local surface=game.surfaces["deep-caves-level-1"]
  if not surface then return 0 end

  -- The four pads are all close to (0,0), but make sure those chunks exist.
  surface.request_to_generate_chunks({0,0},1)
  surface.force_generate_chunk_requests()

  local seed=surfaces.seed_for_depth(1)
  local floor_name="deep-caves-stone-1"
  local made=0
  local complete=true
  if state.starter_resource_progress_version~=STARTER_RESOURCE_VERSION then
    state.starter_resource_progress={};state.starter_resource_progress_version=STARTER_RESOURCE_VERSION
  end
  for _,patch in ipairs(STARTER_PATCHES) do
    if not state.starter_resource_progress[patch.name] then
      local c={x=patch.x+.5,y=patch.y+.5}
      local tiles={}
      for dx=-2,2 do
        for dy=-2,2 do
          tiles[#tiles+1]={name=floor_name,position={patch.x+dx,patch.y+dy}}
        end
      end

      local area={{patch.x-2,patch.y-2},{patch.x+3,patch.y+3}}
      -- Clear only natural clutter/resources. Never erase player-built machines.
      for _,entity in ipairs(surface.find_entities_filtered{area=area,type="resource"}) do
        if entity.name~=patch.name then entity.destroy() end
      end
      for _,entity in ipairs(surface.find_entities_filtered{area=area,name={"big-rock","huge-rock","big-sand-rock"}}) do entity.destroy() end
      walls.set_tiles(surface,tiles,true,false,true)
      local landing=level1_start(surface) or {x=0,y=0}
      generation.connect_positions(surface,landing,c,1,seed,1.35)

      -- Nine tiles at ~550 each gives roughly 5k resources per guaranteed patch.
      local placed=0
      for dx=-1,1 do
        for dy=-1,1 do
          local pos={x=patch.x+dx+.5,y=patch.y+dy+.5}
          if surface.count_entities_filtered{position=pos,radius=.1,name=patch.name,type="resource"}>0 then
            placed=placed+1
          elseif surface.can_place_entity{name=patch.name,position=pos,force="neutral"} then
            local amount=520+math.floor(hash(dx+patch.x,dy+patch.y,seed+47011)*70)
            if surface.create_entity{name=patch.name,position=pos,amount=amount,force="neutral"} then
              made=made+1;placed=placed+1
            end
          end
        end
      end
      if placed==9 then state.starter_resource_progress[patch.name]=true else complete=false end
    end
  end
  if complete then state.starter_resource_version=STARTER_RESOURCE_VERSION end
  return made
end

-- The density setting remains the base rate; risk rises radially from (0,0)
-- and with cave depth. Bounded scaling avoids unbounded growth far from spawn.
function features.enemy_spawn_chance(position,depth,density)
  if density<=0 then return 0 end
  local distance=math.sqrt(position.x*position.x+position.y*position.y)
  local distance_factor=1+math.min(3,distance/1024)
  local depth_factor=1+.5*(math.max(1,math.min(5,depth))-1)
  return math.min(1,density*distance_factor*depth_factor)
end

-- Nest sites use the existing tunnel network only as an anchor. Instead of
-- requiring a pre-existing 5x5 clear patch, each accepted site deliberately
-- cuts a compact side cavern and a short connecting spur into the rock.
function features.populate_enemies(surface,area,depth,seed,force)
  local state=storage.deep_caves
  state.enemy_chunks=state.enemy_chunks or {}
  local marks=state.enemy_chunks[surface.index] or {}
  state.enemy_chunks[surface.index]=marks
  local cx=math.floor(area.left_top.x/32)
  local cy=math.floor(area.left_top.y/32)
  local key=cx..":"..cy
  local density=settings.startup["deep-caves-enemy-density"].value
  -- A completion mark is written only after a successful nest or a losing roll.
  local mark="overlay3:"..density
  if not force and marks[key]==mark then return 0 end
  if density<=0 then marks[key]=mark;return 0 end

  -- Keep the existing completion marks so upgrades never refill cleared sites.
  -- The stronger rates apply to unprocessed chunks, including unexplored caves.
  local chance=features.enemy_spawn_chance({x=cx*32+16,y=cy*32+16},depth,density)
  if hash(cx,cy,seed+32003)>=chance then marks[key]=mark;return 0 end

  local floor_name=generation.ground_name
  local cavern_radius=4
  local spur_radius=1.35

  state.enemy_sites=state.enemy_sites or {}
  local occupied=state.enemy_sites[surface.index] or {}
  state.enemy_sites[surface.index]=occupied
  local existing=occupied[key]
  if existing and existing.valid then marks[key]=mark;return 0 end

  local function blocked(center)
    if depth==1 and in_level1_safe_zone(surface,center,0) then return true end
    if surface.count_entities_filtered{position=center,radius=6,
      name={"deep-caves-ramp-up","deep-caves-ramp-down","deep-caves-vent"}}>0 then return true end
    if surface.count_entities_filtered{position=center,radius=5,force="player"}>0 then return true end
    if surface.count_entities_filtered{position=center,radius=6,type="resource"}>0 then return true end
    return false
  end

  local function nearest_floor(center)
    local best,best_d
    -- This is only an access spur search.  The nest itself is an independent
    -- overlay and does not require the natural tunnel mesh to provide a pocket.
    for r=0,31 do
      for dx=-r,r do
        for _,dy in ipairs({-r,r}) do
          local p={x=math.floor(center.x)+dx+.5,y=math.floor(center.y)+dy+.5}
          if inside(area,p) and clear_ground(surface,p) then
            local d=dx*dx+dy*dy
            if not best_d or d<best_d then best,best_d=p,d end
          end
        end
      end
      for dy=-r+1,r-1 do
        for _,dx in ipairs({-r,r}) do
          local p={x=math.floor(center.x)+dx+.5,y=math.floor(center.y)+dy+.5}
          if inside(area,p) and clear_ground(surface,p) then
            local d=dx*dx+dy*dy
            if not best_d or d<best_d then best,best_d=p,d end
          end
        end
      end
      if best then return best end
    end
    return nil
  end

  local function carve_overlay(center,anchor)
    local tiles,seen={},{}
    local function add(x,y)
      if x<area.left_top.x or x>=area.right_bottom.x
        or y<area.left_top.y or y>=area.right_bottom.y then return end
      local k=x..":"..y
      if seen[k] then return end
      seen[k]=true
      tiles[#tiles+1]={name=floor_name(surface,x+.5,y+.5,depth,seed),position={x,y}}
    end

    local minx=math.floor(center.x-cavern_radius-1)
    local maxx=math.floor(center.x+cavern_radius+1)
    local miny=math.floor(center.y-cavern_radius-1)
    local maxy=math.floor(center.y+cavern_radius+1)
    for x=minx,maxx do
      for y=miny,maxy do
        local dx,dy=x+.5-center.x,y+.5-center.y
        if dx*dx+dy*dy<=cavern_radius*cavern_radius then add(x,y) end
      end
    end

    if anchor then
      local vx,vy=anchor.x-center.x,anchor.y-center.y
      local vv=vx*vx+vy*vy
      local sx=math.floor(math.min(center.x,anchor.x)-2)
      local ex=math.floor(math.max(center.x,anchor.x)+2)
      local sy=math.floor(math.min(center.y,anchor.y)-2)
      local ey=math.floor(math.max(center.y,anchor.y)+2)
      for x=sx,ex do
        for y=sy,ey do
          local px,py=x+.5,y+.5
          local q=vv>0 and ((px-center.x)*vx+(py-center.y)*vy)/vv or 0
          q=math.max(0,math.min(1,q))
          local ax,ay=center.x+q*vx,center.y+q*vy
          local dx,dy=px-ax,py-ay
          if dx*dx+dy*dy<=spur_radius*spur_radius then add(x,y) end
        end
      end
    end

    local clear_area={{math.floor(center.x-cavern_radius-1),math.floor(center.y-cavern_radius-1)},
      {math.ceil(center.x+cavern_radius+1),math.ceil(center.y+cavern_radius+1)}}
    for _,rock in ipairs(surface.find_entities_filtered{area=clear_area,
      name={"big-rock","huge-rock","big-sand-rock"}}) do rock.destroy() end
    if #tiles>0 then walls.set_tiles(surface,tiles,true,false,true) end
    if anchor then generation.connect_positions(surface,center,anchor,depth,seed,spur_radius,true) end
  end

  local center
  -- Multiple deterministic candidates keep a winning density roll from being
  -- silently lost to a ramp or player structure.  The first valid one wins.
  for attempt=1,8 do
    local salt=attempt*997
    local candidate={
      x=area.left_top.x+6+math.floor(hash(cx,cy,seed+32011+salt)*20)+.5,
      y=area.left_top.y+6+math.floor(hash(cx,cy,seed+32013+salt)*20)+.5
    }
    if not blocked(candidate) then center=candidate;break end
  end
  if not center then
    -- Check all remaining interior tiles before giving up on a winning roll.
    local ox=math.floor(hash(cx,cy,seed+32301)*20)
    local oy=math.floor(hash(cx,cy,seed+32303)*20)
    for step=0,399 do
      local p={x=area.left_top.x+6+(ox+step)%20+.5,
        y=area.left_top.y+6+(oy+math.floor(step/20))%20+.5}
      if not blocked(p) then center=p;break end
    end
  end
  if not center then return 0 end

  local anchor=nearest_floor(center)
  carve_overlay(center,anchor)
  local name=hash(cx,cy,seed+32017)<.22 and "spitter-spawner" or "biter-spawner"
  if not surface.can_place_entity{name=name,position=center,force="enemy"} then return 0 end
  local nest=surface.create_entity{name=name,position=center,force="enemy"}
  if not nest then return 0 end
  occupied[key]=nest
  marks[key]=mark
  if not anchor then generation.connect_entrance(surface,center,depth,seed,true,1.35) end

  if depth>=3 and hash(cx,cy,seed+32023)<.4 then
    local angle=hash(cx,cy,seed+32101)*math.pi*2
    local p={x=nest.position.x+math.cos(angle)*6,y=nest.position.y+math.sin(angle)*6}
    if inside(area,p) and clear_ground(surface,p) and not near_ramp(surface,p,6)
      and surface.can_place_entity{name="small-worm-turret",position=p,force="enemy"} then
      surface.create_entity{name="small-worm-turret",position=p,force="enemy"}
    end
  end
  return 1
end

-- Backfill explored caves after upgrading from a build where resources were
-- tied to the legacy chamber layout.  Work is bounded and never requests new chunks.
function features.queue_resources()
  local queue={}
  for _,surface in pairs(game.surfaces) do
    local depth=tonumber(surface.name:match("^deep%-caves%-level%-(%d+)$"))
    if depth then
      for chunk in surface.get_chunks() do
        if surface.is_chunk_generated(chunk) then
          queue[#queue+1]={surface=surface.index,depth=depth,x=chunk.x,y=chunk.y}
        end
      end
    end
  end
  table.sort(queue,function(a,b)
    if a.surface~=b.surface then return a.surface<b.surface end
    return a.x<b.x or (a.x==b.x and a.y<b.y)
  end)
  storage.deep_caves.resource_queue={chunks=queue,index=1,made=0}
  return #queue
end

function features.tick_resources()
  local queue=storage.deep_caves.resource_queue
  if not queue then return end
  local c=queue.chunks[queue.index]
  if not c then
    game.print("Cruel Rain: ore backfill complete ("..queue.made.." resource tiles placed).")
    storage.deep_caves.resource_queue=nil
    return
  end
  queue.index=queue.index+1
  local surface=game.surfaces[c.surface]
  if surface and surface.is_chunk_generated{x=c.x,y=c.y} then
    local seed=(game.default_map_gen_settings.seed+c.depth*104729+7919)%4294967295
    queue.made=queue.made+features.populate_resources(surface,
      {left_top={x=c.x*32,y=c.y*32},right_bottom={x=c.x*32+32,y=c.y*32+32}},c.depth,seed)
  end
end

-- Changing the setting also updates explored caves, amortized over time.
-- No chunk requests and no continuous enemy scan during normal play.
function features.queue_enemies()
  local queue={}
  for _,surface in pairs(game.surfaces) do
    local depth=tonumber(surface.name:match("^deep%-caves%-level%-(%d+)$"))
    if depth and depth<=5 then
      for chunk in surface.get_chunks() do
        if surface.is_chunk_generated(chunk) then
          queue[#queue+1]={surface=surface.index,depth=depth,x=chunk.x,y=chunk.y}
        end
      end
    end
  end
  table.sort(queue,function(a,b)
    if a.surface~=b.surface then return a.surface<b.surface end
    return a.x<b.x or (a.x==b.x and a.y<b.y)
  end)
  storage.deep_caves.enemy_queue={chunks=queue,index=1,made=0}
  return #queue
end

function features.tick_enemies()
  local queue=storage.deep_caves.enemy_queue
  if not queue then return end
  local c=queue.chunks[queue.index]
  if not c then
    game.print("Cruel Rain: enemy placement pass complete ("..queue.made.." new nests).")
    storage.deep_caves.enemy_queue=nil
    return
  end
  queue.index=queue.index+1
  local surface=game.surfaces[c.surface]
  if surface and surface.is_chunk_generated{x=c.x,y=c.y} then
    local seed=(game.default_map_gen_settings.seed+c.depth*104729+7919)%4294967295
    queue.made=queue.made+features.populate_enemies(surface,
      {left_top={x=c.x*32,y=c.y*32},right_bottom={x=c.x*32+32,y=c.y*32+32}},c.depth,seed)
  end
end

return features
