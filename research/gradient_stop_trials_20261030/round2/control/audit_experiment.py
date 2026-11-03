"""Read-only content and resource gate; JSON output is emitted by the caller."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

root = Path(sys.argv[1]).resolve()
manifest = json.loads((root / 'CONTROL_MANIFEST.json').read_text())
files = {str(path.relative_to(root)) for folder in ['candidate', 'control', 'experiment', 'reference']
         for path in (root / folder).rglob('*') if path.is_file()}
files.update(['problem_manifest.json', 'results/frozen_options.mat'])
assert files == set(manifest), 'Frozen source inventory changed'
for name, digest in manifest.items():
    assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, name
bundle = Path('/home/lhtian97/Work/c04_external_comparison_20261010/bundle_r8')
frozen = json.loads((bundle / 'bundle_manifest.json').read_text())['bundle_hashes']
count = 0
for name, digest in frozen.items():
    if name.startswith(('optiprofiler/', 'helpers/', 'control/', 'mp/')):
        assert hashlib.sha256((bundle / name).read_bytes()).hexdigest() == digest, name
        count += 1
assert shutil.disk_usage(root).free >= 100 * 1024**3
if len(sys.argv) > 2 and sys.argv[2] == 'launch':
    assert json.loads((root / 'COUNTER_OFF_ACCEPTED.json').read_text())['status'] == 'accepted'
    assert json.loads((root / 'PREFLIGHT_ACCEPTED.json').read_text())['status'] == 'accepted'
    assert json.loads((root / 'PIPELINE_SMOKE_ACCEPTED.json').read_text())['status'] == 'accepted'
    for stage in ['regression', 'smoke', 'strict']:
        assert (root / 'results' / (stage + '.status')).read_text().startswith('completed exit_code=0'), stage
print(json.dumps({'control_files': len(manifest), 'frozen_dependency_files': count,
                  'free_bytes': shutil.disk_usage(root).free, 'status': 'verified'}, indent=2))
