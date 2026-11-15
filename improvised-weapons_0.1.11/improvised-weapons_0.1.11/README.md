# Improvised Weapons — 0.1.12

A standalone Factorio 2.1 mod. Space Age is not required. Includes fuel-fed defensive fires, melee spinners, unreliable claymores, single-use contact bear traps, barbed-wire walls, and powered electric fences.

## Install

Put `improvised-weapons_0.1.12.zip` into your Factorio `mods` folder without extracting it. Enable **Improvised Weapons** in the Mods menu and restart Factorio. It can be added to an existing save; a new world is not required. Back up the save before adding any new mod.

## 0.1.12

Updated for Factorio 2.1 runtime APIs. In-game interaction testing is recommended.

## Use

1. Craft **Defense fire** from the Combat crafting tab. Available immediately, with no research. Cost: **5 stone + 5 coal**. Crafting time: **0.5 seconds**, the same base duration as copper cable.
2. Place it on dry ground. Its coal-fed center occupies one tile and is walkable; its fire and damage cover the surrounding 3×3 square. It begins burning immediately, using the five coal embedded in the recipe: **50 seconds at default settings**.
3. Point an inserter at the center coal patch and feed it coal, or open it and add coal by hand. Inserters automatically stop at **five queued coal**, separate from the fuel already burning. Manual loading still permits a full stack, filtered to coal of any quality. The mod limits each feeding inserter to one coal per swing and restores its previous stack override when repointed. The decorative coal patch is the fuel holder; it is immune to fire damage.
4. Each additional coal lasts **10 seconds** by default. An empty inventory is fine while the currently consumed coal still has burn time left.
5. Once the last fuel is exhausted, the flame and fuel holder both disappear, within half a second. Place a new fire to restart it. No empty structure, free replacement item, or persistent ground flame remains.

One fire covers **nine tiles**, with a **single fuel inventory at its center**. Nine vanilla flame sprites show the affected square. An ordinary adjacent inserter can feed the center and is immune to this mod's defensive-fire damage, including modded inserters. No remote-loading system is needed.

Damage is **26 fire damage per second** before resistances, applied every half-second to units and player characters intersecting the 3×3 square. Diagonal tiles are included. All structures, equipment, vehicles, trees, and rocks are safe from these fire pits. Players and creatures can still burn; other weapons and their damage are unchanged. Spreading is disabled. Fuel use and pollution remain per fire, not per flame sprite.

This is a placeable entity with a fuel inventory, not a terrain tile. That is how ordinary inserters can feed it. The fuel holder displays a coal-patch sprite. It is decorative, not a mineable resource. The larger fire item and crafting icons reference a square from the first frame of the installed game's `fire-flame-03.png` ground-fire animation, not the fire signal pictograph. The spinner icon uses a square crop of the vanilla roboport rotor frame.

## Burner spinner

Available immediately in the Combat crafting tab. Costs **10 iron plates + 5 iron gears + 5 stone**, with **0.5 seconds** crafting time.

The spinner uses the installed game's roboport top animation, widened to **two tiles**, above a burner-mining-drill body scaled to **one tile**, using mipmaps and linear filtering for a softer appearance. This build sets rotor speed to 5 times v0.1.5 (rotation_speed 0.25 instead of 0.05), half the v0.1.6 test speed. The vanilla rotor has only eight frames, so very high speeds may look flickery or appear stationary due to frame aliasing. This needs an in-game visual check. It has a one-tile collision footprint and a 3×3 selection/damage area centered on the base. Point a fuel inserter at the **center tile**, rather than the outer blades, or add fuel by hand.

It accepts ordinary chemical fuel, such as coal, wood, and solid fuel, in a native burner inventory. It consumes **400 kW** while spinning, including when no enemies are nearby. Normal coal (4 MJ) lasts approximately **10 seconds**. It produces **30 pollution/minute** while running. The native burner controls fuel consumption and automatic fuel insertion; manual full-stack loading is supported.

The rotor deals **13 physical damage per second**, before armor/resistances, to hostile entities and player characters intersecting the **3×3 square**, including diagonal tiles. Its damage hits enemy entities and **characters from any force, including your player**. Characters receive at most **one 0.35-tile shove** per half-second update. An isolated spinner pushes directly away from its center; a straight horizontal, vertical, or diagonal bank pushes perpendicular to the bank. Exact destination collision checks try shorter steps on that same line if the full step is blocked; there is no lateral position search. Shoves are skipped for characters riding vehicles; damage still applies. Other friendly/cease-fire/neutral entities and feeding inserters remain safe. It does not shoot projectiles: the fuel powers a continuous melee hazard. It is a military target and can be destroyed by enemies.

An empty spinner **stays in place**, stops damaging, and restarts when refueled. Unlike the fire, it has no free starting fuel. Mining returns the spinner item. No research or electricity is needed.

## Improvised claymore

Craft **one claymore** from **5 coal + 5 stone + 1 pipe**, in **0.5 seconds**, without research. It displays the vanilla land-mine graphic with a small pipe overlay; its item icon uses the same mine/pipe combination.

Place it and wait **0.5 seconds** for it to arm. Like a normal land mine, enemies within its **2.5-tile trigger radius** set it off. Each triggered claymore rolls once:

- **50%:** an explosion deals **250 explosion damage** before resistances to enemies whose centers are within **three tiles** of the mine.
- **50%:** the charge fails and leaves one small vanilla-style ground fire lasting **about five seconds**, dealing **13 fire damage/second** before resistances. It does not spread or accept fuel. It damages only units and characters, including friendly creatures and players; structures and equipment are safe.

Either result **consumes the claymore**. There is no retry or automatic free replacement. The chance is a game-synchronized random coin flip for each detonation; a small sample need not split exactly in half.

## Bear trap

Craft **one bear trap** from **5 iron plates + 3 iron gears**, in **0.5 seconds**, without research. It uses the land-mine graphic with a gear overlay, including matching item/crafting icons.

It arms after **0.5 seconds** and triggers only when an enemy's collision footprint passes directly across its **center**, with a **0.01-tile trigger radius**. Nearby enemies do not set it off. Checking once per tick helps catch moving biters.

It deals **100 physical damage** before resistance to **one contacting enemy**, then is consumed. A normal vanilla medium biter has 75 health and physical resistance of 4/10%; this hit deals **86.4 damage**, enough to kill it. Tougher modded enemies may survive. No explosion or area splash is produced; friendly and cease-fire forces do not trigger it.

Both traps can be picked up before they trigger. They use native land-mine arming and consumption, which still require an actual in-game check.

## Barbed wire and electric fences

Both are available without research and craft in **0.5 seconds**. Generated transparent game sprites are included. Barbed wire renders one complete tile per placed wall, with north/east/south/west joins derived from adjacent wire segments. This bypasses native wall-piece composition that previously drew extra posts. Construction ghosts use the same join logic. Electric fences are **single poles**, without a painted wire segment; actual native copper wires between fence poles provide the visible fence spans.

| Defense | Cost per segment | Health | Contact damage | Electricity |
| --- | --- | --- | --- | --- |
| Barbed wire | 2 iron sticks | 80 | 4 physical/second | None |
| Electric fence | 4 iron sticks + 2 copper cables | 180 | 40 electric/second | 20 kW idle / 200 kW during shocks per pole |

Damage is before resistances and armor. Both block walking and injure touching **units and characters, including players**. Barbed wire has no stone-wall armor. Electric fences block movement even when unpowered; their shock damage requires electricity, with at most about half a second of residual charge after disconnection.

Place electric fences on adjacent tiles for a continuous barrier. Their **1.5-tile wire reach** connects neighboring segments, including diagonals, and ordinary poles placed close to the fence. Each segment supplies a **5×5 area**, so it can power nearby machinery and turrets too. Its collision footprint nearly fills a tile to prevent biters slipping between segments. Actual copper-wire links between fence poles are checked for contact damage, and a shared span/junction shocks once per update rather than once per endpoint. Unconnected poles do not invent a connecting span. Every shock pulse displays vanilla accumulator discharge sparks at the pole and contact point and plays its electrical discharge sound. Demand rises to 200 kW on each shocking pole for 0.5 seconds, renewed by further shocks, then returns to 20 kW idle. Multiple targets do not multiply that demand. Use the electric network to check actual power.

## Conventional ammunition and turret changes

- The firearm, piercing-rounds, and uranium-rounds magazine recipes each require **one additional coal**, at each crafting stage. Shotgun shells and other ammunition stay unchanged.
- **Gun turrets:** recipe adds **5 green electronic circuits**. They require electricity as well as bullets: **10 kJ per shot**, plus **1 kW idle draw**, with a 100 kJ native buffer.
- **Flamethrower turrets:** recipe adds **10 green electronic circuits**. They retain their fluid ammunition requirement and draw **50 kW** continuously. They stop when their small electric buffer is empty and resume when powered. The handheld flamethrower is unchanged.
- **Gun-turret research:** requires **red, green, and military science packs**, with logistic/military-science prerequisites. Existing research count and duration remain as set by the game/other mods. Science-prerequisite paths are checked for a gun-turret back-edge to avoid a progression cycle.

Existing placed gun/flamethrower turrets need a power supply after this update. Research already completed in an existing save remains completed. Existing ammunition items are preserved; the coal cost affects newly crafted magazines.

## Settings

In **Settings → Mod settings → Map**:

| Setting | Default | Range |
| --- | --- | --- |
| Seconds per coal | 10 seconds | 1–600 seconds |
| Pollution per minute, per fire | 30 | 0–6000 |

Default pollution matches one vanilla boiler at full output, for the entire 3×3 fire. Existing saves may keep their previous setting: change **Defense fire: pollution per minute** to **30** in the Map mod settings to use the new balance.

Changing burn duration affects the next coal consumed and newly placed fires; the current coal keeps its remaining burn time. Pollution applies immediately at the next half-second update. Pollution is attributed to Defense fire in production statistics.

## Save and compatibility

Fuel progress persists in the save. Player placement, construction robots, platform construction, script-raised construction/revival, cloning, mining, destruction, and surface cleanup are handled. Scripts creating the fuel holder should raise `script_raised_built`. This standalone mod has no dependency on Cruel Rain or Biter Caution.

## Refill-limit compatibility

The fire's automatic cap is implemented by temporarily pausing its feeding inserters. Circuit controls remain respected. Normal inserters are checked each tick so multiple feeding arms reserve space before dropping fuel. Inserters placed before the fire, rebuilt/rotated inserters, and existing saves are handled. A hand already holding more than five coal during an upgrade will wait: clear that hand manually, after which it picks up one coal at a time. Loaders or mods that insert directly into inventories bypass this inserter-only limit, as does manual loading. Mods that change inserter destinations by script should raise a build/rotation event or reconfigure/reload the mod so the feeder is discovered.

## Validation

Lua parsing, prototype checks against Factorio's official 2.0.77 API schema, and simulated runtime regression checks were performed. 86 simulated runtime checks cover fire behavior, simultaneous fuel feeding, manual loading, spinner damage bounds and force exemptions, fuel starvation/restart, and cleanup, plus both claymore outcomes, single-target bear-trap damage, trigger deduplication, trap save/surface cleanup, player knockback in straight spinner banks, every barbed-wire neighbor mask, construction ghosts, connected wire-span damage, power loss/recovery, paired-consumer lifecycle, mining entities without unit numbers, structure-safe fire damage, and dud-fire timing and cleanup. Spinner graphics use the live game prototypes; the local prototype test uses representative drill/roboport sprite tables. An actual Factorio executable was unavailable in the build environment, so game loading, inserter interaction, fire visuals, pathing, and native damage still need an in-game test.

Suggested smoke test: place a fire, supply it from a coal belt using an inserter, confirm that it outlasts its starting fuel, then disconnect the belt and wait for both inventory and current fuel to run out. Test near a biter, confirm damage on the diagonal tiles and no damage outside the square, and confirm the feeding inserter stays healthy. Keep your character clear of the flames. Save/reload while one is burning and confirm fuel time is preserved. Confirm its inserter pauses at five queued coal and resumes as fuel is consumed; try a manual full-stack refill. For the spinner, check the enlarged rotor and small drill base, supply coal at its center, bring a biter onto a diagonal tile, then remove fuel and verify that damage stops and the machine remains. Refuel and confirm it restarts.

## License and assets

Mod code: MIT; see `LICENSE`. The reused vanilla graphics and sounds are referenced from the installed Factorio game, remain owned by Wube Software, and are not included in this archive. New barbed-wire and electric-fence sprites were created with ImageGen and are bundled under the mod MIT license. Their production prompts are in `ART_PROMPTS.md`.

### Trap smoke test

Place claymores beside an enemy path and allow them to arm. Trigger several: each should produce exactly one blast or one short fire, and disappear. Confirm dud flames vanish without refueling or spreading. Keep your character clear of dud fires. For bear traps, walk a medium biter across the center: the trap should disappear and kill that biter, while a biter passing beside it should leave it untouched. Test overlapping contacts to confirm only one enemy takes the strike. Save/reload with armed traps and repeat.

### Powered-defense smoke test

Back up your save. Power an ammo-loaded gun turret and a fluid-fed flamethrower turret, test firing, disconnect electricity, then reconnect it. Check their new circuit costs and all three magazine coal costs. In a fresh test save verify gun turrets cannot be researched until red/green/military science is available. Place a straight and corner barbed-wire line, then an electric-fence line connected to an ordinary powered pole; check that biters cannot slip between segments and a nearby machine receives electricity. Approach carefully with your character to test both fence hazards. Check for blue sparks and electrical discharge sound when shocked, 200 kW demand during use, and 20 kW again after leaving. Disconnect the electric fence: after its brief stored charge drains it should still block movement but stop dealing damage. Walk into a fueled spinner to check player damage and a small shove; repeat next to a solid obstacle to ensure the shove is skipped when blocked. Test mining, robot removal, save/reload, and cloning to check for orphan power consumers.

### v0.1.11 regression smoke test

Existing fences/wires update after loading this version; no replacement or new world is required. Place horizontal and vertical barbed-wire runs, then corners, T junctions, and crosses; there should be exactly one visible central post per placed segment. Mine the middle of a line and verify both new ends redraw. Blueprint/build with robots and check construction ghosts. Electric fences should now display one pole per segment and have no circuit ingredient. Connect adjacent fence poles, test touching their powered connecting wires, remove the wire manually and confirm that missing span no longer shocks, then reconnect. Compare spinner knockback on horizontal, vertical, and diagonal banks: movement should be straight away from the bank, with one shove per pulse; beside a blocking obstacle it should shorten or skip rather than move sideways.
