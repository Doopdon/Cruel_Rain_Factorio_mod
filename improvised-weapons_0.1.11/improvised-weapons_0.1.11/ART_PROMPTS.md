# Generated fence art

The v0.1.9 electric-fence image is a single-pole replacement generated with the built-in ImageGen editor from the earlier electric-fence sprite. Its final game asset is `graphics/electric-fence.png`. The original assembly prompt below records the source art; the replacement prompt is:

Use case: precise-object-edit. Asset type: Factorio-style electric-fence pole sprite and inventory icon. Edit the supplied game sprite reference: replace the TWO-POST connected fence assembly with exactly ONE centered weathered steel electric fence pole. Preserve the gray industrial metal, small ceramic insulators, yellow hazard marks, copper bolts, painted Factorio oblique top-down lighting and genuinely transparent background. The single pole should be narrow with three small ceramic insulators down one side. Remove the second pole and remove ALL stretched wires, connecting cables, and blue glows. Connections between poles will be drawn by the game. Exactly one standalone pole, nothing attached beyond its short insulators; no ground, text, background or long cast shadow. Square transparent PNG, object fully visible, readable at 64px.

Created with the built-in ImageGen tool for this mod. Final game-ready assets:

- `graphics/barbed-wire-atlas.png` — 256×256 transparent 4×4 atlas, 64×64 cells.
- `graphics/barbed-wire-icon.png` — 64×64 crop of the horizontal wire tile.
- `graphics/electric-fence.png` — 64×64 transparent electric-fence sprite/icon.

Only atlas slicing, alpha-preserving cropping, and resolution conversion were applied for game packaging. The generated art is bundled under the mod's MIT license.

## Barbed-wire prompt

Use case: stylized-concept. Asset type: Factorio-style 2D game sprite atlas for a cheap barbed-wire wall. Create a transparent PNG sprite sheet, square canvas, exact 4x4 grid of 16 evenly sized square cells, no gutters, each isolated sprite centered in its cell. Rusty iron stakes with stretched steel barbed wire, gritty industrial sprites, oblique top-down camera compatible with Factorio, restrained browns and gray metal, upper-left lighting, absolutely no ground, no scenery, no text, no labels, no shadows outside each cell. All sprites use identical scale and center: a central iron stake occupies center and barbed wire arms run to cell edges. Connectivity masks in reading order 0..15, with bits N=1 E=2 S=4 W=8: row1 isolated stake, N, E, N+E; row2 S,N+S,E+S,N+E+S; row3 W,N+W,E+W,N+E+W; row4 S+W,N+S+W,E+S+W,N+E+S+W. Every cell is a separate usable game sprite; no overlap into neighboring cells. Wire three thin spiky strands, not chunky wooden wall. True transparent alpha background.

## Electric-fence prompt

Use case: stylized-concept. Asset type: one Factorio-style electric fence game sprite and inventory icon. Square transparent PNG. Exactly one centered small industrial electric-fence segment: two slender weathered steel posts joined by three stretched dark metal horizontal fence wires, small pale ceramic insulators, subtly blue glowing energized wire tips. Oblique top-down Factorio camera, detailed painted industrial sprite, gray steel, copper bolts, a little hazard yellow. Object must be readable downscaled to 64 pixels and fit fully inside central 80% of square. No ground, no environment, no text, no branding, no extra objects or lightning bolt icon. Genuinely transparent background with alpha, no checkerboard baked in, no long cast shadow. This is a one-tile game obstacle, not a tall real-world landscape fence.
