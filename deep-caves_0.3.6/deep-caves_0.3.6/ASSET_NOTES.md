# Natural entrance art

Created with the built-in image-generation tool, with transparent backgrounds.

Project source files:
- graphics/natural-sources/pit.png
- graphics/natural-sources/rubble-rise.png

Game assets:
- graphics/ramp-down-{north,east,south,west}.png
- graphics/ramp-up-{north,east,south,west}.png
- graphics/ramp-down-pole.png and graphics/ramp-up-pole.png

The generated north-facing sprites are mechanically resized to 256 by 256 pixels, rotated into four cardinal directions, and packed into 1024 by 256 pixel atlases. At Factorio scale 0.375 they occupy a 3 by 3 tile canvas. Sprite artwork is cosmetic; the native inventory, power-pole identity and walkable no-build collision footprint remain.

## Pit prompt

Use case: stylized-concept. Asset type: one transparent game sprite for a Factorio cave entrance, north-facing DOWN ramp. Render a natural oval black pit with a rough craggy rim of grey and brown rocks, a few jagged rocks sticking up from the hole, and a rough rubble slope descending from the bottom/south edge into the very dark hole towards the top/north. View from overhead at Factorio's slightly oblique top-down camera angle; detailed hand-painted/pre-rendered gritty realistic industrial-game environment art, neutral warm grey stone, earthy brown rubble, natural shadow. Single centered object occupying about 75 percent of a square image, ample transparent border, genuine alpha transparency outside the rocks, the interior pit stays opaque near-black. The slope must clearly look walkable into a hole, not a building or ladder. No text, no arrows, no markings, no metal, no machines, no glow, no scenery or background ground plane. Light from upper left.

## Rubble ascent prompt

Use case: stylized-concept. Asset type: one transparent Factorio game sprite, natural north-facing UP ramp. A low rugged pile of warm grey-brown boulders and loose rubble forms a walkable sloping ridge, rising from the bottom/south foreground to a higher rock pile at the top/north rear, where a small dark passage between the largest boulders suggests a way to the level above. Clearly a mound rising upward, not a deep hole. Slightly oblique overhead top-down game camera, detailed pre-rendered gritty realistic environment art, neutral warm grey rocks and earthy brown dirt, coherent lighting from upper left. Single centered object filling about 75 percent of a square image; transparent background and generous clear border, actual alpha outside the rubble. Irregular natural silhouette, varied boulder sizes, readable slope even when reduced to a 96 pixel game sprite. No text, no arrows, no paint, no metal, no ladder, no architecture, no machines, no glow, no background ground plane.

## Combined package provenance

- Cave generator, ramp art, entrance rain and drip audio: supplied Deep Caves
  0.2.20. Generated entrance artwork and its prompts are recorded above.
- Wall brush icon and runtime: supplied Cave Walls 0.1.15. Natural boundary
  sprites reference Factorio base assets at runtime; base assets are not bundled.
- Rain sprites and weather audio: supplied Surface Thunderstorm 0.1.9,
  copied into `graphics/weather` and `sound/weather`. The original synthetic
  asset generator is retained as `tools/build_weather_assets.py`.
- `thumbnail.png` reuses the supplied north-facing pit sprite unchanged.
- `sound/water-drops.wav` is **Water Drops** by **ianna.lpl (Freesound)**,
  shared by **freesound_community** via **Pixabay**, retained from Deep Caves
  as a WAV for cave ambience. The user identified the Pixabay contributor;
  the source page also identifies ianna.lpl and the Pixabay Content License.
  Source: https://pixabay.com/sound-effects/water-drops-26638/

The author selected **MIT** for original mod code, documentation and
project-created assets. See `LICENSE`. The water-drop recording retains its
own Pixabay Content License; see `THIRD_PARTY_NOTICES.md`.
