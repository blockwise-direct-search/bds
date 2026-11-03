"""Require all final gates to pass, then summarize the saved verification."""

import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

from scipy.io import loadmat


root = Path(sys.argv[1])
stages = ('focused', 'regression', 'mp_strict_gradient_off', 'matrix_retry2', 's2mpj_retry1')
gates = {}
for stage in stages:
    status = (root / 'results' / (stage + '.status')).read_text().strip()
    assert status.startswith('completed exit_code=0 '), (stage, status)
    summary = loadmat(root / 'results' / stage / 'stage_summary.mat', simplify_cells=True)['summary']
    gates[stage] = {'status': status, 'summary': summary}

assert gates['mp_strict_gradient_off']['summary'] == {
    'iseqiv_passed': 1890, 'full_trace_passed': 1890, 'failed': 0}
assert gates['matrix_retry2']['summary']['candidate_cases'] == 480
assert gates['matrix_retry2']['summary']['historical_cases'] == 240
assert gates['matrix_retry2']['summary']['gradient_stops'] > 0
assert gates['s2mpj_retry1']['summary']['candidate_cases'] == 192
assert gates['s2mpj_retry1']['summary']['gradient_stops'] > 0
assert len(list((root / 'results/s2mpj_retry1').glob('case_*.mat'))) == 192
regression = (root / 'logs/regression.log').read_text()
assert len(re.findall(r'\[acceleration-off-Algorithm-[^\]]+\] case \d+/270 passed', regression)) == 1350
assert 'GRADIENT_STOPPING_THRESHOLD_OK behavior=120 shared=1 changed=1 disabled=1' in regression
assert 'BDS_REGRESSION_SUITE_OK' in regression
audit = subprocess.run(['python3', str(root / 'control/audit.py'), str(root)],
                       check=True, capture_output=True, text=True)
audits = [json.loads(line) for line in audit.stdout.splitlines() if line.startswith('{')]
attempts = {stage: (root / 'results' / (stage + '.status')).read_text().strip()
            for stage in ('matrix', 'matrix_retry1', 's2mpj')}
files = [root / 'candidate/src/bds.m', root / 'SYNC_MANIFEST.json']
files += sorted(p for p in (root / 'control').iterdir() if p.is_file())
hashes = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
print(json.dumps({
    'status': 'verified', 'gates': gates, 'source_audits': audits,
    'acceleration_off_cases': 1350, 'gradient_black_box_cases': 120,
    'prior_attempt_statuses': attempts,
    'prior_attempt_notes': {
        'matrix': 'All assertions passed, then MATLAB aborted during exit with heap corruption. Retained; not counted as a passing run.',
        'matrix_retry1': 'Unchanged rerun completed normally. Repeated once more after the S2MPJ scheduling-only test edit.',
        's2mpj': 'Single-process run intentionally terminated to rerun all 192 unchanged cases with eight workers.'},
    'runtime_warnings': {
        's2mpj_retry1': 'All 192 assertions and the summary completed before pool shutdown. One worker left an abort crash dump during shutdown; the client exited with code 0. The dump is retained on the server. This is not a claim of an anomaly-free MATLAB runtime.'},
    'hashes': hashes,
    'external_solver_benchmark_run': False,
    'paper_modified': False,
    'full_trace_comparison': 'isequaln, no tolerances or history truncation',
}, indent=2))
