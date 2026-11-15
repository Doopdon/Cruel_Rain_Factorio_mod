# Cruel Rain 0.3.1 integration record

The internal mod identity remains `deep-caves`; the displayed name is
**Cruel Rain**. Existing cave surfaces, ramps, vents, cargo, settings and
power connections keep their identifiers. The original three-component
merge and its verification are recorded in
`docs/history/cruel-rain-0.3.0-integration.md`.

## Configurable ventilation

`deep-caves-vent-absorption` is a Startup double setting: default **7.5**
pollution per minute per vent, minimum 0, maximum 100. The vent's native
negative emissions use this value divided by 60; its description displays
the actual configured value. This keeps the existing passive, unpowered
tree-like mechanism, with no extra pollution scan or transfer loop.

Changing the setting requires restarting Factorio. It changes existing vent
prototypes in place, without replacing entities or requiring a new world.

## Native ramp fluid inventory

- `deep-caves-ramp-fluid` is a native storage tank under each ramp, with
  1,000 capacity and four normal pipe connections. It has no player collision
  and does not change the existing protected ramp footprint.
- Its center is aligned to the nearest tile center. Ports are two tiles
  north/east/south/west; adjoining pipe centers are three tiles away. This lets
  pipes fit beside older off-grid ramps too.
- A fifth connection is a native linked fluidbox connection with stable ID
  1. Paired buffers are joined once; the engine owns their shared fluid
  segment, flow, capacity, temperature and save persistence. No script copies
  fluid quantities between surfaces.
- Connection checks inspect actual fluid contents and fluid locks. If the
  two local networks contain different fluids, neither is linked or erased.
  Only blocked pairs are retried once per second; flushing/draining one side
  permits the connection. Ordinary connected pairs need no periodic script
  fluid reads or writes.
- New ramps receive their buffer during creation. Configuration upgrades
  reuse valid buffers, recover an existing native helper if its reference is
  missing, and reconnect only missing pair links. Existing plumbing beside
  previously unused ramps activates their destination; empty ramps remain
  lazy. Native player/robot/script-raised pipe construction also activates
  a directly connected unused ramp.
- Clicking a ramp still opens its existing native cargo inventory. Relative
  Cargo/Fluids buttons switch between the native linked-container and storage
  tank windows. The native fluid window provides normal flush controls.
- Pair callbacks are wired during control parsing; no event handler calls
  `require`, which Factorio disallows during gameplay.

## Verification

| Run | Checks passed |
| --- | ---: |
| Actual generation/portal Lua with API stand-ins | 51 |
| Shared lifecycle, helper recovery and weather audio Lua | 5 |
| Actual ramp GUI handlers with player/GUI API stand-ins | 5 |
| Native distant ramps, ores, nests and starter patches across five depths | 13 |
| Native vent absorption at default 7.5/min | 5 |
| Native vent absorption disabled (0/min) | 5 |
| Native vent absorption at custom 25/min | 5 |
| Native filled fluid save/reload | 12 |
| Native combined 0.3.0 save upgrade | 12 |
| Native fluid suite with Space Age, quality and elevated rails | 12 |
| Native wall, weather, projectile, robot and turret regressions | 14 |

All listed checks pass: **61 Lua checks** and **78 named native assertions
across eight runs**, including repeated checks. Native tests use Factorio
2.0.76, save/reload the world and simulate 600 ticks. Logs are summarized in
`tests/engine-results-0.3.1.txt`.

The filled-save fixture preserves 115 water and its mixed temperature, 37
coal, a slot filter, 8 MJ and copper/red/green wires. The legacy fixture
starts with actual 0.3.0 pipes beside the original ramps; the 0.3.1 buffers
join those pipes and preserve their contents. Repeating the upgrade keeps
helper identities and fluid amounts. Other checks cover every pipe port,
bidirectional drawing/insertion, independent water/oil pairs, 2,000 total
pair capacity, steam temperature averaging and conflict recovery.

The GUI stand-in checks cover switching, delayed close events, stale/removed
ramps and cleanup without altering another mod's panel. Native tests verify
inventory types and the 2.0 GUI anchors. A headless 2.0 game cannot create a
player for GUI rendering; the visible panel, pipe caps, audio mix and live
multiplayer remain player QA. No full Space Age campaign or broad
third-party compatibility claim is made.

## Save compatibility and release

Replace 0.3.0 with this ZIP; no new world is needed. For saves still using the
three separate mods, retain the README's `/cave-walls-checks off` step before
disabling the companions. The Factorio 2.0 limits on removed companions'
private weather/brush history remain as described in the historical merge
record. Core cave save state stays under its existing mod identity.

Original mod content is MIT-licensed. Water-drop recording credits and its
separate Pixabay Content License remain in `THIRD_PARTY_NOTICES.md`.

Relevant primary API documentation:

- https://lua-api.factorio.com/2.0.76/runtime-api.json
- https://lua-api.factorio.com/latest/types/PipeConnectionDefinition.html
- https://forums.factorio.com/viewtopic.php?p=621554
