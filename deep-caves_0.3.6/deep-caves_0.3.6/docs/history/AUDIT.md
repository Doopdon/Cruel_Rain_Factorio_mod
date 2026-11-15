# Deep Caves 0.2.19 spawning audit

The supplied 0.2.18 mod contained real placement failures that became much
more visible with sparse meshes and narrow tunnel widths. This release fixes
them and includes runnable regression tests.

## Findings and fixes

| Finding in 0.2.18 | Change in 0.2.19 |
| --- | --- |
| Ramp sites required natural floor three tiles away in all four directions. One-tile tunnels almost never qualified. | Search the whole chunk for a natural tunnel tile, carve a landing, and connect it to that tunnel. Failed old completion marks are revisited once on upgrade. |
| Starter resources were attempted during setup while Cave 1 could still be absent. | Prepare the primary entrance pair during setup; complete the starter deposits when Cave 1 exists. |
| Fixed starter pads could be disconnected from the landing or overlap a return ramp and its protected puddle. | Connect all four pads to the actual initial landing and reserve the pads when choosing random ramps and return landings. |
| Ore centers were searched only within a local window, missing edge-only tunnels. Oil also lacked a full footprint in narrow tunnels; water excluded solid deposits. | Search the whole chunk and provide small connected dry side pads for oil and wet-only sites. Interior pad search handles corner tunnels beside ramps. |
| Failed entity creation was marked complete, and a partially successful two-patch pass hid the other failure. | Mark completed work after success; retain progress separately for each patch so retries preserve finished deposits. |
| Nest caverns with no nearby dry tunnel could be isolated. | Connect to the nearest of the three mesh networks. Access segments through unseen chunks are saved and painted during later exploration, then removed from storage. |
| Enemy backfill forced every explored chunk through placement again, recreating destroyed nests. | Ordinary backfill respects successful completion marks at the same density. |

The safe center is available before the first Cave 1 chunks populate. Nest
placement avoids existing ores as well as ramps and player structures, and
clears natural rocks from access paths. New caves retain normal native
spawners; Level 1 native expansion remains allowed outside its starter
exclusion, following the game's expansion setting. The original rule blocking
native expansion on deeper levels is retained.

## Validation

The original seven focused checks produced six failures against the unmodified
0.2.18 archive. The completed Lua suite passes **46 of 46** checks. It runs the
mod's real Lua with a small API substitute and tests minimum/default meshes,
all five depths, coordinates about 9,600 and 131,000 tiles from origin, 27
starter seeds, flooded tunnels, oil footprints, ore depth rules, failed and
partial placement, cleared nests, distant surface returns, pairing, generation
order, saved access paths, and read-only inspection.

Very low positive enemy density was checked over 16,384 chunk coordinates:
0.001 produced 15 nests and 0.01 produced 178. A zero density produced no
scripted nests. Separate bounded samples also verified 0.1, 0.5, 1 and 10.

Real-engine checks used **Factorio 2.0.76 headless with Cave Walls 0.1.13**:

| Preset | Mesh densities (large / small / web) | Widths (large / small / web) | Seed | Result |
| --- | --- | --- | --- | --- |
| Minimum | 1 / 1 / 1 | 1 / 1 / 1 | 0 | 13/13; save/reload and 600 ticks passed |
| Default | 1 / 4 / 10 | 12 / 3 / 1 | 0 | 13/13; save/reload and 600 ticks passed |
| Maximum | 8 / 16 / 24 | 48 / 24 / 12 | 17 | 13/13; save/reload and 600 ticks passed |

These checks use real terrain, collision helpers, ramps, nests, resource
entities and linked inventories. They verify starter tiles, character-sized
landings, native biter placement beside nests, distant surface-return pairs,
resource depth rules, completed-pass idempotence and cleared nests. Rare
resource checks additionally generate eligible seeded sites, since finite
random samples can legitimately omit oil or uranium. The tests never run in
ordinary saves; the Python runner installs hooks only in a disposable copy.

Headless checks cover generation and runtime behavior. Appearance, sound and
extended factory balance are playtest work. Existing art and audio assets were
preserved byte for byte.

## Spawn rules and use

Only the four starter deposits are guaranteed at fixed locations. Each is a
3x3 patch on a 5x5 pad near (0,0), containing about 5,000 resources. Outside
that area, spawn rolls and placement space still matter. Ramp candidates use
50% of natural-floor chunks. Scattered resources use about 45% of chunks;
solid-rock-only chunks need no deposit. Enemy density 0 disables initial
nests; 0.01 is about 1%, 0.1 about 10%, and all values >=1 saturate at 100%.
Protection for the starter nest circle, ramps, ores and factories still applies.
Oil starts on Level 3; uranium on Level 4; Level 5 has no downward ramps.

Install the updated ZIP in place of the older Deep Caves ZIP. Use a new world
when comparing startup mesh settings. `/cave-check-spawns` reads nearby ramp,
nest and resource counts plus pair-link status without generating terrain.
`tests/README.md` explains how to rerun the suites; `tests/lua-results.txt`,
`tests/engine-results.txt` and `tests/baseline-0.2.18.txt` contain the results.
