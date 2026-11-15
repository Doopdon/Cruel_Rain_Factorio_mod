# Cruel Rain 0.3.3 integration record

Internal mod ID and entity identities remain deep-caves. Original content
remains MIT licensed; the Water Drops recording retains its separate Pixabay
license and credits in THIRD_PARTY_NOTICES.md.

## Configuration

Independent Startup research and rocket multipliers accept 0.01 to 100 and
default to 0.1. Fixed unit counts and rocket parts round up, minimum one.
Infinite formulas are multiplied and clamped to one. Ingredients, time per
unit, recipe requirements and research triggers retain their existing values.
Surface-only silos default on and can be disabled. The script handler and
native Space Age conditions both follow the toggle.

## Fluid connections and collision

Native tank helpers retain their 1,000-unit capacity per end and saved identity.
Pipe offsets are one tile instead of two, placing adjacent pipe centers two
tiles from the helper grid center. The helper suppresses pipe covers, pipe
pictures, blue connection information and fluid icons using the exact 2.0.76
prototype fields. The visible ramp collision and selection box is reduced to
0.99 tiles in each direction; its center remains protected. The invisible
cargo container retains its 1.49-tile inserter target area with no collision
layers, allowing closer pipes beside off-grid ramps.

Existing outer pipes are preserved; adding a pipe in the new inner position
reconnects them. Native filled-save tests verify no loss or duplication of
water, cargo, filters, energy or wires. A new world is not needed.

## Verification

All 68 Lua assertions pass (51 generation, 5 integration, 5 GUI, 7 silo).
All 70 named native assertions across six save/reload profiles pass.
The profiles cover fresh and upgraded fluid networks, all four close ports,
old-pipe adapters, fluid capacity/temperature/conservation/conflicts, custom
0.5 research and 0.2 rocket costs, restored normal costs, minimum 0.01 costs,
and Space Age with cave silos enabled. Research comparisons cover 198 base
technologies or 277 with Space Age. Actual final rocket-part crafting passes.
Default 0.3.2 costs retain 40% current research on upgrade; a reduction from
10 units to 5 retains four invested units as 80%. Earlier reduction below
invested units resets progress. Finish current research before changing costs.

Current reports: tests/engine-results-0.3.3.txt and the four Lua result files.
Older release records are historical evidence, not reruns of all prior suites.
An additional native burner-inserter check confirms cargo transfer after the
collision clearance change.

Client appearance, sound and live multiplayer still require gameplay QA.

Primary API: https://lua-api.factorio.com/2.0.76/prototype-api.json
