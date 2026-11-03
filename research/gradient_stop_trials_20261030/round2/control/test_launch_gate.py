"""Exercise the status gate using temporary runtime fixtures, never launch MATLAB."""
import os
from pathlib import Path
import subprocess
import tempfile

script = Path(__file__).with_name('run_after_verification.sh')
with tempfile.TemporaryDirectory(prefix='bds-poll-gate-') as directory:
    root = Path(directory)
    (root / 'results').mkdir()
    environment = dict(os.environ, BDS_LAUNCH_ROOT=str(root))

    def check(expected):
        result = subprocess.run(['bash', str(script), '--check-only'], env=environment,
                                capture_output=True, text=True)
        assert result.returncode == expected, (result.returncode, result.stderr)

    check(10)
    names = ['results/regression.status', 'results/smoke.status', 'results/strict.status',
             'preflight.status', 'pipeline_smoke.status']
    for name in names:
        (root / name).write_text('completed exit_code=0 utc=test\n')
    check(0)
    (root / names[-1]).write_text('started utc=test\n')
    check(10)
    (root / names[0]).write_text('failed exit_code=1 utc=test\n')
    check(1)
    (root / names[0]).write_text('completed exit_code=9 utc=test\n')
    check(1)
    (root / names[0]).write_text('unknown\n')
    check(1)
print('LAUNCH_GATE_TEST_OK missing/running/success/failure/nonzero/unknown')
