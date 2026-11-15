local generation = {}
local walls=require("scripts.walls")

function generation.floor_name(surface)
  local depth = tonumber(string.match(surface.name, "^deep%-caves%-level%-(%d+)$"))
  return depth and "deep-caves-stone-" .. math.min(depth,12) or "dirt-7"
end


local function fract(x)
  return x - math.floor(x)
end

local function hash01(x, y, seed)
  -- Deterministic hash.  No Lua RNG state, so generation order does not matter.
  return fract(math.sin(x * 127.1 + y * 311.7 + seed * 0.0137) * 43758.5453123)
end

generation.hash01 = hash01

local function network(layer)
  local name=({"large","small","web"})[layer]
  return {cell=256/settings.startup["deep-caves-"..name.."-density"].value,
    width=settings.startup["deep-caves-"..name.."-width"].value}
end
local function params(depth)
  local large=network(1)
  return {cell=large.cell,chamber=math.max(8,large.width),tunnel=2.5,bend=.24}
end

generation.params = params

local function node_for(cx, cy, cell, seed, level)
  level = level or 0
  local size = cell * 2 ^ level
  return {
    x = (cx + 0.5 + (hash01(cx, cy, seed + 17 + level * 373) - 0.5) * 0.88) * size,
    y = (cy + 0.5 + (hash01(cx, cy, seed + 43 + level * 613) - 0.5) * 0.88) * size
  }
end

local function dist_sq(a, b, x, y)
  return (x-a)^2 + (y-b)^2
end

local function point_segment_distance_sq(px, py, ax, ay, bx, by)
  local dx, dy = bx-ax, by-ay
  local denominator = dx*dx + dy*dy
  local t = denominator > 0 and ((px-ax)*dx + (py-ay)*dy)/denominator or 0
  t = math.max(0, math.min(1, t))
  return (px-ax-t*dx)^2 + (py-ay-t*dy)^2
end

-- Midpoint displacement at three scales, then corner smoothing. All seeds
-- belong to the edge, so adjacent chunks calculate exactly the same curve.
local function curved_path(a, b, seed, keyx, keyy)
  local points = {a, b}
  for level = 1, 3 do
    local next_points = {points[1]}
    for i = 1, #points-1 do
      local u, v = points[i], points[i+1]
      local dx, dy = v.x-u.x, v.y-u.y
      local bend = (hash01(keyx+i*79, keyy+level*103, seed)-0.5)*0.48
      next_points[#next_points+1] = {
        x=(u.x+v.x)*0.5-dy*bend, y=(u.y+v.y)*0.5+dx*bend
      }
      next_points[#next_points+1] = v
    end
    points = next_points
  end
  local smooth = {a}
  for i = 1, #points-1 do
    local u, v = points[i], points[i+1]
    smooth[#smooth+1] = {x=u.x*0.75+v.x*0.25, y=u.y*0.75+v.y*0.25}
    smooth[#smooth+1] = {x=u.x*0.25+v.x*0.75, y=u.y*0.25+v.y*0.75}
  end
  smooth[#smooth+1] = b
  return smooth
end

local function segments_for(points, width)
  local segments = {}
  for i = 1, #points-1 do
    local a,b = points[i],points[i+1]
    segments[#segments+1] = {ax=a.x,ay=a.y,bx=b.x,by=b.y,width=width}
  end
  return segments
end

local function smooth_noise(x,y,seed)
  local ix,iy = math.floor(x),math.floor(y)
  local fx,fy = x-ix,y-iy
  fx,fy = fx*fx*(3-2*fx),fy*fy*(3-2*fy)
  local a = hash01(ix,iy,seed)*(1-fx)+hash01(ix+1,iy,seed)*fx
  local b = hash01(ix,iy+1,seed)*(1-fx)+hash01(ix+1,iy+1,seed)*fx
  return a*(1-fy)+b*fy
end

-- Patchy shallow water on Level 1, with wetter strata on Levels 2 and 5.
-- The world-coordinate mask gives broad irregular wetlands without chunk seams.
function generation.is_flooded_depth(depth)
  return depth==1 or depth==2 or depth==5
end
function generation.flooded_at(x,y,depth,seed)
  if not generation.is_flooded_depth(depth) then return false end
  -- Keep the starter resources and landing area dry.
  if depth==1 and x*x+y*y<64*64 then return false end
  local broad=smooth_noise(x/38,y/38,seed+39019)
  local fine=smooth_noise(x/12,y/12,seed+39103)
  return broad*.75+fine*.25>(depth==1 and .62 or (depth==5 and .36 or .5))
end

local function paint_segment(mask,cx,cy,s,seed)
  local reach = s.width*1.25
  local x0 = math.max(cx*32,math.floor(math.min(s.ax,s.bx)-reach))
  local x1 = math.min(cx*32+31,math.ceil(math.max(s.ax,s.bx)+reach))
  local y0 = math.max(cy*32,math.floor(math.min(s.ay,s.by)-reach))
  local y1 = math.min(cy*32+31,math.ceil(math.max(s.ay,s.by)+reach))
  for y=y0,y1 do
    for x=x0,x1 do
      local index = (y-cy*32)*32+x-cx*32+1
      if not mask[index] then
        local width = math.max(2,s.width*(0.82+smooth_noise((x+0.5)/7,(y+0.5)/7,seed+251)*0.42))
        if point_segment_distance_sq(x+0.5,y+0.5,s.ax,s.ay,s.bx,s.by)<=width*width then mask[index]=true end
      end
    end
  end
end

-- Experimental three-pass terrain. Edges are cached as geometry, independent
-- of chunk order. A cardinal raster walk keeps even one-tile paths connected.
local geometry_cache,geometry_order={},{}
local function geometry(gx,gy,depth,seed,layer)
  local key=depth..":"..seed..":"..layer..":"..gx..":"..gy
  if geometry_cache[key] then return geometry_cache[key] end
  local p=network(layer)
  local node_seed=seed+layer*10007
  local node=node_for(gx,gy,p.cell,node_seed)
  local g={paths={}}
  local function path(a,b,width,salt,kx,ky)
    local points=curved_path(a,b,seed+salt,kx,ky)
    local tiles={}
    local minx,miny,maxx,maxy=math.huge,math.huge,-math.huge,-math.huge
    local function add(x,y)
      tiles[#tiles+1]={x=x,y=y}
      minx=math.min(minx,x);miny=math.min(miny,y)
      maxx=math.max(maxx,x);maxy=math.max(maxy,y)
    end
    for i=1,#points-1 do
      local u,v=points[i],points[i+1]
      local x,y=math.floor(u.x),math.floor(u.y)
      local tx,ty=math.floor(v.x),math.floor(v.y)
      local dx,dy=math.abs(tx-x),math.abs(ty-y)
      local sx,sy=tx>x and 1 or -1,ty>y and 1 or -1
      local ix,iy=0,0
      add(x,y)
      while ix<dx or iy<dy do
        if ix<dx and (iy>=dy or (ix+.5)*dy <= (iy+.5)*dx) then
          x=x+sx;ix=ix+1
        else y=y+sy;iy=iy+1 end
        add(x,y)
      end
    end
    g.paths[#g.paths+1]={tiles=tiles,width=width,minx=minx,miny=miny,maxx=maxx,maxy=maxy}
  end
  -- Each scale is a complete winding mesh of its own. Overlap joins the
  -- three meshes naturally; the fine network is not a set of dead-end spokes.
  for edge,target in ipairs({node_for(gx+1,gy,p.cell,node_seed),node_for(gx,gy+1,p.cell,node_seed)}) do
    path(node,target,p.width,layer*3101+edge*1759,gx,gy)
  end
  geometry_cache[key]=g;geometry_order[#geometry_order+1]=key
  if #geometry_order>384 then geometry_cache[table.remove(geometry_order,1)]=nil end
  return g
end

local cache,cache_order={},{}
local function floor_mask(cx,cy,depth,seed)
  local key=depth..":"..seed..":"..cx..":"..cy
  if cache[key] then return cache[key].mask end
  local mask,kinds={},{}
  local open_count=0
  local function add(x,y,kind)
    if x>=cx*32 and x<cx*32+32 and y>=cy*32 and y<cy*32+32 then
      local i=(y-cy*32)*32+x-cx*32+1
      if not mask[i] then mask[i]=true;open_count=open_count+1 end
      kinds[i]=math.min(kinds[i] or kind,kind)
    end
  end
  for layer=1,3 do
    if open_count==1024 then break end
    local p=network(layer)
    -- Include neighboring edges, curve displacement and configurable width.
    local margin=2+math.ceil(p.width/p.cell)
    for gx=math.floor(cx*32/p.cell)-margin,math.floor((cx*32+31)/p.cell)+margin do
      for gy=math.floor(cy*32/p.cell)-margin,math.floor((cy*32+31)/p.cell)+margin do
        local g=geometry(gx,gy,depth,seed,layer)
        for _,path in ipairs(g.paths) do
          -- Integer dilation supports both odd and even widths. A width of
          -- one paints only the cardinal centerline, including across seams.
          local low=-math.floor((path.width-1)/2)
          local high=math.floor(path.width/2)
          if path.minx+low<cx*32+32 and path.maxx+high>=cx*32
            and path.miny+low<cy*32+32 and path.maxy+high>=cy*32 then
            for _,tile in ipairs(path.tiles) do
              if tile.x+low<cx*32+32 and tile.x+high>=cx*32
                and tile.y+low<cy*32+32 and tile.y+high>=cy*32 then
                for dx=math.max(low,cx*32-tile.x),math.min(high,cx*32+31-tile.x) do
                  for dy=math.max(low,cy*32-tile.y),math.min(high,cy*32+31-tile.y) do add(tile.x+dx,tile.y+dy,layer) end
                end
              end
            end
          end
        end
      end
    end
  end
  cache[key]={mask=mask,kinds=kinds};cache_order[#cache_order+1]=key
  if #cache_order>128 then cache[table.remove(cache_order,1)]=nil end
  return mask
end

-- Useful for inspecting the experiment without duplicating its geometry.
function generation.layout_kinds(cx,cy,depth,seed)
  floor_mask(cx,cy,depth,seed)
  return cache[depth..":"..seed..":"..cx..":"..cy].kinds
end

function generation.is_fine_path(x,y,depth,seed)
  local ix,iy=math.floor(x),math.floor(y)
  local cx,cy=math.floor(ix/32),math.floor(iy/32)
  return generation.layout_kinds(cx,cy,depth,seed)[(iy-cy*32)*32+ix-cx*32+1]==3
end

function generation.is_floor(x,y,depth,seed)
  local ix,iy=math.floor(x),math.floor(y)
  local cx,cy=math.floor(ix/32),math.floor(iy/32)
  return floor_mask(cx,cy,depth,seed)[(iy-cy*32)*32+ix-cx*32+1] or false
end

generation.smooth_noise=smooth_noise

function generation.is_cave_ground(name)
  return string.match(name,"^deep%-caves%-stone%-%d+$")
    or string.match(name,"^deep%-caves%-earth%-%d+$")
    or string.match(name,"^deep%-caves%-sand%-%d+$")
end

function generation.ground_name(surface,x,y,depth,seed)
  depth=depth or tonumber(string.match(surface.name,"^deep%-caves%-level%-(%d+)$"))
  if not depth then return "dirt-7" end
  seed=seed or (game.default_map_gen_settings.seed+depth*104729+7919)%4294967295
  local broad=smooth_noise(x/39,y/39,seed+28103)
  local fine=smooth_noise(x/11,y/11,seed+28201)
  local kind=(broad*.72+fine*.28)>.55 and "earth" or "stone"
  if broad<.38 and fine>.60 then kind="sand" end
  return "deep-caves-"..kind.."-"..math.min(depth,12)
end

-- Features belong to global chamber cells, never to chunk order.
function generation.sites_in_area(area,depth,seed)
  local p=params(depth)
  local sites={}
  for gx=math.floor((area.left_top.x-32)/p.cell)-1,math.floor((area.right_bottom.x+32)/p.cell)+1 do
    for gy=math.floor((area.left_top.y-32)/p.cell)-1,math.floor((area.right_bottom.y+32)/p.cell)+1 do
      local n=node_for(gx,gy,p.cell,seed+10007)
      n.gx,n.gy=gx,gy
      n.radius=p.chamber*(.55+hash01(gx,gy,seed+101)*.8)
      if hash01(gx,gy,seed+29009)<.55 then
        local angle=hash01(gx,gy,seed+29101)*math.pi*2
        local radius=5+hash01(gx,gy,seed+29113)*4.5
        local offset=radius*.65
        n.pool={x=n.x+math.cos(angle)*offset,y=n.y+math.sin(angle)*offset,radius=radius}
      end
      sites[#sites+1]=n
    end
  end
  return sites
end

local function pool_mask(cx,cy,sites,seed)
  local water,shore={},{}
  for _,site in ipairs(sites) do
    local pool=site.pool
    if pool then
      local reach=pool.radius*1.15+2.5
      for x=math.max(cx*32,math.floor(pool.x-reach)),math.min(cx*32+31,math.ceil(pool.x+reach)) do
        for y=math.max(cy*32,math.floor(pool.y-reach)),math.min(cy*32+31,math.ceil(pool.y+reach)) do
          local r=pool.radius*(.85+smooth_noise((x+.5)/4,(y+.5)/4,seed+29303)*.3)
          local d=dist_sq(pool.x,pool.y,x+.5,y+.5)
          local index=(y-cy*32)*32+x-cx*32+1
          if d<=(r+2.5)^2 then shore[index]=true end
          if d<=r*r then water[index]=true end
        end
      end
    end
  end
  return water,shore
end

function generation.upgrade_shallow_water()
  if storage.deep_caves.shallow_water_version==1 then return end
  for _,surface in pairs(game.surfaces) do
    if string.match(surface.name,"^deep%-caves%-level%-%d+$") then
      for chunk in surface.get_chunks() do
        if surface.is_chunk_generated(chunk) then
          local tiles={}
          for _,tile in ipairs(surface.find_tiles_filtered{
            area={{chunk.x*32,chunk.y*32},{chunk.x*32+32,chunk.y*32+32}},
            name={"water","water-green","deepwater","deepwater-green"}}) do
            tiles[#tiles+1]={name="deep-caves-shallow-water",position=tile.position}
          end
          if #tiles>0 then walls.set_tiles(surface,tiles,true,false,true) end
        end
      end
    end
  end
  storage.deep_caves.shallow_water_version=1
end

function generation.upgrade_ground_mix()
  local state=storage.deep_caves
  if state.ground_mix_version==1 then return end
  for _,surface in pairs(game.surfaces) do
    local depth=tonumber(string.match(surface.name,"^deep%-caves%-level%-(%d+)$"))
    if depth then
      surface.peaceful_mode=game.surfaces.nauvis.peaceful_mode
      for chunk in surface.get_chunks() do
        if surface.is_chunk_generated(chunk) then
          local tiles={}
          for x=chunk.x*32,chunk.x*32+31 do
            for y=chunk.y*32,chunk.y*32+31 do
              local old=surface.get_tile(x,y)
              if generation.is_cave_ground(old.name) and not old.hidden_tile then
                local name=generation.ground_name(surface,x+.5,y+.5,depth)
                if name~=old.name then tiles[#tiles+1]={name=name,position={x,y}} end
              end
            end
          end
          if #tiles>0 then walls.set_tiles(surface,tiles,true,false,true) end
        end
      end
    end
  end
  state.ground_mix_version=1
end

function generation.carve_circle(surface, position, radius)
  if string.match(surface.name, "^deep%-caves%-level%-%d+$") then
    for _, rock in pairs(surface.find_entities_filtered{position=position,radius=radius+1,
      name={"big-rock","huge-rock","big-sand-rock"}}) do
      rock.destroy()
    end
  end
  local tiles = {}
  local r2 = radius * radius
  local minx = math.floor(position.x - radius)
  local maxx = math.floor(position.x + radius)
  local miny = math.floor(position.y - radius)
  local maxy = math.floor(position.y + radius)
  for x = minx, maxx do
    for y = miny, maxy do
      local dx = x + 0.5 - position.x
      local dy = y + 0.5 - position.y
      if dx * dx + dy * dy <= r2 then
        local old=surface.get_tile(x,y)
        local cave=string.match(surface.name,"^deep%-caves%-level%-%d+$")
        local name=generation.ground_name(surface,x+.5,y+.5)
        if old.valid and ((old.hidden_tile and not walls.is_wall(old.name)) or (not cave and not walls.is_wall(old.name) and old.name~="water" and old.name~="deepwater" and old.name~="water-green" and old.name~="deepwater-green")) then name=old.name end
        tiles[#tiles + 1] = {name=name,position={x,y}}
      end
    end
  end
  walls.set_tiles(surface,tiles, true, false, true)
end

local function carve_connection(surface,points,depth,seed,width,deferred)
  local segments=segments_for(points,width)
  local chunks={}
  for _,s in ipairs(segments) do
    for x=math.floor((math.min(s.ax,s.bx)-width)/32),math.floor((math.max(s.ax,s.bx)+width)/32) do
      for y=math.floor((math.min(s.ay,s.by)-width)/32),math.floor((math.max(s.ay,s.by)+width)/32) do
        local key=x..":"..y
        local c=chunks[key] or {x=x,y=y,segments={}}
        c.segments[#c.segments+1]=s;chunks[key]=c
      end
    end
  end
  -- Sorted requests make incidental chunk generation deterministic too.
  local keys={}
  for key in pairs(chunks) do keys[#keys+1]=key end
  table.sort(keys)
  local state=storage.deep_caves
  state.cave_seams=state.cave_seams or {}
  local seams=state.cave_seams[surface.index] or {}
  state.cave_seams[surface.index]=seams
  for _,key in ipairs(keys) do
    local c=chunks[key]
    if deferred then
      -- Persist spurs through unseen chunks without recursively generating
      -- more nests/ramps. raw_layout paints them when those chunks are explored.
      if not surface.is_chunk_generated(c) then
        local saved=seams[key] or {};seams[key]=saved
        for _,s in ipairs(c.segments) do saved[#saved+1]=s end
      end
    else surface.request_to_generate_chunks({x=c.x*32+16,y=c.y*32+16},0) end
  end
  if not deferred then surface.force_generate_chunk_requests() end
  for _,key in ipairs(keys) do chunks[key].generated=surface.is_chunk_generated(chunks[key]) end
  local tiles,seen={},{}
  for _,s in ipairs(segments) do
    for x=math.floor(math.min(s.ax,s.bx)-width),math.ceil(math.max(s.ax,s.bx)+width) do
      for y=math.floor(math.min(s.ay,s.by)-width),math.ceil(math.max(s.ay,s.by)+width) do
        local key=x..":"..y
        local c=chunks[math.floor(x/32)..":"..math.floor(y/32)]
        if c and c.generated and not seen[key]
          and point_segment_distance_sq(x+0.5,y+0.5,s.ax,s.ay,s.bx,s.by)<=width*width then
          seen[key]=true
          local old=surface.get_tile(x,y)
          local name=(old.hidden_tile and not walls.is_wall(old.name)) and old.name or generation.ground_name(surface,x+.5,y+.5)
          local depth=tonumber(surface.name:match("^deep%-caves%-level%-(%d+)$"))
          if depth==5 and (old.name=="deep-caves-shallow-water"
            or (walls.is_wall(old.name) and generation.flooded_at(x+.5,y+.5,depth,seed)
              and dist_sq(x+.5,y+.5,segments[1].ax,segments[1].ay)>=49)) then
            name="deep-caves-shallow-water"
          end
          tiles[#tiles+1]={name=name,position={x,y}}
        end
      end
    end
    for _,rock in pairs(surface.find_entities_filtered{area={{math.min(s.ax,s.bx)-width-2,math.min(s.ay,s.by)-width-2},{math.max(s.ax,s.bx)+width+2,math.max(s.ay,s.by)+width+2}},
      name={"big-rock","huge-rock","big-sand-rock"}}) do
      local r=rock.position
      if point_segment_distance_sq(r.x,r.y,s.ax,s.ay,s.bx,s.by)<=(width+1.5)^2 then rock.destroy() end
    end
  end
  walls.set_tiles(surface,tiles,true,false,true)
end

-- Use all three meshes when choosing an access node. Only using the large
-- mesh produced unnecessarily long spurs after reducing the mesh settings.
function generation.connect_entrance(surface,position,depth,seed,deferred,width)
  if depth<=0 then return end
  local target,best
  for layer=1,3 do
    local p=network(layer)
    local cx,cy=math.floor(position.x/p.cell),math.floor(position.y/p.cell)
    for gx=cx-1,cx+1 do for gy=cy-1,cy+1 do
      local n=node_for(gx,gy,p.cell,seed+layer*10007)
      local d=dist_sq(n.x,n.y,position.x,position.y)
      if not best or d<best then target,best=n,d end
    end end
  end
  local points=curved_path(position,target,seed+9719,math.floor(position.x),math.floor(position.y))
  carve_connection(surface,points,depth,seed,width or 2.5,deferred)
end

function generation.connect_positions(surface,a,b,depth,seed,width,deferred)
  carve_connection(surface,{a,b},depth,seed,width or 1.5,deferred)
end

-- Combine the configured networks with saved entrance access spurs and pools.
local function raw_layout(surface,cx,cy,depth,seed)
  local mask={}
  for i,v in pairs(floor_mask(cx,cy,depth,seed)) do mask[i]=v end
  local seams=storage.deep_caves.cave_seams and storage.deep_caves.cave_seams[surface.index]
  for _,s in ipairs(seams and seams[cx..":"..cy] or {}) do paint_segment(mask,cx,cy,s,seed) end
  local area={left_top={x=cx*32,y=cy*32},right_bottom={x=cx*32+32,y=cy*32+32}}
  local water,shore=pool_mask(cx,cy,generation.sites_in_area(area,depth,seed),seed)
  return {mask=mask,water=water,shore=shore}
end

function generation.generate_chunk(surface, area, depth, seed)
  local cx,cy=math.floor(area.left_top.x/32),math.floor(area.left_top.y/32)
  local layout=raw_layout(surface,cx,cy,depth,seed)
  local tiles={}
  for y=0,31 do
    for x=0,31 do
      local old=surface.get_tile(cx*32+x,cy*32+y)
      local keep=old.name=="deep-caves-shallow-water" or generation.is_cave_ground(old.name)
        or (old.hidden_tile~=nil and not walls.is_wall(old.name)) or old.name=="stone-path"
        or string.find(old.name,"concrete",1,true) or old.name=="foundation"
      local index=y*32+x+1
      local name=walls.NAME
      if layout.mask[index] or layout.shore[index] then
        name=generation.ground_name(surface,cx*32+x+.5,cy*32+y+.5,depth,seed)
      end
      if (layout.water[index] and not layout.mask[index])
        or (layout.mask[index] and generation.flooded_at(cx*32+x+.5,cy*32+y+.5,depth,seed))
        then name="deep-caves-shallow-water" end
      if keep then name=old.name end
      tiles[#tiles+1]={name=name,position={cx*32+x,cy*32+y}}
    end
  end
  walls.set_tiles(surface,tiles,true,false,true)
  local seams=storage.deep_caves.cave_seams and storage.deep_caves.cave_seams[surface.index]
  if seams then seams[cx..":"..cy]=nil end -- Only unseen chunks need saved access geometry.
end

function generation.find_floor_in_chunk(area, depth, seed,accept)
  -- A ramp carves its own landing. Requiring a +/-3 tile cross of natural
  -- floor rejected essentially every site when all tunnel widths were small.
  -- Search the entire chunk, including tunnels that only touch its edge.
  local ox = math.floor(hash01(area.left_top.x / 32, area.left_top.y / 32, seed + 8101) * 32)
  local oy = math.floor(hash01(area.left_top.x / 32, area.left_top.y / 32, seed + 8209) * 32)
  for step = 0, 1023 do
    local lx = (ox + step) % 32
    local ly = (oy + math.floor(step / 32)) % 32
    local x = area.left_top.x + lx + 0.5
    local y = area.left_top.y + ly + 0.5
    local p={x=x,y=y}
    if generation.is_floor(x, y, depth, seed) and (not accept or accept(p)) then
      return p
    end
  end
  return nil
end

function generation.upgrade_floor_textures()
  storage.deep_caves = storage.deep_caves or {}
  if storage.deep_caves.stone_floor_version == 1 then return end
  for _, surface in pairs(game.surfaces) do
    if string.match(surface.name, "^deep%-caves%-level%-%d+$") then
      for chunk in surface.get_chunks() do
        local tiles = {}
        for _, tile in pairs(surface.find_tiles_filtered{area={{chunk.x*32,chunk.y*32},{chunk.x*32+32,chunk.y*32+32}},name="dirt-7"}) do
          tiles[#tiles+1] = {name=generation.floor_name(surface),position=tile.position}
        end
        if #tiles>0 then walls.set_tiles(surface,tiles,true) end
      end
    end
  end
  storage.deep_caves.stone_floor_version = 1
end

function generation.rock_density(depth)
  return math.min(1, 0.07 + math.max(0,depth-1)*0.085)
end

function generation.populate_rocks(surface, area, depth, seed, force)
  storage.deep_caves=storage.deep_caves or {}
  storage.deep_caves.rock_chunks=storage.deep_caves.rock_chunks or {}
  local marks=storage.deep_caves.rock_chunks[surface.index] or {}
  storage.deep_caves.rock_chunks[surface.index]=marks
  local key=math.floor(area.left_top.x/32)..":"..math.floor(area.left_top.y/32)
  if not force and marks[key]==2 then return end
  marks[key]=2
  local portals=surface.find_entities_filtered{area={{area.left_top.x-9,area.left_top.y-9},{area.right_bottom.x+9,area.right_bottom.y+9}},name={"deep-caves-ramp-up","deep-caves-ramp-down","deep-caves-vent"}}
  local density=generation.rock_density(depth)
  -- Global candidate lattice: chunk order cannot change placement or spacing.
  for gx=math.ceil(area.left_top.x/2.5),math.ceil(area.right_bottom.x/2.5)-1 do
    for gy=math.ceil(area.left_top.y/2.5),math.ceil(area.right_bottom.y/2.5)-1 do
      if hash01(gx,gy,seed+19101)<density then
        local p={x=gx*2.5+0.5,y=gy*2.5+0.5}
        if p.x>=area.left_top.x and p.x<area.right_bottom.x and p.y>=area.left_top.y and p.y<area.right_bottom.y then
          -- Mineable stone should occur inside actual passages, including the
          -- narrower tunnel mesh. Requiring the old 5x5 open square excluded
          -- most tunnels, so use a compact cross-shaped clearance instead.
          local clear=generation.is_floor(p.x,p.y,depth,seed)
            and generation.is_floor(p.x-1,p.y,depth,seed)
            and generation.is_floor(p.x+1,p.y,depth,seed)
            and generation.is_floor(p.x,p.y-1,depth,seed)
            and generation.is_floor(p.x,p.y+1,depth,seed)
          for _,portal in ipairs(portals) do
            if dist_sq(portal.position.x,portal.position.y,p.x,p.y)<81 then clear=false;break end
          end
          if clear and generation.is_cave_ground(surface.get_tile(p).name)
            and surface.count_entities_filtered{position=p,radius=1.5,type="resource"}==0
            and surface.count_entities_filtered{position=p,radius=1.25,force="player"}==0
            and surface.can_place_entity{name="big-rock",position=p,force="neutral"} then
            surface.create_entity{name="big-rock",position=p,force="neutral"}
          end
        end
      end
    end
  end
end

function generation.upgrade_rocks()
  storage.deep_caves=storage.deep_caves or {}
  if storage.deep_caves.rock_population_version==2 then return end
  local chunks={}
  for _,surface in pairs(game.surfaces) do
    local depth=tonumber(string.match(surface.name,"^deep%-caves%-level%-(%d+)$"))
    if depth then
      for chunk in surface.get_chunks() do
        if surface.is_chunk_generated(chunk) then chunks[#chunks+1]={surface=surface,depth=depth,x=chunk.x,y=chunk.y} end
      end
    end
  end
  for _,chunk in ipairs(chunks) do
    generation.populate_rocks(chunk.surface,{left_top={x=chunk.x*32,y=chunk.y*32},right_bottom={x=chunk.x*32+32,y=chunk.y*32+32}},chunk.depth,((game.default_map_gen_settings.seed + chunk.depth * 104729 + 7919) % 4294967295),true)
  end
  storage.deep_caves.rock_population_version=2
end

return generation
