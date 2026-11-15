# Cruel Rain 0.3.5 verification

Nest placement now multiplies the configured base rate by radial distance
from (0,0) and cave depth, with bounded multipliers of 4 and 3 respectively.
The final probability is capped at 1. Zero density still disables overlays.
Existing completion markers are preserved so upgrades and backfills do not
recreate cleared nests or add new threats to previously processed chunks.
The Level 1 safe zone and placement protections are unchanged.

Native biter/spitter nests and all worm sizes use empty collision masks.
Matching masks are required by Factorio's native enemy expansion logic.
They remain targetable and vulnerable, and retain their footprint and health.
Native placement checks verify that units and characters can occupy nest
footprints, including behemoth units. White coloring is retained.

Current reports are tests/lua-results.txt and tests/engine-results-0.3.5.txt.
Previous integration reports remain under docs/history.
