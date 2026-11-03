"""Read-only audit of the production transplant and frozen experiment."""

import hashlib
import json
from pathlib import Path
import subprocess
import sys

workspace = Path(sys.argv[1])
candidate = workspace / "candidate"
experiment = Path('/home/lhtian97/Work/bds_gradient_threshold_20261030')


def executable_lines(path):
    # Only full comment lines and empty lines are removed. Do not strip '%' in
    # code strings, continuations, or normalize actual expressions/operators.
    return '\n'.join(line for line in path.read_text().splitlines()
                     if line.strip() and not line.lstrip().startswith('%'))


actual = executable_lines(candidate / 'src/bds.m')
tested = executable_lines(experiment / 'candidate/src/bds_dual_threshold.m')
tested = tested.replace('= bds_dual_threshold(fun, x0, options)', '= bds(fun, x0, options)', 1)
assert actual == tested, 'Production executable statements differ from the tested candidate'
private_files = sorted((candidate / 'src/private').glob('*.m'))
for file in private_files:
    original = experiment / 'candidate/src/private' / file.name
    if file.name == 'set_options.m':
        expected = original.read_text().replace(
            'options.grad_tol for the single reference-scaled threshold.',
            'options.grad_tol for the reference-scaled gradient stopping criterion.')
        assert file.read_text() == expected
    else:
        assert file.read_bytes() == original.read_bytes(), file

subprocess.run(['python3', str(experiment / 'control/prepare.py'), str(experiment), 'audit'], check=True)
manifest = json.loads((workspace / 'SYNC_MANIFEST.json').read_text())
for relative, digest in manifest.items():
    assert hashlib.sha256((candidate / relative).read_bytes()).hexdigest() == digest, relative
assert set(manifest) == {str(p.relative_to(candidate)) for p in candidate.rglob('*') if p.is_file()}
print(json.dumps({'status': 'verified', 'production_matches_tested_executable_statements': True,
                  'private_matlab_files': len(private_files), 'synced_files': len(manifest)}))
