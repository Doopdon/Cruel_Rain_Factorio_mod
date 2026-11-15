# Cruel Rain 0.3.0 integration record

The supplied Deep Caves 0.2.20, Cave Walls 0.1.15 and Surface Thunderstorm
0.1.9 are included in one Factorio 2.0 package. The internal name remains
`deep-caves`, with public title **Cruel Rain**. Only base is required;
the two former standalone mods are marked incompatible to prevent duplicate
prototypes, repeated damage and duplicate event processing.

## Runtime changes

- Wall modules are under `scripts/cave_walls`; storm modules are under
  `scripts/weather`. Namespaced prototype modules avoid the two different
  `scripts.walls` implementations overwriting each other.
- A shared event dispatcher composes lifecycle, tick, chunk, player, build
  and script-trigger handlers. Interval 60 retains both exposure damage and
  the cave resource/enemy/audio work.
- Prototype, surface, setting, command and remote-interface identifiers are
  retained. Asset references now point into this package. The old wall and
  weather compatibility interfaces remain available for integrations.
- Muffled weather finds `deep-caves-vent` as well as legacy Cave 1 up ramps.
- Storm reload cleanup destroys its own views rather than clearing every
  render object owned by the newly combined mod; cave lighting/rain survives.
- On a 2.0 save upgrade, boundary helpers are recovered from native entities
  before wall state is rebuilt, retaining their identities and avoiding
  duplicate boundary geometry. The original Deep Caves save state stays under the
  same mod identity.

## Verification

| Run | Engine / content | Checks passed |
| --- | --- | --- |
| Lua generation and vents | Actual mod Lua with a small API substitute | 51 |
| Lua event/audio integration | Actual integration modules | 5 |
| Spawning, minimum mesh, seed 0 | Factorio 2.0.76, base + combined mod | 13 |
| Spawning, default mesh, seed 0 | Factorio 2.0.76, base + combined mod | 13 |
| Native ventilation, seed 17 | Factorio 2.0.76, base + combined mod | 5 |
| Wall/weather/combat integration | Factorio 2.0.76, base + combined mod | 14 |
| Three-mod save to one-mod upgrade | Same engine, supplied old versions to 0.3.0 | 16 |
| Integration with Space Age | Space Age, quality and elevated rails enabled | 14 |

Each native run saves/reloads the world and completes 600 simulation ticks.
All named checks pass. Tests confirm wall sight checks stop damage and ammo/
oil consumption, then restore firing after erasure; fast robot crossings and
moving bullets are intercepted; storm damage operates on Nauvis and respects
sheltered caves; toggling weather off stops further exposure. Native rendering
cleanup leaves a vent skylight intact. A real populated old save retains its
vent, inventory entity, 37 coal, filter, power entity, 8 MJ, saved wires, all
42 test boundary helpers and an intentionally inactive turret.

The original implementation had no damage issue in the blocked-target
fixture: spawners regenerate a tiny floating-point amount above their initial
health. The finalized check allows healing while rejecting health loss and
still verifies ammo/oil are unchanged.

## Save-upgrade limit in Factorio 2.0

A new world is not required. The populated three-mod save upgrade described
above passed; players should keep a backup and follow the README's switch
steps. The limits below concern private state from the removed companion
mods, rather than a requirement to regenerate the world.

Automatic ownership transfer for removed mods' private storage was introduced
in Factorio 2.1.18, not 2.0. This package remains compatible with the tested
2.0 runtime. Companion weather command overrides, private clocks and original
brush terrain history cannot be recovered from disabled 2.0 mods. Their map
and player setting identifiers remain unchanged. To release previously
wall-paused turrets before switching, run `/cave-walls-checks off` with the old
wall mod enabled, then save; intentional inactivity remains respected.
Existing painted walls without old restoration history erase to stone-path.

Source: https://forums.factorio.com/viewtopic.php?p=704024

## Publishing and playtesting

The package contains an updated README, a portal description, compatible
changelog formatting, a thumbnail and asset provenance. It retains the
existing author field. At the author's request, original mod content is
licensed under MIT in `LICENSE`. The water-drop recording is credited to
ianna.lpl (Freesound), shared by freesound_community via Pixabay, and retains
the Pixabay Content License; details are in `THIRD_PARTY_NOTICES.md`.
The public rename changes the title, documentation and message wording;
internal mod, prototype, surface, setting and save-state identifiers remain
unchanged. The license/credit update changes no game assets. Portal
name availability could not be verified here. The balance remains a playtest
build.

Audio mixing, in-game appearance and a live multiplayer session still need
player testing. No claim is made about the whole Space Age campaign or other
third-party mods. Biter Caution and improvised weapons are not integrated.
