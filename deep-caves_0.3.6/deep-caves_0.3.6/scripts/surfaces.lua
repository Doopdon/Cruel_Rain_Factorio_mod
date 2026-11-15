local surfaces = {MAX_DEPTH=5}
function surfaces.darken(surface)
  if prototypes and prototypes.surface_property and prototypes.surface_property["deep-caves-above-ground"] then
    surface.set_property("deep-caves-above-ground",0)
  end
  surface.always_day=false
  surface.freeze_daytime=true
  surface.daytime=.5
  surface.min_brightness=0
  surface.brightness_visual_weights={1,1,1}
  surface.show_clouds=false
end
function surfaces.upgrade_darkness()
  for _,surface in pairs(game.surfaces) do
    if surface.name:match("^deep%-caves%-level%-%d+$") then surfaces.darken(surface);surface.no_enemies_mode=false end
  end
end

function surfaces.name(depth)
  return "deep-caves-level-" .. depth
end

function surfaces.depth_from_surface(surface)
  if surface.name == "nauvis" then return 0 end
  local d = string.match(surface.name, "^deep%-caves%-level%-(%d+)$")
  return d and tonumber(d) or nil
end

function surfaces.seed_for_depth(depth)
  local base = game.default_map_gen_settings and game.default_map_gen_settings.seed or 0
  return (base + depth * 104729 + 7919) % 4294967295
end

function surfaces.ensure(depth)
  if depth <= 0 then return game.surfaces["nauvis"] end
  local name = surfaces.name(depth)
  local existing = game.surfaces[name]
  if existing then surfaces.darken(existing);return existing end

  if depth>surfaces.MAX_DEPTH then return nil end
  local s = game.create_surface(name, {
    seed = surfaces.seed_for_depth(depth),
    peaceful_mode = game.surfaces.nauvis.peaceful_mode,
    no_enemies_mode = false,
    starting_area = "none",
    default_enable_all_autoplace_controls = false,
    autoplace_settings = {
      entity = {treat_missing_as_default = false, settings = {}},
      tile = {treat_missing_as_default = false, settings = {}},
      decorative = {treat_missing_as_default = false, settings = {}}
    },
    cliff_settings = {
      name = "cliff",
      cliff_elevation_0 = 1024,
      cliff_elevation_interval = 0,
      richness = 0
    }
  })

  surfaces.darken(s)
  return s
end

return surfaces
