# Cruel Rain

A hostile surface. Five cave layers. Build where there is room, keep the
power flowing, and watch what emerges from the dark.

Cruel Rain combines the cave system, solid rock walls, and permanent surface
weather in one Factorio 2.1 mod. Your friends only need this package.

## Play

Put `deep-caves_0.3.7.zip` in Factorio's mods folder and enable **Cruel Rain**.
Disable/remove the separate **Cave Walls** and **Surface Thunderstorm** mods,
and remove any older Deep Caves ZIP. Their functionality is included here.
Existing worlds are supported; a new map is optional for a fresh playthrough
or a clean comparison of mesh settings. Space Age is optional.

The ZIP keeps the internal mod name `deep-caves` so existing saves recognize
it. Keep its filename unchanged; **Cruel Rain** is the display name shown in
the game and on the portal.

The surface is a rain-soaked wasteland without mining deposits. Use a rocky
descent to enter Cave 1. Iron, copper, coal and stone starter patches are
placed near the first landing. Deeper layers grow darker and more cramped;
oil starts on Cave 3, uranium on Cave 4, and Cave 5 is flooded.

Stand on an opening's center tile to travel. Each pair shares a private
12-slot inventory with item filters; inserters can work from its edges.
Adjacent poles connect the pair's power bridge. Surface-connected openings
in Cave 1 are **Vents**: daylight, rain, muffled thunder, and local pollution
absorption of 7.5 per minute each by default. They need no power to ventilate.

Ramps also carry **one fluid per pair**. Place pipes on the
north, east, south or west side. Connection graphics are invisible. Pipe centers sit two tiles from the tile
center nearest the ramp's center. Each end holds 1,000 fluid, giving 2,000
per pair plus the capacity of connected pipes/tanks. Flow works both ways
without power; use pumps to set a direction. Use separate ramp pairs for
different fluids. Clicking a ramp opens **Cargo**; its **Fluids** button opens
the native fluid inventory, including the normal flush controls.

Connecting a pipe or opening the Fluids tab prepares an unused ramp's matching
end. If two ends already contain different fluids, they stay separate until
you drain or flush one side, then reconnect automatically.

Solid walls block movement. Flying robots and moving shots that cross them
are destroyed. Standard gun, laser and flamethrower turrets hold fire when
their target is behind cave rock, and resume when the path is clear.

Biters, spitters, worms and their nests have white colorable body layers,
including all four sizes and their death/decay animations. Natural dark details
and shadows remain. This applies on the surface and in every cave, and to
existing creatures when a save is loaded. Combat and spawning are unchanged.

Nests and worms are passable so they cannot trap bugs. Matching their collision
rules preserves native enemy expansion. Nest rolls grow with
radial distance from `(0,0)` and depth: the base density is multiplied by
`1 + min(3, distance / 1024)` and by `1 + 0.5 * (depth - 1)`, capped at
100% per eligible chunk. The Cave 1 starter safe zone and density zero still
work. Existing processed chunks stay as they are, including cleared nests;
stronger generation applies to newly explored chunks.

Cave 1 now has irregular shallow-water patches on its tunnel floors, outside
a dry 64-tile radius around (0,0). Newly explored areas get the extra water;
existing factory terrain is preserved. Other levels keep their previous water
patterns. Starter deposits and ramp landings retain their dry placement pads.

## Difficulty

Science-based research defaults to one tenth as many packs, including infinite
research. Research and rocket costs have independent Startup multipliers:
`0.1` keeps the current reduction, `0.5` halves normal costs, and `1` restores
normal costs. Both accept 0.01 to 100. Restart Factorio after changing them. Fixed counts round up and all counts have a minimum of one. The
packs used per unit and time per unit retain their normal values. Research
triggers such as crafting the first lab retain their normal requirements.

Each launch needs 10 rocket parts in the base game, or 5 with Space Age.
Rocket silos must be built above ground by default. The **Surface-only rocket
silos** Startup setting can disable that restriction. Underground silos and silo ghosts
placed by players, robots or raised script events are rejected; consumed
building items are returned with their quality. If an inventory is full, the
refund falls on the ground. Other underground machines work normally.

## Settings

Startup settings control density and width for the three tunnel networks,
and initial biter nest density. Sparse settings remain playable; random
spawns are probabilistic outside the guaranteed starter deposits. Density
zero disables the mod's initial nests. Native expansion on Cave 1 remains
subject to Factorio's expansion settings outside the starter safe zone.

**Vent pollution absorption (per minute)** is a Startup setting under
**Cruel Rain**. Default 7.5, range 0 to 100; 0 disables absorption. Restart
Factorio after changing it. Existing vents adopt the new value without a new
world or replacement of their cargo/power connections.

Map settings control surface storm enablement and exposure damage. Player
settings control darkness, rain, flashes, storm volume and cave drip volume.
Surface damage defaults to 0.5 per second for characters and 0.1 for buildings;
rails, native crash-site ship pieces and ramp infrastructure
are spared. Caves remain sheltered. All settings now appear under Cruel Rain.

## Existing saves

A save using a previous combined version can switch directly to 0.3.7.
Existing ramps retain their identities, fluid, cargo, filters, energy and
wires. The pipe connections have moved one tile inward: if your pipes are
in the old outer positions, add one pipe between them and the ramp. Existing
pipes are not moved automatically. No world restart is required.

Completed technologies and saved rocket parts remain. Default costs match
0.3.2, so that upgrade preserves current research progress. Changing research
costs can reset partial progress when the new count is below already invested
units; finish the current research before changing that setting.

A new world is not required. Upgrading a populated save from Deep Caves
0.2.20, Cave Walls 0.1.15 and Surface Thunderstorm 0.1.9 was tested in Factorio
2.0.76. Keep a backup of your save before switching packages.

For a save that used the separate components, run `/cave-walls-checks off`
while the old mods are enabled, then save before switching to this ZIP.
That releases only turrets the old wall script paused. The combined mod
starts wall checks enabled and preserves intentionally inactive turrets.

Generated cave terrain, ramp/vent identities, shared cargo, slot filters,
power buffers and wires remain. Existing wall boundary helpers are reused.
Factorio 2.0 cannot transfer private storage between removed mods, so the
old storm command override/clock and brush restoration history reset.
Weather map/player settings retain their existing names; erasing an old
painted wall without its former history restores stone-path. New brush
strokes retain their original terrain normally.

## Useful commands

- `/cave-check-spawns` reads nearby ores, nests, entrances and pair links.
- `/surface-storm on`, `off`, `lightning`, or `status` controls weather.
- `/cave-walls-checks on`, `off`, or `status` controls wall checks for diagnosis.
- `/cave-diagnostics start 10` and `/cave-walls-diagnostics start 10` profile scripts.
- Alt+W gets the terrain brush; left-drag paints walls, Shift+left-drag or
  right-drag erases. The brush is a debug/editor tool and requires no recipe.

## Development and publishing

Version 0.3.7 supports Factorio 2.1.24 while preserving saves, fluids, and
turret behavior. Version 0.3.6 made research and launch costs configurable and
added a switch for surface-only silos. Fluid ports are invisible and one tile closer. Ramp fluids and adjustable ventilation remain included; balancing
and playtesting continue. Biter Caution and improvised weapons remain separate projects.
`MOD_PORTAL.md` contains the portal description and upload notes.
`tests/README.md` explains reproducible tests; `INTEGRATION.md` records what
was verified. Historical component notes are kept under `docs/history`.

## License and credits

Original mod code, documentation and project-created assets use the **MIT
License** in `LICENSE`. The cave water-drop recording is **Water Drops** by
**ianna.lpl (Freesound)**, shared by **freesound_community** via **Pixabay**,
and retains the **Pixabay Content License**. See `THIRD_PARTY_NOTICES.md` for
the source and license links.
