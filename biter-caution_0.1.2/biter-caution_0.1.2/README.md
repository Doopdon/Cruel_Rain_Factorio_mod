# Biter Caution 0.1.3

Standalone Factorio 2.1 mod. Install `biter-caution_0.1.3.zip` and load a new or existing save. No Deep Caves or Cave Walls dependency and no restart required. Works independently on each surface.

When an enemy-force unit dies, its 3x3-tile cell receives an invisible, indestructible pathfinding obstacle. Default lifetime is 600 seconds (10 minutes), rounded to the next second. Another death in that cell refreshes the timer instead of creating another obstacle. Adjacent deaths can form a larger avoided region. Expiration opens it again. These are hard barriers, so a completely sealed passage can make bugs wait until it clears; this first version does not model a soft path cost or coordinated intelligence.

A dedicated collision layer is added to native `unit` prototypes while preserving existing masks. Base biters and spitters, and modded units using that entity type, collide with the barriers. Characters, cars, tanks, trains, robots, projectiles and buildings do not receive the layer. Collision masks are per prototype, so friendly/player-owned units of those same prototypes are also blocked. Enemy deaths trigger cells; destroyed-but-not-killed entities do not. Spawners, worms, robots, other entity types and non-enemy forces do not trigger cells. Space Age segmented enemies are outside this prototype.

Barriers belong to the enemy force, are not military targets, cannot be selected/mined/blueprinted, have no loot and disappear without death events. They do not damage units, change terrain or stop bullets. Natural pathfinding chooses routes around them when a route exists. Units already overlapping a newly created barrier can be temporarily stuck; the timer provides recovery.

Runtime mod settings change the memory duration (5–3,600 seconds) and active-cell cap (default 2,048, maximum 8,192). Lifetime changes affect subsequent deaths; changing the cap does not delete existing cells. At the cap, new locations are ignored but existing cells can still refresh. Cleanup visits only the expiry bucket once per second; there are no per-tick world searches, chunk scans or unit repositioning loops. State and timers persist through saving/loading.

## Testing commands

- `/biter-caution show`: outline danger cells in orange; new cells are outlined too. Default is invisible. Outlines are a global debug view.
- `/biter-caution hide`: remove outlines.
- `/biter-caution status`: show active cell count, duration and enabled state.
- `/biter-caution clear`: remove all active cells.
- `/biter-caution off`: disable creation and remove existing cells.
- `/biter-caution on`: enable creation again.

Changes require an admin. Status is available to everyone. This mod has no research, item, brush or recipe. Existing deaths are not reconstructed when installing it; only new deaths create memory cells.


Upgrading from 0.1.0 changes the old 60-second default to 600 seconds and refreshes existing cells for the full ten minutes. Other custom durations are preserved.


## 0.1.3

Updated for Factorio 2.1 runtime APIs and tested in Factorio 2.1.24.

## 0.1.2

Enemy deaths within the configurable nest aggression radius (24 tiles by default) no longer create or refresh caution cells. If a caution cell already occupies that death cell, it is removed. This keeps defenders around enemy spawners aggressive while preserving the caution behavior away from nests. The radius is available under runtime-global mod settings.
