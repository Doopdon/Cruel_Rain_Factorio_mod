# Deep Caves 0.2.20 — pollution vents

Cave 1 openings that lead to Nauvis are now named **Vents**. Each absorbs
up to **10 pollution per minute** from its cave chunk using Factorio's native
negative emissions, the same passive mechanism used by trees. Vents need no
power, stack their absorption when several share a chunk, and stop at zero
pollution. Pollution is removed locally rather than moved onto Nauvis.

Existing surface openings convert automatically on update. Their paired
cargo entities, item contents, slot filters, power buffers, and saved copper
and circuit wires are preserved. Travel, daylight, rain, and entrance puddles
continue to work. Deeper ascents retain their existing behavior.

Install `deep-caves_0.2.20.zip` alongside Cave Walls and remove the older
Deep Caves ZIP from Factorio's mods folder. You can continue an existing save.

Validation: **51 Lua checks**, **13 native spawning checks** at minimum mesh
settings, and **6 native vent/upgrade checks** pass in Factorio 2.0.76 with
Cave Walls 0.1.13. The upgrade checks load an actual 0.2.19 save containing
37 coal, a cargo filter, 8 MJ, and copper/red/green wires. See `VENTS.md` and
`tests/README.md` for details and reproducible commands.

---

# Deep Caves 0.2.19 — spawning fixes and regression tests

Install `deep-caves_0.2.19.zip` in the Factorio mods folder and remove the older
Deep Caves ZIP. Keep Cave Walls installed (tested with 0.1.13). Use a new world
for comparisons when changing cave mesh settings.

This version fixes ramp placement with narrow/sparse settings and creates
Cave 1 during setup so the four fixed starter deposits near (0,0) are present
before first travel. Each 3x3 starter patch contains about 5,000 resources;
short paths connect the pads to the initial landing. Random ramps and return
landings avoid these pads.

Ore searches cover the entire chunk. Oil and wet-only tunnels receive small
dry side pads when needed, joined to existing walkable floor. Successful nest
overlays get an access route even when the natural tunnel is in a neighboring
chunk. Unseen access segments are saved for later exploration without forcing
more chunks to generate, then discarded from storage once painted.

Failed placement is retryable; partial resource passes retain completed
patches. Ordinary same-density enemy backfills leave cleared nests cleared.
Existing generated areas get the updated ramp/resource/enemy placement passes
when upgrading; the existing terrain mesh is not rerolled.

- `/cave-check-spawns` inspects nearby ramps, ores, nests and pair links without
  generating anything. An optional radius of 1–8 is measured in chunks.
- `/cave-populate-resources` queues missing or incomplete resource passes.
- `/cave-populate-enemies` queues missing or incomplete nest passes.
- `/cave-background on` enables the background surface-return preparation if
  it was deliberately turned off for profiling in an existing save.

Spawning remains probabilistic outside the starter deposits: ramp candidates
use a 50% roll in chunks with natural tunnel floor; scattered resources use
roughly 45% of chunks, subject to placement space. Nest density 0 means off,
0.01 means about 1%, 0.1 about 10%, and every value >=1 means 100% of eligible
chunks. Starter nest exclusion and protection for ramps, ores and factories
still apply. Oil begins on Level 3; uranium on Level 4. Level 5 is the bottom
and has no downward ramps. These settings do not mean one entity in every
chunk or every small area explored.

See `AUDIT.md` for findings and validation, and `tests/README.md` for runnable
Lua and real-Factorio regression suites. Test hooks never run in normal saves.

---

## Historical release notes

The material below records earlier versions and their old settings.

## 0.2.12 tunnel stone and upper-coal pass

- Mineable native `big-rock` stone now spawns throughout cave passages, including narrow tunnels; the older 5x5-open-floor requirement was reduced to a compact cross clearance. Ramps, resources, and player structures remain protected.
- Cave Level 1 ore patches are now strongly coal-biased: about 48% coal, 18% iron, 16% copper, and 18% stone. Level 2 keeps a smaller coal bias before deeper levels return to the normal mix.
- Existing explored caves receive one upgrade pass for the new tunnel-rock placement, and the ore resource version is bumped so the new Level 1 coal weighting can fill previously processed chunks without respawning exhausted deposits of the same exact patch positions.

# Deep Caves 0.2.2 — Configurable Mesh Experiment

## 0.2.11 scattered cave ores

- Restored cave resources using a new per-chunk scatter system that follows the current three-mesh cave layout instead of the retired chamber-site grid.
- Iron, copper, coal and stone can appear on every cave level. Uranium begins at Level 4.
- Roughly 45% of generated cave chunks receive at least one small ore patch; a small fraction receive two. Placement only uses actual dry cave floor and avoids ramps and player structures.
- Deposits become richer with depth without dramatically increasing visual patch density.
- Existing explored cave chunks are backfilled gradually after upgrade. `/cave-populate-resources` can manually queue another missing-chunk pass; already processed chunks are not duplicated.


A Factorio 2.0 mod with connected, procedural cave layers and paired ramps.

## Included

- Many ramps on Nauvis and each explored cave depth. All entrances to a given depth share one cave surface.
- Paired return ramps with fixed artwork and a depth indicator.
- Natural stone terrain that darkens with depth, with progressively more mineable rocks.
- Surface-linked up ramps emit light that follows the overworld day/night cycle. Deeper ramps do not.
- Each ramp pair shares a private 12-slot inventory. Click the ramp to open it; inserters target any edge from outside its footprint.
- Ramps are power poles: connect copper wires directly to them. Wire reach is 2.75 tiles measured from the center, enough to reach the adjacent tile outside the three-tile ramp footprint: place your local pole immediately beside the ramp. The local supply square is 2 by 2 tiles, within the 3 by 3 tile ramp artwork.
- Power transfers through the paired ramps. There is no separate visible pole or battery.

## Controls

Stand in the center tile of a ramp to travel. Travel pauses while a GUI is open.

- `/cave-info`: show depth and cave generation parameters.
- `/cave-create-entrance`: admin command to create another downward ramp.

## Installation

Put `deep-caves_0.2.2.zip` and Cave Walls 0.1.13 or later in Factorio's mods folder and remove older Deep Caves ZIPs. Start a new world for this experimental terrain. Keep the stable mod and your previous save separately to revert.

## Prototype limitations

Power transfer uses hidden paired 40 MJ buffers with a 12 MW flow limit. It does not join the two surfaces into one literal wire network or carry circuit signals between levels. Ramps support local circuit wires as native poles do. Cave walls use the Cave Walls mod's `cave-wall` terrain; terrain, density and art are still prototypes. Fluid transfer and custom ores are not implemented.

## 0.1.25 solid cave walls

- Requires Cave Walls 0.1.9 or later. New cave chunks use `cave-wall` instead of native voids, enabling its robot/projectile interception and standard gun, laser and flamethrower turret sight checks throughout caves.
- Existing generated cave voids convert automatically once on update. Floors, factories and ramp inventories are preserved; cave layouts are not rerolled. Nauvis and other surfaces are not converted. The first load may take longer while collision helpers are created.
- Ramp landing carving updates wall collision helpers immediately. Legacy widening and void repair are removed in 0.2.2; `/cave-fix-voids` is no longer available.
- Cave Walls remains a required dependency after conversion. Its brush can still paint or erase walls; generator-created walls have no saved original terrain, so erasing them with the brush restores stone-path.

## 0.1.16 cool sky light and rain through surface openings

- Level 1 up ramps leading to Nauvis emit cooler blue daylight. Existing lights are recolored in place; the day/night cycle remains, with darkness at night.
- With Surface Thunderstorm 0.1.2 or later, those openings brighten and flash white using the same lightning pulse as the surface, including nighttime strikes. Updates run every three ticks so the short double pulse is visible.
- A looping, elliptical rain/splash overlay is confined to the ramp's three-tile artwork. Rain is blue in normal light and briefly whitens during lightning.
- These effects are only for Level 1 up ramps that lead to Nauvis. Down ramps, surface ramps and deeper up ramps remain unaffected.
- Turning the surface storm off removes the localized rain and lightning while retaining blue daylight. Without the weather mod, normal blue daylight works without a mandatory dependency.
- Install the companion surface-thunderstorm_0.1.2.zip update for synchronized weather.

Verified in Factorio 2.0.76 headless: blue daytime lights, darkness at night, a localized native rain animation only on Level 1 up ramps, white night flashes, matching first/second/fading lightning pulses, storm-off cleanup and reuse of render objects. With no weather mod, an existing light recolors blue without replacement; a populated older save retains ramp pairing, inventory identity and contents. In-game visual appearance remains a player check.

## 0.1.15 desolate Nauvis

- Removes every resource deposit on Nauvis, including ores, coal, stone and crude oil, in existing explored terrain and newly generated chunks. Surface mines/pumpjacks remain but have no deposit to extract.
- Replaces natural surface land with irregular cracked ash, parched soil and dusty sand. Removes green trees and decorative vegetation, retaining native boulders, cliffs, lakes and sparse mineable dead trees.
- Player buildings, inventories, paving, landfill/foundations, ramp pairs and power connections remain. Natural ground hidden under paving is also changed, so removing the paving reveals wasteland.
- Other planets and underground resource deposits are untouched. Cave generation adds native crude-oil wells from Level 2 onward, with increasing yields at depth, in newly explored cave chunks.
- This update converts existing Nauvis terrain on load; it can briefly pause on large saves. Surface resource removal is intentional and does not delete the miners or items already in their inventories.

Verified in Factorio 2.0.76 headless: startup and new-chunk Nauvis resource counts are zero; explicit ore/oil/tree conversion preserves a chest and its contents, concrete, hidden ground, and water; repeated processing does not duplicate dead trees; Levels 2/6 have intact ores and native pumpjack-compatible oil wells. A populated older save retained inventory identity, contents, pairing and 8 MJ of bridge energy. An unrelated test surface kept its ore and grass unchanged.

## 0.1.14 water, resources, inhabitants and natural entrances

- Rocky pits replace down-ramp artwork, and rising rubble piles replace up ramps. Four orientations remain; inventories, power and travel behavior are unchanged. Original generated source images are included under graphics/natural-sources; ASSET_NOTES.md records the prompts and sprite packing.
- Cave floors mix natural stone, dirt and sandy patches, darkening with depth. Existing natural cave floors receive the texture mix once; paving and structures remain.
- New chunks gain irregular pools in chamber-side bays. Pools do not replace the underlying connected dry passage network.
- Chamber ore patches contain iron, copper, coal and stone; uranium joins the selection at Level 4. Amounts grow with depth. Ore patches are sampled globally so they continue across chunk edges; exhausted resources do not respawn.
- Native biter/spitter nests are scattered through new chambers, becoming more common with depth. Worm defenses start at Level 3, with medium worms at Level 6 and big worms at Level 10. Initial nests avoid ramps and established factories. Cave peaceful mode follows Nauvis.
- Existing caves are not retroactively flooded or populated with ores/enemies. Explore new areas for those additions. Rocks avoid ore patches so the deposits remain visible; rocks, ores and nests are not repopulated after clearing.

Verified in Factorio 2.0.76 headless at Levels 1/6/12: mixed floor types, water, native offshore pump placement, all standard ores (uranium starting at Level 4), enemy spawners, connected dry route interiors, and no script respawn of cleared nests. Paired inventory contents and bridge energy transfer passed; a return landing near a preexisting nest relocated while retaining the nest. A populated older save retained inventory identity, 37 coal, pairing, 8 MJ of bridge energy, and its established cave floors. Native sprite/prototype loading passed; visual appearance still needs an in-game look.

## 0.1.13 remote map browsing

- Automatic ramp travel only runs in the character controller. Map/remote-view cameras can inspect ramps on any level without triggering a teleport.
- Ramp proximity uses the actual character entity's position and surface.
- Layer activation and the depth HUD use the physical player's surface, so browsing another layer does not count as entering it.
- Normal walking travel, inventory GUI pauses, cooldowns, paired inventories and power remain.

Headless regression checks passed in Factorio 2.0.76 using native ramps and a character with simulated player camera/controller state: cross-layer and same-layer browsing stay in place, the HUD follows physical depth, viewing a cave does not activate it, and walking travel plus cooldown still work. Native map UI interaction requires an in-game check.

## 0.1.12 winding root networks

- New ramp candidates are reduced by 50% on Nauvis and every cave layer. Each down ramp retains its corresponding up ramp; guaranteed starting ramps remain.
- Fine branches merge into larger branches and widely spaced trunks. Multi-scale displaced, smoothed curves replace the small east/south chamber grid. Chamber shapes and tunnel widths vary smoothly; disconnected square pockets are removed.
- Deeper passages remain narrower, with a minimum two-tile tunnel radius before terrain correction. Rocks can still require mining.
- Landing access paths follow winding spurs to the connected cave network.
- Existing terrain, ramps, inventories, wiring and structures are retained. The new terrain and lower ramp density apply to unexplored chunks. Existing cave openings receive connecting spurs into new terrain at upgrade boundaries. Previously carved floors and paving in queued chunks are preserved too.

Verified in Factorio 2.0.76 headless: connected interior terrain at Levels 1/6/12, roughly half-density ramp placement, winding entrance access, and populated-save migration preserving cave floors, shared inventory identity, contents, pairing and stored energy. Boundary-spur centerlines remain open after new chunks generate. Separate Lua checks verified identical terrain when querying chunks in reverse order, a 49.83% ramp-candidate acceptance rate over 40,000 chunks, and no enclosed disconnected floor components in 640 by 640 tile previews at all three depths.

## 0.1.11 protected ramps and chained power

- The full 3 by 3 tile ramp footprint blocks structures, belts and rails while remaining walkable.
- Its shared inventory fills that footprint. Normal inserters placed immediately outside can load/unload through any edge.
- Wire reach is adjusted to 2.75 tiles from the center, so an adjacent pole can connect without being built on the ramp. The blue supply area remains 2 by 2 tiles underneath the artwork.
- Power pooling now follows connected local wire networks and ramp pairs transitively. Multiple depths, branches, return routes and loops can carry power in either direction. Disconnected local networks remain isolated, and rewiring updates the graph every five ticks.
- Pooling conserves stored energy; pairing a previously charged ramp no longer clears its buffer. Existing inventories and power buffers retain their identity on upgrade.

Verified in Factorio 2.0.76 headless: building restrictions and walkability; adjacent poles on aligned and off-grid ramps; surface solar powering Level 3 and Level 3 generation powering Nauvis; loop energy conservation; isolated networks; stopping after a local wire cut and recovering after reconnection; real powered inserters loading/unloading at the ramp edges; and populated-save inventory and energy preservation.

## 0.1.10 short-range ramp terminals

- Copper and circuit wire reach is 1.75 tiles (roughly one adjacent tile with grid placement tolerance), and supply area distance is 1 tile (a 2 by 2 tile blue square underneath the artwork).
- Existing out-of-range ramp wires are disconnected on upgrade. Place a pole immediately beside each ramp to reconnect it to your local grid.
- Cross-level power and paired inventories retain their existing behavior.

## 0.1.9 integrated power ramps

- The visible ramp is now a native electric-pole entity with ramp artwork and wire anchors.
- Clicking its electrical GUI redirects to the existing shared inventory. Inserters still target the invisible container at the ramp center.
- Existing ramps migrate to the new entity type; pair references, container identity and contents, stored bridge energy and existing pole wires are preserved. Old helper poles are removed and the power buffer moves invisibly inside the ramp.
- Terrain carving and generation no longer delete colliding entities, protecting existing ramp inventories as nearby chunks develop.
- Verified in Factorio 2.0.76 headless: new-map loading, populated 0.1.8 save migration, native copper-wire connections, shared inventory access, solar power transferred to a cave lamp, and electrically powered inserter transfer with item conservation. Visual wire placement and clicking the inventory GUI still need an in-game check.

## Earlier changes

## 0.1.1 fixes

- Corrected base rock prototype names to `huge-rock` and `big-rock`.
- Disabled inherited rock autoplace on entrances; only portal scripts create them.
- Enabled unit-number lookup for entrance registry entries.
- Corrected zip and root-folder naming to match `deep-caves`.

## 0.1.2 fixes

- Entrance prototypes now use `simple-entity-with-owner`, which supports the unit numbers used by portal pairing. The rock graphics are preserved.

## 0.1.3 passage and entrance changes

- Added half a tile to each side of procedural tunnels (one tile total width).
- Connected underground entrance pads to their nearest chamber with a clear access tunnel.
- Added a second surface entrance about 96 tiles west of spawn, in addition to exploration entrances. All entrances at a given depth share one cave surface; each has its own paired return endpoint and logistics.
- Existing saves widen already generated cave terrain and repair entrance access on upgrade, preserving buildings and existing floors. There may be a brief pause on large saves.
- Factorio 2.0.76 headless checks passed: map creation, distinct surface entrances sharing Level 1, character-sized access from test entrance pads at depths 1/2/3/12, and old-terrain widening preserving a building and its contents.

Install: remove the previous Deep Caves zip and put `deep-caves_0.1.3.zip` in the mods folder. Load your existing save to apply the passage update.

## 0.1.4 excessive entrance density

- Attempts one downward entrance per generated 32x32 chunk on Nauvis and every cave depth, including the spawn area. Water, occupied terrain, and chunks without cave floor can prevent placement.
- Existing explored chunks receive the same dense entrance pass once when upgrading. Each processed chunk is recorded to prevent repeat placements.
- All entrances between the same depths share the same destination surface, with individually paired return exits and logistics. Return ends appear when an entrance is first used.
- Access tunnels are prepared when an entrance is used; unused entrances do not recursively generate more terrain.
- Fixed cave-floor search to inspect every candidate instead of repeatedly checking a small subset.
- Factorio 2.0.76 headless validation passed: 192 surface entrances, 41/34/35 downward entrances in sampled Levels 1/2/3, shared destinations with separate return pairs, linked belts, repeat-upgrade idempotence, and no idle terrain expansion.

Install this version in place of the older zip and load the existing save. The first upgrade may pause briefly while adding entrances. This density is deliberately excessive for testing.

## 0.1.5 ramps, navigation, and stone floors

- Replaced entrance rocks with stone ramps in four deterministic cardinal orientations. Green UP ramps rise; amber DOWN ramps descend. Arrow and UP/DOWN markings remain visible on the sprites.
- Each ramp displays its destination and has an UP/DOWN map tag. The top HUD shows Surface / Cave Level N continuously.
- Ramp graphics are original SVG shapes matching the supplied slope sketch, rasterized for Factorio. SVG sources are included alongside PNGs.
- Cave floors use the base stone-path texture, progressively tinted darker over Levels 1–12. Deeper levels retain the darkest tone. Walking speed remains normal.
- Existing entrance entities retain their unit numbers, pairing, and logistics. Dirt cave floors are retextured on upgrade; player-placed paving and buildings are retained.
- Headless Factorio 2.0.76 checks passed for loading, four orientations, destination labels/map tags, pairing, linked belts, and floor migration preserving buildings/items. HUD text updates were checked with a mock player; visual UI appearance and ramp art still need your in-game check.

Replace the previous zip and load your existing save. Cave geometry and the deliberately excessive entrance density remain as in 0.1.4.

## 0.1.6 natural ground and mineable rocks

- Removed all downward floating destination text and DOWN map tags, including existing ones. Ramp art and the depth HUD remain. UP labels and tags remain for navigation.
- Replaced the cobblestone base texture with the base game's rough cracked natural ground texture (`nuclear-ground` graphics only); depth-dependent darkening remains. There is no radiation mechanic.
- Added native `big-rock` entities that mine into stone. Candidate placement density increases from 7% at Level 1 to 100% at Level 12 and deeper. Actual coverage depends on cave geometry, existing structures, and clear ramp pads.
- Existing explored cave chunks receive rocks once on upgrade. Mined rocks do not respawn; placement checks protect buildings and paving. New chunks use seed/depth/coordinate-driven placement.
- Ramp landing areas are cleared; first-use access tunnels to nearby chambers are also cleared. Other deep passages can require mining.
- Factorio 2.0.76 headless checks passed: rock density per floor tile increased at sampled Levels 1/6/12, mining yielded stone, repeated upgrades did not respawn rocks, ramp pads stayed clear, and downward labels were removed while upward navigation remained.

Replace the older zip and load the existing save. The first upgrade can pause while populating already explored caves.

## 0.1.7 daylight at surface exits and prepared return ramps

- Level 1 UP ramps that lead to Nauvis emit a warm daylight pool. Light follows Nauvis day phases, fades through sunset, switches off at night, and fades back at sunrise. It needs no electricity.
- Deeper UP ramps receive no surface daylight. Ambient cave darkness, natural ground, rocks, ramp graphics, and the depth HUD remain.
- Downward entrances now receive their matching UP ramps in bounded background batches (two pairs every ten ticks), before use. Existing unpaired entrances are handled as well.
- Generating a paired return end suppresses independent downward entrance spawning in its generated chunks, avoiding recursive creation of infinitely deeper surfaces. Exploring/entering a cave layer activates its downward entrances; each still has a distinct return pair into the shared layer below.
- Current saves retain existing pairs and logistics. After loading, newly prepared return ramps appear progressively.
- Factorio 2.0.76 headless checks passed: multiple return ramps present before travel, daylight at day/sunset/night and restoration after sunrise, deeper ramps unlit, retained linked-belt pairing, and no recursively generated deeper surfaces.

Install in place of the previous zip and load the existing save. Visual light radius and brightness still need an in-game look.

## 0.1.8 ramp inventories replace belts

- Removed remaining UP floating text and map tags; ramp UP/DOWN art, the depth HUD, and surface daylight remain.
- Each ramp pair now owns a private shared 48-slot linked-container inventory. Items inserted at either end are immediately available at the matching end. Other ramp pairs have separate inventories.
- Click the ramp to open its native inventory GUI. Aim inserter pickup/drop positions at the ramp center (the inventory is one tile wide; the ramp art is wider). The hidden container is selectable over the ramp artwork, while the art entity is not selectable.
- Teleporting is paused while a GUI is open so inventory interaction does not immediately change levels.
- Old built-in belt lanes are removed on upgrade. Items on those lanes are moved into the ramp inventory; any overflow is dropped at the former lane position. Existing player-built belts and inserters are not removed.
- Electrical bridges, pairing, daylight, cave geometry, and rocks remain.
- Factorio 2.0.76 headless checks passed: load/new-map creation, shared inventory insertion/removal, pair isolation, 48-slot capacity, old belt item preservation, removed labels, and actual burner-inserter transfer from a surface chest through the paired ramp to a cave chest with all items conserved.

Replace the previous zip and load your save. Reposition logistics to load/unload the ramp center instead of the former two belt lanes. Inventory GUI appearance still needs an in-game check.

## 0.1.17
Cave pools use native shallow water: walkable at 80% speed, with splashes, and blocked for ordinary structures. Existing cave water converts on upgrade; Nauvis water stays unchanged. New cave chunks have more frequent and larger pools, while the original dry tunnel network remains connected. Existing explored floors and factories are preserved. First-level opening effects also check the actual ramp surface. Install Surface Thunderstorm 0.1.3 for muffled first-level rain; it remains optional.

## 0.1.18: surface return coverage
Exploring Level 1 now generates matching Nauvis columns and pairs their normal surface entrances into Level 1 UP ramps. Previously those ramps stopped at the edge of generated surface terrain. Existing explored Level 1 chunks are backfilled in bounded batches, prioritizing characters underground. Nearby generated chunks are checked even if their original generation happened during a suppressed pairing request. Existing pairs, inventories and power buffers are retained; the half-density surface candidate rule remains. Pairing-generated padding does not recursively queue more columns, and no extra cave layers are generated by return coverage.

## 0.1.19: partly flooded strata
Levels 2, 5, 8, 11 and every third level after that have broad irregular shallow-water stretches covering roughly half their passage footprint. This uses a deterministic world-space water mask across chunk edges. The water remains walkable but blocks structures; native pumps still work. Ramp creation clears dry landings and access spurs. Other depths retain their normal mixed dry floors and side pools. Only newly generated terrain changes; existing explored floors, paving, ore patches and factories are preserved.

## 0.1.20: fixed ramp artwork
UP and DOWN ramps each have one sprite and one wire attachment point. Power-pole auto-orientation cannot select another visual direction. Ramps cannot be manually rotated; old direction metadata is cleared on upgrade. Travel exits at a fixed offset with the normal collision-safe placement and cooldown. Existing entities, pairs, inventories, wires and energy buffers are retained.

## 0.1.21: clearer cave water
Cave shallow water now uses the regular opaque water sprites and animated water effect rather than the rocky shallow-water bed artwork. The secondary water color is cool blue; native shoreline transitions include the custom water. Wading speed, splash sounds, walkable collision, building restrictions, water fluid/pumping and flood distribution stay the same. Existing pools redraw automatically on load because their tile name is unchanged.

## 0.1.22: one-tile void repair
On the first load after this update, all generated cave chunks receive one snapshot repair pass. An out-of-map tile becomes floor when at least three cardinal neighbors are open, or its north/south or east/west pair is open. Diagonals and two adjacent sides do not count. Repairs span chunk borders, fill watery gaps with shallow water when wet neighbors dominate, and only replace void tiles. Existing non-void floors, paving, buildings, resources, ramps and inventories stay in place. Ungenerated chunks and Nauvis are excluded. The saved completion flag prevents repeating the scan on later loads; the admin command /cave-fix-voids runs another single pass on demand.

New cave chunks use the same rule on the original procedural floor/water masks, including the neighboring chunks' masks. This is independent of generation order and does not generate those neighboring chunks. The rule makes one simultaneous pass rather than recursively widening walls. This update includes the existing-world repair, so it needs no additional temporary mod or new save.

## 0.1.23: filtered 12-slot ramp inventories
Each pair shares one 12-slot inventory with native cargo-wagon-style item filters and the inventory limiter bar. Slots start unfiltered; set or clear them through the normal inventory GUI. Filtering one endpoint changes the same shared inventory at the other endpoint. Inserters respect the reserved slots and normal stack sizes. Other ramp pairs retain separate inventories.

Existing 48-slot inventories migrate into a new prototype so the game cannot truncate their contents before the script runs. The migration compacts and transfers each shared inventory once, preserves the pair's link ID and limiter setting (clamped to the new capacity), and spills excess stacks beside one endpoint on the dry pad outside the travel trigger. Ramp entities, wires and power buffers remain. The old 48-slot prototype is retained invisibly only for save migration. The saved migration flag prevents duplicate transfers on later loads.

## 0.1.24: deliberate ramp travel and upper wire attachment
Travel activates only when the character's position enters the single terrain tile containing the ramp's center. Adjacent tiles, including diagonal corners, no longer trigger travel. Existing cooldown, GUI and remote-view protections remain. Up-ramp copper and circuit wire attachment points now sit on the top of the rock pile; down-ramp attachment points remain in their previous position. Existing ramps pick up both changes on load.

## 0.1.26 performance diagnostics

- `/cave-diagnostics start 10` samples ten simulation seconds of cave work, then prints timing totals, average per call and average per simulation tick for terrain, rocks, resources/enemies, ramp placement, background pairing/returns, player travel/activation, power, lighting and HUD updates. Reproduce the lag during the sample. With low UPS, ten simulation seconds take longer than ten real seconds. `/cave-diagnostics stop` prints early; `status` gives an immediate population snapshot. Timings are transient and a save reload ends sampling. Timings never influence gameplay; no recurring profiler overhead exists outside a sample beyond simple function guards.
- Reports list generated chunks, ramp counts, unpaired ramps, wall helpers and enemy units on Nauvis and each cave layer, plus queued surface columns. Inclusive timings can overlap when pairing forces chunk generation, so do not sum them. Profiling counts time inside synchronous Cave Walls integration but cannot attribute other mods, rendering or native engine entity/pathfinding updates; use F4 -> show-time-usage for those.
- `/cave-background off` pauses automatic preparation of unused ramp pairs and surface-return columns across all layers. Existing paired ramps, power, inventories and travel remain active. Walking onto an unpaired ramp still generates its destination, and exploration still generates new chunks. This diagnostic mode can delay additional surface up ramps until re-enabled. `on` resumes the queues; `status` prints the switch. Default is ON; changes persist in the save.
- Changing diagnostic switches or starting/stopping profiling requires an admin. Status is available to everyone. No cave layouts are regenerated and no world restart is needed. Keep Cave Walls 0.1.11 installed and replace only Deep Caves with 0.1.26.

## 0.1.27 local background preparation

- Background pairing selects the closest unpaired down ramp within 64 tiles of a player's physical character, on that character's surface. Empty layers and distant unused ramps no longer request destination chunks.
- Pairing and surface-return work share one expensive job per 30 ticks across all players, rather than running two pairs and two columns every ten ticks. Failed landing searches wait five seconds before background retry, instead of hammering occupied landing sites. Stepping onto a ramp bypasses that background delay and still creates its pair on demand.
- Surface returns process only queued Level 1 columns within 96 tiles of characters currently on Level 1. Nearby lookups replace a scan of the entire pending map. Distant queued columns are retained until visited; there is no fallback global backfill while everyone is on Nauvis or deeper levels. Missing Nauvis columns generate asynchronously rather than flushing all pending Nauvis chunk requests.
- Existing paired ramps, shared inventories, wiring and cave terrain remain unchanged; no restart or cave reroll is required. Cave diagnostics and background ON/OFF switches remain available. Background preparation must be ON for local prefetch/return backfill; normal exploration and direct travel still work when OFF.
- This limits speculative terrain generation. Exploring new areas or using an unpaired ramp can still trigger generation and cause a brief pause; it does not eliminate native generation work or engine overhead.


## 0.1.28 performance update

Ramp power pools cache their topology for up to one second, with immediate invalidation when new ramps pair. Energy still transfers every five ticks; idle empty buffers are not rewritten. Pole rewiring is reflected within one second. Entrance lighting/rain animate only within 192 tiles of a connected player physically on Cave 1; distant effects are hidden and reactivate on approach. No terrain reset or inventory replacement.


## 0.1.29 dark caves and entrance puddles

All existing and new cave surfaces have zero ambient brightness and a matching darkness color multiplier. Character/car lights, lamps and Cave 1 entrance daylight still illuminate their surroundings. Surface lighting is unchanged. Small walkable, non-buildable puddles form just south of the surface-return ramps on Cave 1, outside the ramp footprint. Existing structures, resources, rocks and paving are skipped. Existing entrances update ten at a time every half-second; new entrances receive puddles immediately. The patch preserves puddles during later ramp access carving. No world restart needed.


## 0.1.30 flooded depths

Cave 5 and deeper use broad shallow-water regions covering approximately 80% of unprotected open terrain, with irregular dry islands. Levels 1–4 keep their existing water distribution. New access paths preserve deep water, and ramps retain dry landing pads. Existing generated deep chunks convert incrementally, one chunk every five ticks. Paving, structures, ores, rocks, and a seven-tile radius around ramps are preserved, so developed areas remain drier. Water stays walkable and non-buildable. No restart required; a large explored bottom level can take around a minute to finish updating.


## 0.1.31 final Cave 5

The playable cave progression ends at Cave 5, which remains mostly flooded. No natural, debug-created or paired downward ramps can lead below it. Existing downward ramps leading below Cave 5 are removed; any items in their shared inventory are moved once into ordinary steel chests at the retired ramp positions. Their lower counterpart inventory is emptied as part of that move, avoiding duplication. Other paired ramp inventories are untouched. Legacy deeper surfaces/factories remain intact; their upward ramps lead to the nearest Cave 5 return ramp so stranded players can escape. They are not deleted, and old deeper surfaces are not newly generated by this mod.


## 0.1.32 underground enemies

Nauvis has natural enemy spawning disabled and enemy-base autoplace disabled. Existing enemy-force units, nests and worms on Nauvis are removed once on upgrade, without death events or danger barriers. New surface chunks and expansion-built surface nests are also cleaned. Cave surfaces keep natural spawning enabled.

Settings -> Mod settings -> Map: Cave enemy nest density multiplier. Default 3 gives three times the old chamber nest probability, capped at 100%. 1 restores the old density; 0 disables new nests; maximum 10. The setting changes nest placement in newly generated cave areas, rather than each existing nest's native unit production rate. Existing cave enemies are preserved, cleared chunks do not respawn nests, and the existing 22-tile ramp/20-tile factory safety margins remain. No world restart needed.

## 0.2.0 three-pass experiment

Start a new world and disable older Deep Caves versions. Keep Cave Walls installed. This is a separate experimental release; the stable 0.1.32 ZIP and old saves can be restored to reverse it.

1. Large, irregular chambers with overlapping lobes.
2. Winding three-tile connectors and smaller pockets.
3. One-tile cardinal branches and occasional cross-links creating loops.

Generation is deterministic across chunks. Cached path geometry and bounding boxes avoid rebuilding distant paths. Rocks require a clear five-tile footprint; fine branches are excluded from automatic one-tile wall repair. Ramp candidates require nearby floor space. Five levels, the flooded final cave, darkness, resources and enemy density settings are retained.

The included layout preview colors large rooms tan, narrow passages gray and one-tile branches blue. These are explanatory colors, not in-game tile colors.

## 0.2.1 branching trunks and enemy placement

Broad winding cave ribbons replace isolated round chambers. Medium five-tile branches and one-tile loops fill the spaces between trunks, following the reference sketch. Pools remain attached near trunk junctions.

Cave enemy nest density now ranges from 0 to 100, default 10. Enemy positions are sampled independently across cave floors instead of allowing only one nest at a chamber center. Nine nearby alternatives are tried; ordinary rocks may be cleared for successful nests, while failed attempts restore them. Dry terrain, ramp and factory safety margins remain. Native per-nest unit production is unchanged.

Changing the setting queues explored cave chunks at one chunk per second. `/cave-populate-enemies` retries the current density without requesting terrain or duplicating occupied sites. Existing nests remain when density is lowered.

## 0.2.2 configurable overlay meshes

Three separate winding network meshes now overlap, with six Startup settings for their density and nominal width. Density means approximate nodes per 256 tiles along each axis; increasing it gives closer nodes and more tunnels. Defaults: large density 1 / width 12; small density 4 / width 3; web density 10 / width 1. Startup changes require a Factorio restart. Start a new world for every layout comparison; existing terrain is not redrawn.

The old void repair module, command and tile-by-tile hole-filling pass have been removed. Legacy passage widening and boundary stitching are no longer invoked. Entrance connection paths remain. Native entrance artwork now uses a stationary floor-layer visual instead of pole artwork in the object layer, allowing characters to draw above it.


## 0.2.3 carved enemy nest caverns

Enemy placement no longer requires a pre-existing clear 5x5 patch. Accepted sites find a nearby existing tunnel, choose a rock-facing side, and carve a small dry nest cavern with a narrow connecting spur before placing the native biter or spitter spawner. The three configurable cave meshes themselves are unchanged.

Ramp and player-entity safety checks run before excavation, retaining the existing 22-tile ramp and 20-tile factory margins. Natural rocks inside the new pocket may be removed; resources and player structures are never deliberately cleared. Cave enemy density remains the runtime 0–100 setting, default 10, and changing it still queues explored chunks for repopulation attempts without removing existing nests.


## 0.2.5 lower enemy density

Cave enemy nest density is configurable under Settings -> Mod settings -> Map, with default 2 and range 0–10. Existing saves can retain their previous setting: set it to 2 there to reduce future nest placement. Existing nests are retained. Cave meshes and nest-carving logic are unchanged.


## 0.2.6 cave dripping ambience

All underground levels have occasional water droplets with a short echo, at random nearby positions about every 2–6 seconds per player. No dripping on the surface or while viewing another surface remotely. Settings -> Mod settings -> Per player -> Cave dripping volume adjusts or mutes them (default 0.7). The enemy density default remains 2, maximum 10. Meshes and enemy placement are unchanged.


## 0.2.9 enemy expansion density fix

Native enemy expansion is now suppressed on cave surfaces as well as Nauvis. Cave nests are created only by Deep Caves' scripted density placement, so the Cave enemy nest density setting is no longer bypassed by expansion-built bases. Existing nests are not removed by this migration. Units spawned normally from retained scripted nests are unchanged.


## 0.2.10 enemy density control rewrite

- `Cave enemy nest spawn rate` is now a Startup mod setting, making it visible before world creation. Default 0.1, range 0-10.
- Enemy placement now makes exactly one deterministic nest roll per generated 32x32 cave chunk instead of sampling a 12-tile grid.
- Scripted nests require a 24-tile separation, preventing dense clusters across neighboring chunks.
- At density 0.1 the per-chunk chance is 0.3% on Level 1, rising to 0.7% on Level 5. Density 1.0 gives 3%-7%.
- Added `/cave-enemy-density` to print the active density and current nest count on each generated cave level.
- Native expansion-built cave bases remain suppressed.


### 0.2.13
Resource progression is now explicit: Level 1 contains iron, copper, stone and coal (with coal still the most common); crude oil begins on Level 3; uranium begins on Level 4. Oil generates as isolated mineable wells rather than ore-tile patches. Existing explored cave chunks are eligible for the new resource-version backfill.


0.2.14 adds a Level 1 starting safe zone. A 160-tile circle around the first Level 1 return ramp contains no enemy spawners, worms, or units; scripted nest placement rejects the area and a lightweight periodic cleanup prevents wandering biters from camping the entrance. Deeper cave levels are unchanged.


0.2.15 shrinks the Level 1 starting nest exclusion to 64 tiles and makes it nest-only: wandering units and worms are no longer deleted. Level 1 enemy expansion is allowed outside the exclusion circle. Four guaranteed starter deposits (iron, copper, coal and stone) are script-placed on carved 7x7 floor pads with centered 5x5 ore patches of roughly 6k resources each.


0.2.16 moves the four guaranteed Level 1 starter deposits to fixed sites near world (0,0). Each iron, copper, coal, and stone starter site forcibly lays a 5x5 cave-floor pad, clears natural rocks/resources from that pad, and places a centered 3x3 deposit of roughly 5k total resources. This placement is independent of natural cave crevasses.


0.2.17 fixes random cave entrances disappearing away from the starting region. Chunks force-generated while creating paired return ramps used to skip their entrance roll permanently. Every cave chunk now receives the normal deterministic downward-entrance roll on first generation; the pair-generation guard remains only for Level 1 surface-return queue work.


0.2.18 changes cave enemy density to a literal per-chunk overlay probability. A setting of 0.1 means a deterministic 10% of eligible cave chunks receive an initial scripted nest. Successful rolls carve their own small nest cavern and access spur instead of depending on a pre-existing clear pocket or nest-spacing filter. The Level 1 starter nest exclusion remains in effect.
