# Cruel Rain 0.3.4 verification

The change replaces body-mask colors for all four sizes of native biters,
spitters and worms, both native nest types, and their referenced corpses.
Natural sprite details, shadows and overlay behavior are preserved.
The palette applies on every surface and when existing saves load.

Factorio 2.0.76 prototype dumps for 0.3.3 and 0.3.4 differ only in 312
palette leaf values across 14 live prototypes and 14 corpse prototypes.
No runtime scripts, balance values, collision fields or spawning rules changed.

Native regression runs passed all 13 ramp-fluid/save-upgrade checks from
0.3.3 and all 14 wall/weather/combat integration checks with Space Age.
See tests/engine-results-0.3.4.txt for the results.
The headless checks validate prototype loading and gameplay; they do not
provide a rendered visual preview.

Previous integration records are retained under docs/history.
