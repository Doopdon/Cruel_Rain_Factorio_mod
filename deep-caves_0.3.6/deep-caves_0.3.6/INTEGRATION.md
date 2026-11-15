# Cruel Rain 0.3.7 verification

Factorio 2.1.24 native tests passed for spawning (14), fluids (13), integration
(14), difficulty (12), vents (5), collisions (1), and water (1).

Cave 1 now uses a 0.62 threshold on the existing seam-free flood noise.
It retains a dry 64-tile starter circle. Levels 2-5 retain the previous masks.
No existing-chunk water backfill is performed, preserving built factories.

A seed-17 coordinate sample found 17,468 wet positions out of 66,049 (26.4%).
This is a noise-mask sample, not a guarantee of map-wide floor coverage.
Starter-radius samples remained dry; 16,900 coordinate samples on Levels 2-5
matched version 0.3.5 exactly. Existing pools and vent puddles are unchanged.

Native save-upgrade checks with Space Age passed all 16 integration checks.
The native water suite checks wet Cave 1 tunnel floor tiles and dry starter ores.
Results are retained in tests/engine-results-0.3.6.txt.
