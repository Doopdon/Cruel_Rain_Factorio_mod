# Cruel Rain 0.3.2 integration record

The internal mod identity remains `deep-caves`; the displayed name is
**Cruel Rain**. Cave terrain, ramps, vents, shared cargo, power and fluids
retain their existing names and storage. Earlier merge and fluid verification
are recorded in `docs/history/cruel-rain-0.3.0-integration.md` and
`docs/history/cruel-rain-0.3.1-integration.md`.

## Research and launch costs

`prototypes/difficulty.lua` runs from data-final-fixes after base and Space Age
updates. Science technology unit counts are divided by ten, rounded up and
clamped to one. Infinite formulas are wrapped in `max(1, (formula) / 10)`;
Factorio evaluates these at each level. Pack types, quantities per unit,
unit times, unlocks and research triggers remain unchanged. Existing map
research price multipliers continue to apply normally.

Rocket silo prototypes require one tenth as many rocket parts per launch,
clamped to one. The native silo requires 10 instead of 100 parts in the base
game, or 5 instead of 50 with Space Age. Rocket-part recipes, silo construction
recipes and launch cargo capacity retain their normal values.

## Above-ground silo placement

`scripts/silos.lua` rejects rocket silos and silo ghosts on every surface
named `deep-caves-level-N`. Nauvis and other outdoor surfaces are allowed.
The shared dispatcher covers player/robot construction, raised script builds,
raised ghost revivals and entity cloning without replacing existing handlers.
Player `consumed_items` refunds preserve counts and quality. Robot refunds
return only the required building item, not the entire supplied stack. Full
inventories spill remaining items. Removed ghosts generate no refund items.
Other entity types return immediately.

Space Age additionally supplies a native `deep-caves-above-ground` surface
property, default 1 outside caves and 0 on cave creation or configuration
upgrade. Silos append an above-ground condition while retaining their existing
pressure constraints. This rejects native underground placement/preview checks.
Native surface conditions require Space Age, so the base game rejects attempts
immediately after construction and returns their item. No new dependency or
per-tick silo scan is needed. Existing underground silo entities are not
deleted by the upgrade; this rule governs new placement.

## Save compatibility

Existing worlds can upgrade without restarting. Native tests preserve
completed research, current research selection and an existing surface silo
with two saved rocket parts. **Finish partially completed research before
updating:** Factorio 2.0.76 resets partial progress when a technology's unit
count changes. The actual 0.3.1 upgrade fixture confirms this reset; normal
0.3.2 save/reloads retain the fixture's 40% progress. The mod does not claim
to recover spent science after that native cost-change reset.

Core ramp state, fluid, cargo, slot filters, power and wires continue to
survive ordinary reloads. Older separate-component saves should still follow
the README's companion removal steps.

## Verification

| Current run | Passed checks |
| --- | ---: |
| Actual generation/portal Lua with API stand-ins | 51 |
| Shared lifecycle, helper recovery and weather audio Lua | 5 |
| Ramp GUI handlers with player/GUI API stand-ins | 5 |
| Actual silo placement handler with player inventory stand-ins | 6 |
| Native fresh 0.3.2 difficulty save/reload | 12 |
| Native 0.3.1 difficulty upgrade, base game | 12 |
| Native 0.3.1 difficulty upgrade, Space Age | 12 |
| Native ramp-fluid regression | 12 |

All **67 Lua checks** and **48 named native assertions across four runs** pass,
including repeated checks. Each native run uses Factorio 2.0.76, saves/reloads
and simulates 600 ticks. The upgrade suites compare 198 science technologies
in the base game and 277 with Space Age, including two disposable test
technologies. They verify finite counts, infinite levels, ingredients and
time per unit, saved research/silo state, actual final rocket-part crafting,
all five cave depths, native Space Age placement checks, outdoor placement,
quality, robot inventory/overflow, ghosts, revival and cloning. Native fluid
checks confirm unchanged flow, conservation, temperature, capacity, conflicts,
cargo, power and wires. Output is in `tests/engine-results-0.3.2.txt`.

Player inventory overflow and exact consumed quantities are checked with
API stand-ins. A headless game cannot render a player placement message or
inventory window; client visual feedback, sound, live multiplayer and broad
third-party compatibility remain player QA. Prior native generation, vent and
wall/weather reports remain historical evidence, not reruns of every suite.

Original content remains MIT-licensed. Water-drop recording credits and its
separate Pixabay Content License remain in `THIRD_PARTY_NOTICES.md`.

Primary API references:

- https://lua-api.factorio.com/2.0.76/runtime-api.json
- https://lua-api.factorio.com/latest/types/TechnologyUnit.html
- https://lua-api.factorio.com/latest/types/MathExpression.html
- https://lua-api.factorio.com/latest/prototypes/RocketSiloPrototype.html
- https://lua-api.factorio.com/latest/types/SurfaceCondition.html
