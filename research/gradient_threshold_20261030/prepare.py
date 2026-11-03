"""Generate one isolated experimental entry and audit its exact source delta."""

import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
old = """                if reference_grad_norm_initialized ...
                        && all(norm_grad_window ...
                            < grad_tol * max(1, reference_grad_norm))"""
new = """                if reference_grad_norm_initialized ...
                        && (all(norm_grad_window ...
                            < grad_tol * min(1, reference_grad_norm)) ...
                            || all(norm_grad_window ...
                            < 1e-3 * grad_tol * max(1, reference_grad_norm)))"""
source = root / 'candidate/src/bds.m'
target = root / 'candidate/src/bds_dual_threshold.m'
code = source.read_text()
assert code.count(old) == 1
assert code.count('= bds(fun, x0, options)') == 1
expected = code.replace('= bds(fun, x0, options)', '= bds_dual_threshold(fun, x0, options)', 1)
expected = expected.replace(old, new, 1)
mode = sys.argv[2]
if mode == 'prepare':
    assert not target.exists() and not (root / 'CONTROL_MANIFEST.json').exists()
    target.write_text(expected)
else:
    assert mode in ('audit', 'freeze')
    if mode == 'freeze':
        assert not (root / 'CONTROL_MANIFEST.json').exists() and not (root / 'run.status').exists()
assert target.read_text() == expected, 'Unexpected solver change beyond the final predicate'
folders = ['candidate', 'control', 'reference']
files = [p for folder in folders for p in (root / folder).rglob('*') if p.is_file()]
files += [root / 'problem_manifest.json', root / 'results/frozen_options.mat']
hashes = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}
bundle = Path('/home/lhtian97/Work/c04_external_comparison_20261010/bundle_r8')
frozen = json.loads((bundle / 'bundle_manifest.json').read_text())['bundle_hashes']
dependency_hashes = {n: h for n, h in frozen.items() if n.startswith(('optiprofiler/', 'helpers/', 'control/', 'mp/'))}
for name, digest in dependency_hashes.items():
    assert hashlib.sha256((bundle / name).read_bytes()).hexdigest() == digest, name
manifest = {'source_hashes': hashes, 'dependency_hashes': dependency_hashes}
if mode in ('prepare', 'freeze'):
    (root / 'CONTROL_MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
else:
    assert json.loads((root / 'CONTROL_MANIFEST.json').read_text()) == manifest
print(json.dumps({'status': 'verified', 'files': len(hashes), 'dependencies': len(dependency_hashes),
                  'only_final_predicate_changed': True}))
