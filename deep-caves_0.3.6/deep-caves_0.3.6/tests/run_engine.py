"""Run the bundled cave, wall and weather checks in disposable Factorio worlds.

python tests/run_engine.py --factorio /path/to/factorio --suite integration
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--factorio', type=Path, required=True)
    parser.add_argument('--cave-walls', type=Path, help='Legacy standalone Cave Walls ZIP, required only for an old-save fixture.')
    parser.add_argument('--legacy-weather', type=Path, help='Legacy standalone Surface Thunderstorm ZIP for integration upgrade fixtures.')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--preset', choices=['default', 'minimum', 'maximum'], default='minimum')
    parser.add_argument('--seed', type=int, default=17)
    parser.add_argument('--space-age', action='store_true', help='Also enable the bundled Space Age, quality and elevated-rails mods.')
    parser.add_argument('--suite', choices=['spawning', 'vents', 'integration', 'fluids', 'difficulty', 'collisions', 'water'], default='spawning')
    parser.add_argument('--absorption', type=float, help='Override the vent absorption startup setting (0 to 100 pollution/minute).')
    parser.add_argument('--research-cost', type=float, help='Research multiplier override, 0.01 to 100.')
    parser.add_argument('--rocket-cost', type=float, help='Rocket launch multiplier override, 0.01 to 100.')
    parser.add_argument('--allow-cave-silos', action='store_true', help='Disable the above-ground restriction in the disposable fixture.')
    parser.add_argument('--upgrade-from', type=Path, help='Create the vent-test save with this older extracted mod first.')
    args = parser.parse_args()
    if not 0 <= args.seed <= 4294967295:
        parser.error('--seed must be between 0 and 4294967295')
    if args.upgrade_from and args.suite not in ('vents', 'integration', 'fluids', 'difficulty'):
        parser.error('--upgrade-from requires --suite vents, integration, fluids or difficulty')
    if args.absorption is not None and not 0 <= args.absorption <= 100:
        parser.error('--absorption must be between 0 and 100')
    for name in ('research_cost','rocket_cost'):
        value=getattr(args,name)
        if value is not None and not .01 <= value <= 100:
            parser.error('--'+name.replace('_','-')+' must be between 0.01 and 100')
    if args.upgrade_from:
        old_info=json.loads((args.upgrade_from / 'info.json').read_text())
        if any(dep.startswith('cave-walls') for dep in old_info.get('dependencies', [])) and not args.cave_walls:
            parser.error('This old version requires --cave-walls for its save fixture')
    exe = args.factorio.resolve()
    dependency = args.cave_walls.resolve() if args.cave_walls else None
    source = Path(__file__).resolve().parents[1]
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix='deep-caves-tests-'))
    if output == source or source in output.parents:
        parser.error('--output must be outside the mod source folder')
    output.mkdir(parents=True, exist_ok=True)
    mods = output / 'mods'
    mods.mkdir(exist_ok=True)
    info = json.loads((source / 'info.json').read_text())
    def install(mod_source, setup_upgrade=False):
        mod_info = json.loads((mod_source / 'info.json').read_text())
        target = mods / f"deep-caves_{mod_info['version']}"
        # Reusing an output folder must not let a newer leftover version win
        # when the first stage intentionally loads an older mod fixture.
        for installed in mods.glob('deep-caves_*'):
            if installed.is_dir(): shutil.rmtree(installed)
            elif installed.is_file(): installed.unlink()
        shutil.copytree(mod_source, target)
        module = {'spawning': 'engine', 'vents': 'engine_vents', 'integration': 'engine_integration', 'fluids': 'engine_fluids', 'difficulty': 'engine_difficulty', 'collisions': 'engine_collisions', 'water': 'engine_water'}[args.suite]
        if setup_upgrade or args.suite in ('fluids','difficulty'):
            shutil.copy2(source / f'tests/{module}.lua', target / f'tests/{module}.lua')
        control = (target / 'control.lua').read_text()
        if setup_upgrade or args.suite in ('fluids','difficulty'):
            marker = 'end)\n\nscript.on_configuration_changed'
            if marker not in control:
                raise ValueError('Cannot locate the older mod initialization hook')
            hook='setup_upgrade_fixture' if setup_upgrade else 'setup_save_fixture'
            control = control.replace(marker, f'  spawn_engine_suite.{hook}()\n' + marker, 1)
        control = 'local spawn_engine_suite\n' + control
        control += f'\nspawn_engine_suite=require("tests.{module}")\n'
        control += '''if spawn_engine_suite.tick then script.on_event(defines.events.on_tick,spawn_engine_suite.tick) end
script.on_nth_tick(137,function()
  local state=storage.deep_caves
  if not state.engine_prepared then state.engine_prepared=true;spawn_engine_suite.prepare()
  elseif not state.engine_tests_done then state.engine_tests_done=true;spawn_engine_suite.run() end
end)\n'''
        (target / 'control.lua').write_text(control)
        return target

    old_source = args.upgrade_from.resolve() if args.upgrade_from else None
    target = install(old_source or source, setup_upgrade=bool(old_source))
    legacy_folders = []
    if old_source:
        for archive_path in [dependency, args.legacy_weather]:
            if not archive_path:
                continue
            with zipfile.ZipFile(archive_path) as archive:
                for name in archive.namelist():
                    rel = Path(name)
                    if rel.is_absolute() or '..' in rel.parts:
                        raise ValueError('Unsafe dependency archive path')
                    # The supplied Cave Walls archive also contains an old
                    # Deep Caves ZIP beside its folder. Never install it.
                    if len(rel.parts) > 1:
                        archive.extract(name, mods)
                        if mods / rel.parts[0] not in legacy_folders:
                            legacy_folders.append(mods / rel.parts[0])
    fixture = mods / 'deep-caves-spawn-test_0.0.1'
    fixture.mkdir(exist_ok=True)
    (fixture / 'info.json').write_text(json.dumps({'name': 'deep-caves-spawn-test', 'version': '0.0.1',
        'title': 'Disposable cave spawning tests', 'author': 'Tests', 'factorio_version': '2.1',
        'dependencies': ['base', 'deep-caves']}))
    presets = {'default': (1, 12, 4, 3, 10, 1), 'minimum': (1, 1, 1, 1, 1, 1),
        'maximum': (8, 48, 16, 24, 24, 12)}
    settings = []
    for index, name in enumerate(('large', 'small', 'web')):
        settings.append(f'data.raw["int-setting"]["deep-caves-{name}-density"].default_value={presets[args.preset][index*2]}')
        settings.append(f'data.raw["int-setting"]["deep-caves-{name}-width"].default_value={presets[args.preset][index*2+1]}')
    if args.absorption is not None:
        settings.append('if data.raw["double-setting"]["deep-caves-vent-absorption"] then '
            f'data.raw["double-setting"]["deep-caves-vent-absorption"].default_value={args.absorption} end')
    for name, value in [('deep-caves-research-cost', args.research_cost), ('deep-caves-rocket-cost', args.rocket_cost)]:
        if value is not None:
            settings.append(f'if data.raw["double-setting"]["{name}"] then data.raw["double-setting"]["{name}"].default_value={value} end')
    if args.allow_cave_silos:
        settings.append('if data.raw["bool-setting"]["deep-caves-surface-silos-only"] then data.raw["bool-setting"]["deep-caves-surface-silos-only"].default_value=false end')
    (fixture / 'settings-updates.lua').write_text('\n'.join(settings) + '\n')
    if args.suite=='difficulty':
        (fixture/'data.lua').write_text('''local tiny=table.deepcopy(data.raw.technology["electric-mining-drill"])
tiny.name="deep-caves-test-tiny-research";tiny.prerequisites={};tiny.effects={};tiny.unit.count=1
local low=table.deepcopy(tiny)
low.name="deep-caves-test-low-formula-1";low.unit.count=nil;low.unit.count_formula="2^(L-1)";low.max_level="infinite"
data:extend{tiny,low}
''')
    if args.suite != 'vents':
        (fixture / 'data-final-fixes.lua').unlink(missing_ok=True)
    if args.suite == 'vents':
        # Isolate native entity absorption from terrain absorption in this
        # disposable fixture; production terrain prototypes are unchanged.
        (fixture / 'data-final-fixes.lua').write_text(
            'for _,tile in pairs(data.raw.tile) do tile.absorptions_per_second={} end\n')
    def write_mod_list(legacy):
        enabled = ['base', 'deep-caves', 'deep-caves-spawn-test']
        if legacy and dependency:
            enabled.append('cave-walls')
            if args.legacy_weather:
                enabled.append('surface-thunderstorm')
        (mods / 'mod-list.json').write_text(json.dumps({'mods': [{'name': name, 'enabled': True}
            for name in enabled] + [{'name': name, 'enabled': args.space_age}
            for name in ('space-age', 'quality', 'elevated-rails')]}))
    write_mod_list(bool(old_source))
    data = exe.parents[2] / 'data'
    config = output / 'config.ini'
    config.write_text('[path]\nread-data=' + data.as_posix() + '\nwrite-data=' + output.as_posix()
        + '\n[other]\ncheck-updates=false\n')
    map_gen = output / 'map-gen.json'
    map_gen.write_text(json.dumps({'seed': args.seed}))
    common = [str(exe), '--config', str(config), '--mod-directory', str(mods)]
    create = subprocess.run(common + ['--create', str(output / 'world.zip'), '--map-gen-settings', str(map_gen)],
        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (output / 'create.log').write_text(create.stdout)
    for line in create.stdout.splitlines():
        if 'DC_ENGINE' in line or 'Error' in line:
            print(line, flush=True)
    if create.returncode:
        print(create.stdout[-6000:])
        raise SystemExit(create.returncode or 1)
    if old_source:
        shutil.rmtree(target)
        for folder in legacy_folders:
            shutil.rmtree(folder)
        target = install(source)
        write_mod_list(False)
    benchmark = subprocess.run(common + ['--benchmark', str(output / 'world.zip'), '--benchmark-ticks', '600',
        '--benchmark-runs', '1'], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (output / 'reload.log').write_text(benchmark.stdout)
    for line in benchmark.stdout.splitlines():
        if 'DC_ENGINE' in line or 'Error' in line:
            print(line, flush=True)
    if benchmark.returncode or 'DC_ENGINE RESULT' not in benchmark.stdout:
        print(benchmark.stdout[-6000:])
        raise SystemExit(benchmark.returncode or 1)
    print('PASS real-engine save/reload and 600 simulation ticks', flush=True)
    print(f'Logs: {output}', flush=True)


if __name__ == '__main__':
    main()
