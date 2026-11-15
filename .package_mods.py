from pathlib import Path
import json, zipfile
root=Path.cwd()
sources=sorted(p.parent for p in root.glob('*/*/info.json'))
old=list(root.glob('*.zip'))+list(root.glob('*/*.zip'))
for source in sources:
 info=json.loads((source/'info.json').read_text())
 name=f"{info['name']}_{info['version']}"
 archive=root/(name+'.zip')
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
  for f in sorted(source.rglob('*')):
   if f.is_file() and '__pycache__' not in f.parts and f.suffix!='.pyc':
    z.write(f, name+'/'+f.relative_to(source).as_posix())
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None
  assert json.loads(z.read(name+'/info.json'))==info
  for f in source.rglob('*'):
   if f.is_file() and '__pycache__' not in f.parts and f.suffix!='.pyc':
    assert z.read(name+'/'+f.relative_to(source).as_posix())==f.read_bytes()
 print('Verified',archive.name,archive.stat().st_size,'bytes')
for f in old:
 assert f.resolve().is_relative_to(root.resolve())
 f.unlink()
 print('Deleted old ZIP:',f.relative_to(root))
