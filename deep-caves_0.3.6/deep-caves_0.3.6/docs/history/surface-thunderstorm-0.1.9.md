# Surface Thunderstorm 0.1.2

A separate Factorio 2.0 mod for a permanent, atmospheric storm on Nauvis.

## Install

1. Put `surface-thunderstorm_0.1.2.zip` in your Factorio mods folder.
2. Disable the other rain mod while trying this one, so two weather overlays and soundtracks do not overlap.
3. Keep Deep Caves installed. This weather mod runs alongside it; you do not need another cave-mod update.
4. Restart Factorio and load your save. The storm starts automatically on Nauvis, with the first lightning flash after approximately 3–7 seconds.

Requires Factorio 2.0.46 or newer (for its camera zoom API). Space Age is optional. Deep Caves is optional as well: the storm also works in a normal Nauvis game.

## Weather

- Permanent heavy, wind-slanted rain: two animated layers of streaks.
- A dark, cool overcast overlay over the world, including daytime. The inventory, toolbars and other interface elements remain clear and clickable.
- Irregular lightning flashes approximately every 7–20 seconds, with a short second flash and fade.
- Thunder follows each flash after a random **1–10 seconds**. Pending thunder is queued, so a later flash cannot cancel an earlier rumble.
- Constant rain audio: alternating channels, four variations, and overlapping equal-power fades keep the sound bed steady.
- Cave surfaces and other planets have no weather overlays and start no weather sounds. Sound already playing can finish its short tail when you enter a cave.
- No lightning damage, changes to solar production, or changes to the actual day/night cycle. This release is an aesthetics prototype.

## Adjust it

**Settings → Mod settings → Per player**:

- Overcast darkness: default **0.45**; increase to make the surface darker.
- Rain intensity: default **1**; lower to reduce the rain overlay.
- Lightning flashes: disable to keep rain without flashes.
- Rain and thunder volume: default **0.55**; set to **0** to mute.

**Settings → Mod settings → Map** has the permanent-storm enable switch.

Commands (on/off/lightning require admin access):

```
/surface-storm status
/surface-storm on
/surface-storm off
/surface-storm lightning
```

The command uses its own saved on/off override. Changing the permanent-storm map setting resets that override.

## 0.1.2 audio fixes

Rain clips overlap by half a second, and each incoming/outgoing pair uses complementary sine/cosine fades. Alternating sound names prevent one clip from replacing its predecessor. The first half-second gently fades in; after that the rain bed has no scheduled silence or volume dips. Four variations reduce audible repetition.

Thunder delay is randomized from 60 to 600 ticks (1–10 seconds), with a queue to preserve multiple pending rumbles. Switching the storm off clears pending thunder.

## Implementation and validation

Weather uses private, per-player script-rendering objects, not physical raindrop entities. A small grid covers the visible world; animation playback is handled by Factorio. Grid size depends on display dimensions rather than map area or zoom distance. For example, a 1920×1080 display uses 99 animated tiles and three cover/light objects. Scrolling removes obsolete tiles; entering a cave, disconnecting, or switching weather off removes the view.

Rain graphics and sound files are generated original assets. The code modifies no prototypes from other mods and no terrain or surface lighting parameters.

Verified in Factorio 2.0.76 headless: loading, new-map creation, animation/sprite/light rendering API calls, view movement and zoom updates, lightning envelope and flash-disable setting, rain intensity, bounded object count and cleanup, Nauvis-only eligibility, sound prototype paths, and unchanged day/night and solar settings. Also checked with Deep Caves 0.1.20 enabled. The 0.1.2 audio changes passed engine scheduling checks for alternating rain playback every 90 ticks and queued thunder with 60–600 tick delays; complementary fade power and all four audio clips were checked separately.

The headless runtime cannot display the game or play audio. Rain appearance, perceived darkness, sound balance, and a live player's camera still need an in-game check; this release is ready for that first art pass.

The optional asset regeneration script is `tools/build_assets.py`; it requires Python, Pillow and NumPy. These are not required to play the mod.

## 0.1.2 shared weather clock

Exposes a read-only remote interface, surface-thunderstorm.get_weather(), returning storm enabled state and the current lightning strength. Deep Caves 0.1.16 uses it for localized rain and white flashes at Level 1 surface exits. Surface rain, crossfaded sound and delayed thunder remain unchanged.

## 0.1.3
When Deep Caves is installed, players physically on cave Level 1 hear quieter, low-pass-filtered rain. The alternating two-second clips retain their half-second overlap. Deeper levels are silent. Audio follows the character's physical surface rather than the remote map camera and respects rain intensity, sound volume and storm enable settings. Outdoor storm overlays require both the character and camera to be on Nauvis, and stale overlays are removed before lightning updates.

## 0.1.4: surface exposure
While the storm is enabled, destructible characters physically on Nauvis take 0.5 HP each second; player buildings and vehicles take 0.1 HP each second. Both rates are configurable runtime global settings (0 disables either). Caves and other planets are sheltered. Damage uses a dedicated type to keep small pulses from being completely cancelled by flat armor resistance; native shields and repair behavior still apply. Natural rocks/trees, enemy nests, flying robots and indestructible ramp entities/helpers are exempt. Audio and lightning options do not change exposure; disabling the storm pauses it.

## 0.1.5: rain exemptions
The crashed spaceship and its wreck pieces are exempt from storm exposure. All native ground, legacy and elevated rail types, rail ramps and rail supports are exempt by entity type, including modded rails using those types. This only skips rain damage; normal combat damage is unchanged. Other buildings, vehicles and characters retain their configured exposure rates.


## 0.1.6 audible delayed thunder and localized cave weather

Thunder clips are louder, have higher playback priority and use an explicit playback position. Each lightning flash queues thunder 1–10 seconds later; subsequent flashes do not replace pending thunder. Cave 1 surface-connected up ramps transmit low-pass filtered thunder at the same due tick and muffled rain within 24 tiles, fading with distance. Only the nearest opening plays, so dense openings do not multiply volume. Other cave levels are silent. Storm-off, per-player mute and remote-view checks remain.

Replace the older Surface Thunderstorm ZIP with this version alongside Deep Caves 0.2.5. Test using /surface-storm lightning, then wait up to 10 seconds. Existing cave meshes, ramps, enemies and density settings are unchanged.


## 0.1.7 louder storm audio

Outdoor thunder, muffled cave thunder and muffled cave rain now play at three times their previous prototype volume. Outdoor rain, per-player volume controls, thunder delay, opening range and distance fade are unchanged.


## 0.1.8 smoother outdoor thunder and louder cave rain

Outdoor thunder uses the same filtered clips as underground thunder, with prototype volume 4.8. Underground thunder remains at 2.55. Muffled rain volume is doubled from 1.5 to 3.0. Thunder delay and proximity behavior are unchanged.
