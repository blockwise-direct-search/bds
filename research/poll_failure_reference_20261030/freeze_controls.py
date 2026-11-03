"""Freeze the complete experiment source inventory before the formal run."""
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
assert not (root / 'compute.status').exists(), 'Do not change a running experiment'
files = [path for folder in ['candidate', 'control', 'experiment', 'reference']
         for path in (root / folder).rglob('*') if path.is_file()]
files.extend([root / 'problem_manifest.json', root / 'results/frozen_options.mat'])
manifest = {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(files)}
target = root / 'CONTROL_MANIFEST.json'
if target.exists():
    previous = target.read_bytes()
    digest = hashlib.sha256(previous).hexdigest()
    backup = root / 'evidence' / ('CONTROL_MANIFEST_' + digest + '.json')
    if not backup.exists():
        backup.write_bytes(previous)
target.write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps({'files': len(manifest),
                  'manifest_sha256': hashlib.sha256(target.read_bytes()).hexdigest()}, indent=2))
