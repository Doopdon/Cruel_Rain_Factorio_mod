# Vents in 0.2.20

Surface-connected up ramps in Cave 1 use the `deep-caves-vent` electric-pole
prototype. It clones the ascent's footprint, artwork, wire reach and supply
area, with a distinct localized name and `emissions_per_second` set to
`{pollution = -10 / 60}`. Absorption is native, passive and independent of
power or background ramp preparation. It removes cave pollution locally.
Factorio performs the absorption at its native pollution update cadence.

New endpoint creation selects this prototype only for Cave 1 to Nauvis.
Existing eligible ascents migrate on configuration change: replace the
visible pole at its saved position, reconnect its saved wires, remap both
sides of its registry link, and retain its cargo and power helper entities.
An unsuccessful creation leaves the old opening intact. Repeating migration
does not create another vent. Portal discovery, terrain protection, nesting
protection, travel, cargo opening, spawn inspection and daylight all recognize
the new prototype. Existing puddle state stays attached to the portal record.

## Validation

- 51 Lua checks pass, including all earlier spawning tests and five focused
  vent/registry/migration/travel checks.
- 13 native spawning checks pass with minimum mesh settings and seed 0 in
  Factorio 2.0.76 with Cave Walls 0.1.13, followed by 600 simulation ticks.
- Six native vent and populated-save upgrade checks pass using seed 17 and
  minimum mesh settings. A real 0.2.19 save retains 37 coal, the slot filter,
  the same inventory and power entities, 8 MJ, and copper/red/green wires.
- In isolated native chunks, one unpowered vent removed 0.5 pollution and two
  removed 1.0 over the 137-tick observation window. Native cadence accounts
  for the discrete sample. A near-empty chunk reached zero; ordinary ascents,
  descents and the empty control retained their 100 pollution.

See `tests/README.md` for commands. The headless checks verify prototype
loading and behavior; the artwork itself is unchanged from 0.2.19.
