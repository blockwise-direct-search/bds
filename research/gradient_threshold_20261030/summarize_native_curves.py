"""Read native mean curves without changing or plotting any data."""

import json
from pathlib import Path
import sys

import numpy as np
from scipy.io import loadmat


root = Path(sys.argv[1])
records = []
for marker in sorted(root.glob("seed*/*/VERIFIED.json")):
    report = json.loads(marker.read_text())
    curves = loadmat(marker.parent / "curves.mat", simplify_cells=True)["curves"]
    for order in (2, 4):
        for kind in ("hist", "out"):
            means = [curves[order - 1][kind]["perf"][s, -1] for s in range(2)]
            # Native x coordinates are already log2 ratios. Evaluate both
            # right-continuous staircase means at the union of their knots.
            knots = np.unique(np.concatenate([curve[0] for curve in means]))
            values = []
            for curve in means:
                assert np.all(np.diff(curve[0]) >= 0)
                indices = np.searchsorted(curve[0], knots, side="right") - 1
                values.append(np.where(indices >= 0, curve[1, np.maximum(indices, 0)], 0))
            records.append({
                "seed": report["seed"], "feature": report["feature"],
                "tau": 10.0 ** (-order), "kind": kind,
                "old_terminal_fraction": float(means[0][1, -1]),
                "new_terminal_fraction": float(means[1][1, -1]),
                "max_absolute_mean_curve_gap": float(np.max(np.abs(values[0] - values[1]))),
            })
assert len(records) == 48
print(json.dumps({"source": "Native pairwise OptiProfiler curves; targets recomputed per run.",
                  "records": records}, indent=2))
