# Cruel Rain portal page

Title: **Cruel Rain**

Summary: Build beneath a hostile, storm-soaked wasteland. Five cave layers,
tight tunnels, ore caverns, biters, flooded depths and pollution vents, with
shared cargo, pipe-connected fluids and power through natural cave openings.

## Description to paste into the portal

The surface is a hostile, rain-soaked wasteland. Your factory belongs below.

Descend through five cave layers: broad caves near the surface, cramped dark
passages deeper down, and a flooded final layer. Find iron, copper, coal and
stone starter deposits in Cave 1, then hunt deeper resources and make room
for a factory that can survive the tunnels.

Natural openings carry you between layers. Each pair shares a filtered
12-slot cargo inventory, carries one fluid through four pipe ports, and
bridges electrical power. Fluid ports are invisible, with adjoining pipes
two tiles from the ramp’s grid center. Existing outer pipes need one additional
pipe between them and the ramp after upgrading. Each end provides a 1,000-fluid buffer; pipes work
in both directions, with pumps available to control flow. Surface-connected **Vents**
bring blue daylight, rain, muffled thunder and pollution absorption into
Cave 1. Solid rock blocks movement, flying robots and moving projectiles;
standard gun, laser and flamethrower turrets respect cave walls.

Vent absorption defaults to 7.5 pollution per minute. Adjust it from 0 to 100
in Startup settings; 0 turns absorption off. Existing saves receive the fluid
buffers automatically and can continue without restarting the world.

Research defaults to one tenth the usual science packs, including infinite research.
Research and rocket costs have independent Startup multipliers (0.01 to 100):
0.1 is the default, 0.5 halves costs, and 1 restores normal costs.
Surface-only silos can also be disabled in Startup settings.
Rocket launches need 10 parts, or 5 with Space Age. Build rocket silos above
ground; underground placements return the building item. Finish partially
completed research before updating, because reducing its cost can reset partial progress. Completed technologies remain researched.

Includes the complete cave, wall and weather systems in one download.
Adjust tunnel density, width, initial nest density, storm intensity, volume
and surface exposure damage through mod settings.

Factorio 2.0. Space Age is optional. Existing worlds are supported; a new
world is optional for a fresh playthrough. Balance and development are still
in progress. Follow the save-upgrade steps in the README when switching from
the separate mods.

**Install only Cruel Rain. Disable the old Cave Walls and Surface Thunderstorm
mods; their features are already included.** Biter Caution and improvised
weapons are separate mods and are not part of this package.

Original mod content is licensed under **MIT**. Cave drip sound: **Water
Drops** by **ianna.lpl (Freesound)**, shared by **freesound_community** via
[Pixabay](https://pixabay.com/sound-effects/water-drops-26638/), used under the
**Pixabay Content License**. Full credits are included in the package.

## Upload notes

Upload `deep-caves_0.3.7.zip` at https://mods.factorio.com using your Factorio
account. The package contains valid mod metadata, a changelog and a thumbnail.
The public title is **Cruel Rain**; the internal name remains `deep-caves` to
preserve existing saves. Keep the ZIP filename `deep-caves_0.3.7.zip` because
Factorio matches it to the internal name and version. The portal's URL also
uses the internal name. If that internal name is owned by another account on the
portal, it must be resolved before publication. Name availability could not
be confirmed in this environment.

Select **MIT** as the distribution license on the portal. The package contains
the MIT text in `LICENSE`, asset provenance in `ASSET_NOTES.md`, and separate
recording credits and terms in `THIRD_PARTY_NOTICES.md`. The water-drop
recording retains its Pixabay Content License; the MIT grant covers original
mod content. The storm's supplied generator documents synthesized weather
audio.

Suggested category: Overhaul. Suggested tags: Environment, Enemies, Logistics,
Utilities. Add in-game screenshots of a vent, the narrow cave factory, the
stormy surface and the flooded level when you publish.

Official mod structure documentation:
https://lua-api.factorio.com/latest/auxiliary/mod-structure.html

Official portal upload documentation:
https://wiki.factorio.com/Mod_upload_API

Native biters, spitters, worms and nests use white body color masks, including
death animations. Existing creatures update when loading a save.
