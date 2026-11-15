from pathlib import Path
import json, subprocess, shutil, zipfile
root=Path.cwd()
exe=Path(r'C:\Program Files (x86)\Steam\steamapps\common\Factorio\bin\x64\factorio.exe')
out=root/'.validation'
sources=sorted(p.parent for p in root.glob('*/*/info.json'))
mods=out/'combined'/'mods'; mods.mkdir(parents=True,exist_ok=True)
for source in sources:
 info=json.loads((source/'info.json').read_text())
 target=mods/f"{info['name']}_{info['version']}"
 shutil.copytree(source,target,dirs_exist_ok=True)
for space in (False,True):
 work=out/('combined-space-age' if space else 'combined-base');work.mkdir(exist_ok=True)
 enabled=[json.loads((s/'info.json').read_text())['name'] for s in sources]+['base']
 (mods/'mod-list.json').write_text(json.dumps({'mods':[{'name':n,'enabled':True} for n in enabled]+[{'name':n,'enabled':space} for n in ('space-age','quality','elevated-rails')]}))
 config=work/'config.ini';config.write_text('[path]\nread-data='+ (exe.parents[2]/'data').as_posix()+'\nwrite-data='+work.as_posix()+'\n[other]\ncheck-updates=false\n')
 common=[str(exe),'--config',str(config),'--mod-directory',str(mods)]
 for label,args in [('create',['--create',str(work/'world.zip')]),('reload',['--benchmark',str(work/'world.zip'),'--benchmark-ticks','3600','--benchmark-runs','1'])]:
  r=subprocess.run(common+args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
  (work/(label+'.log')).write_text(r.stdout)
  if r.returncode: print(r.stdout[-8000:]);raise SystemExit(r.returncode)
  print(f'PASS all three mods together: {work.name} {label}',flush=True)
for suite in ('spawning','fluids','difficulty','vents','collisions','water'):
 r=subprocess.run(['python',str(root/'deep-caves_0.3.6/deep-caves_0.3.6/tests/run_engine.py'),'--factorio',str(exe),'--suite',suite,'--output',str(out/suite)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 (out/(suite+'.txt')).write_text(r.stdout)
 print('\n'.join(x for x in r.stdout.splitlines() if 'RESULT' in x or x.startswith('PASS')),flush=True)
 if r.returncode: print(r.stdout[-8000:]);raise SystemExit(r.returncode)
