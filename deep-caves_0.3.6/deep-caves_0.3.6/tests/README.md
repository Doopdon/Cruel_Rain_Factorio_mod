# Cruel Rain 0.3.7 regression tests

Factorio 2.1.24 native validation passed the spawning, fluids, integration,
difficulty, vents, collisions, and water suites.

From the extracted mod folder, run:

```sh
lua tests/run.lua
lua tests/run_integration.lua
lua tests/run_ramp_gui.lua
lua tests/run_difficulty.lua
```

Lua 5.2 or later is sufficient; `texlua` also works. The generation suite has
51 named checks. Five integration checks cover shared event/lifecycle
registration, native-helper recovery, renamed-vent rain/thunder routing,
and remote-view suppression. Five GUI checks cover window switching, delayed
close events, removed ramps, stale buttons and cleanup. They use the actual
GUI handlers with small player/GUI API stand-ins. The lightweight substitute deliberately leaves
native wall collision, combat, prototype loading and actual rendering to
Factorio. It does not reimplement the generator.

## Native Factorio tests

Only Python 3 and your installed Factorio executable are needed. No separate
Cave Walls or weather ZIP is needed for new test worlds.

```sh
python tests/run_engine.py --factorio /path/to/factorio --preset minimum --seed 0
python tests/run_engine.py --factorio /path/to/factorio --preset default --seed 0
python tests/run_engine.py --factorio /path/to/factorio --suite vents --seed 17
python tests/run_engine.py --factorio /path/to/factorio --suite integration --seed 17
python tests/run_engine.py --factorio /path/to/factorio --suite integration --space-age --seed 17
python tests/run_engine.py --factorio /path/to/factorio --suite fluids --seed 17
python tests/run_engine.py --factorio /path/to/factorio --suite fluids --space-age --seed 17
python tests/run_engine.py --factorio /path/to/factorio --suite vents --absorption 0 --seed 17
python tests/run_engine.py --factorio /path/to/factorio --suite vents --absorption 25 --seed 17
```

The spawning suite has 13 checks across all five depths, two distant regions,
exact starter deposits, resource depth rules, native biters, return vents,
pairing and idempotence. The vent suite has five checks; only its temporary
fixture disables terrain absorption to isolate native negative emissions.
The integration suite has 14 checks for compatibility interfaces, vent
weather lookup, native render cleanup, robot/projectile creation and wall
crossing, all three standard turret types, brush erasure and exposure damage.
It keeps laser energy available to isolate targeting from power starvation.

The fluid suite has 13 native checks: filled-save preservation, legacy pipe
adoption, helper recovery, four-sided ports beside off-grid ramps, different
fluid protection/recovery, automatic pairing on pipe construction, native
inventory types, bidirectional flow, conservation, pair isolation, capacity
and steam temperature. Its save fixture contains 115 water, mixed-temperature
water, 37 coal, a slot filter, 8 MJ and copper/red/green wires before saving.
The vent suite runs at the configured rate; zero and a custom rate of 25 are
included in this release's verification.

To check a combined 0.3.0 save upgrade (no companions needed):

```sh
python tests/run_engine.py --factorio /path/to/factorio --suite fluids --upgrade-from /path/to/deep-caves_0.3.0 --seed 17
```

## Upgrade a disposable old save

```sh
python tests/run_engine.py --factorio /path/to/factorio --suite integration --upgrade-from /path/to/deep-caves_0.2.20 --cave-walls /path/to/cave-walls_0.1.15.zip --legacy-weather /path/to/surface-thunderstorm_0.1.9.zip --seed 17
```

This creates a save with the actual three older supplied mods, then removes
the two companions and loads the same world using only the combined package.
It retains a native vent, 37 coal, a slot filter, 8 MJ, copper/red/green wires,
42 wall boundary helpers, and a deliberately inactive turret. Two additional
upgrade checks give 16 integration checks for this run. It tests native save
state rather than assuming cross-mod Lua storage is transferred in 2.0.

All runners copy sources into disposable mod directories and simulate 600
ticks after reloading. Test modules and callbacks are injected only into
those copies. Normal mod loads never run the test suites. Choose
`--output /path/to/disposable-folder` to retain logs; otherwise a temporary
folder is used. Output must be outside the source folder. Failed assertions
produce a nonzero exit status. Archives are checked for unsafe extraction
paths; a stray old ZIP in the supplied wall archive is not installed.

Results for this release are in `lua-results.txt`,
`integration-lua-results.txt`, `ramp-gui-results.txt` and `engine-results-0.3.1.txt`. Earlier outputs
are historical; their component versions are retained in the filenames or
`docs/history`. `source-sha256.json` fingerprints the packaged runtime.

## Gameplay limits of the checks

Headless tests verify native prototypes, rendered-object lifetimes and audio
routing logic, but cannot judge the audible mix or appearance on a player's
screen. Native tests cannot create a player in headless Factorio 2.0, so the
ramp buttons are covered by the GUI API stand-in checks and native inventory/
anchor validation; the visible panel still needs an in-game client check.
Space Age is tested on Nauvis/caves with its native mods enabled;
this is not a campaign playthrough or a broad third-party mod-compatibility
claim. Multiplayer determinism comes from shared scripted state and native
APIs; a live multiplayer session has not been run in this environment.

## Difficulty and surface-only silos (0.3.2)

Run these suites with the same Factorio headless executable:

```sh
python tests/run_engine.py --factorio /path/to/factorio --suite difficulty --output /tmp/cruel-rain-difficulty
python tests/run_engine.py --factorio /path/to/factorio --suite difficulty --upgrade-from /path/to/deep-caves_0.3.1 --output /tmp/cruel-rain-difficulty-upgrade
python tests/run_engine.py --factorio /path/to/factorio --suite difficulty --upgrade-from /path/to/deep-caves_0.3.1 --space-age --output /tmp/cruel-rain-difficulty-space-age
```

The upgrade fixtures compare the old and new counts, ingredients and per-unit
time across 198 science technologies in the base game and 277 with Space Age
(including two disposable test technologies). The suite verifies infinite
levels, minimum counts, completed and selected research, saved silo parts,
actual final rocket-part crafting, every cave depth, outdoor placement,
ghosts, native Space Age conditions, robot cargo, quality, full-inventory
refunds, clone/revive protection and unrelated machines. Cost reductions below invested units reset
partial research in Factorio; this is recorded as an upgrade limitation.
A normal same-version save/reload preserves the fixture's 40% progress.

The 7 Lua placement checks test the actual production handler with player
inventory stand-ins, including overflow and exact consumed quantities.
Native tests exercise real entity creation events, inventories, qualities,
cloning and revival; headless player placement feedback still needs client QA.

Current output: `difficulty-lua-results.txt` and `engine-results-0.3.6.txt`.
Earlier engine reports are historical evidence, not reruns of every prior
suite in this release.

## Configurable difficulty and closer ports (0.3.6)

```sh
python tests/run_engine.py --factorio /path/to/factorio --suite difficulty --research-cost 0.5 --rocket-cost 0.2 --upgrade-from /path/to/deep-caves_0.3.1
python tests/run_engine.py --factorio /path/to/factorio --suite difficulty --research-cost 1 --rocket-cost 1 --upgrade-from /path/to/deep-caves_0.3.1
python tests/run_engine.py --factorio /path/to/factorio --suite difficulty --research-cost 0.01 --rocket-cost 0.01
python tests/run_engine.py --factorio /path/to/factorio --suite difficulty --space-age --allow-cave-silos --upgrade-from /path/to/deep-caves_0.3.2
python tests/run_engine.py --factorio /path/to/factorio --suite fluids --upgrade-from /path/to/deep-caves_0.3.2
```

The fluid suite checks all four closer ports with an off-grid ramp, center
building protection, old outer pipes plus new inner adapters, and preservation
of filled buffers. Hidden connection graphics use Factorio 2.0 prototype flags;
headless verification does not render the client appearance.

0.3.6 adds bounded radial/depth probability checks and native unit/character
placement inside both nest footprints. Collision stand-ins now reflect
passable nests. See engine-results-0.3.6.txt for current engine checks.

For the 0.3.6 native tunnel-water and dry starter-resource check, run
`python tests/run_engine.py --factorio /path/to/factorio --suite water`.
