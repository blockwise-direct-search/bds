"""Read-only inventory of the two explicitly retired experiment directories.

Run on the experiment server before deletion. Output is JSON on stdout.
This utility neither starts MATLAB nor changes any file or process.
"""

import csv
import datetime
import hashlib
import json
import pathlib
import subprocess


ROOTS = {
    "round1": pathlib.Path("/home/lhtian97/Work/.bds_experiment_trash/bds_gradient_stop_20261029"),
    "round2": pathlib.Path("/home/lhtian97/Work/bds_poll_failure_reference_20261030"),
}


def retained_files(root):
    files = list(root.glob("*.json")) + list(root.glob("*.status"))
    files += list(root.glob("REPORT.md"))
    files += [p for p in (root / "control").rglob("*") if p.is_file()]
    for pattern in ("*.json", "*.csv", "selection.mat"):
        files += list((root / "selection").glob(pattern))
    files += list((root / "results").glob("*.status"))
    files += list((root / "results").glob("frozen_options.mat"))
    for folder in ("baseline", "validation"):
        files += list((root / folder).glob("ACCEPTED.json"))
    for pattern in ("*audit.json", "validation.log", "selection.log", "experiment_screen.log"):
        files += list((root / "logs").glob(pattern))
    return sorted(set(files))


report = {"captured_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "rounds": {}}
for label, root in ROOTS.items():
    assert root.is_dir() and not root.is_symlink()
    completed = sorted(p.name for p in (root / "validation").glob("f*_p*_r*.mat"))
    baseline = sorted(p.name for p in (root / "baseline").glob("f*_p*_r*.mat"))
    files = retained_files(root)
    assert all(not p.is_symlink() for p in files)
    entry = {
        "source": str(root),
        "allocated_kib": int(subprocess.check_output(["du", "-sk", str(root)], text=True).split()[0]),
        "baseline_cases": len(baseline),
        "validation_cases": len(completed),
        "completed_validation_files": completed,
        "remaining_validation_files": sorted(set(baseline) - set(completed)),
        "fresh_seed_directory_exists": (root / "fresh").exists(),
        "sha256": {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
    }
    if label == "round2":
        names = json.loads((root / "problem_manifest.json").read_text())["problem_names"]
        features = ["plain", "noisy_1e-4", "noisy_1e-2", "linearly_transformed",
                    "linearly_transformed_noisy_1e-4", "linearly_transformed_noisy_1e-2"]
        columns = ["gradient_history_loss", "gradient_output_loss", "joint_history_loss", "joint_output_loss"]
        counts = dict.fromkeys(columns, 0)
        failed = set()
        with (root / "selection" / "selected_cases.csv").open() as stream:
            for row in csv.DictReader(stream):
                if float(row["tau"]) != 1e-4:
                    continue
                filename = "f%d_p%03d_r%d.mat" % (
                    features.index(row["feature"]) + 1, names.index(row["problem"]) + 1, int(row["repeat"]))
                if filename not in completed:
                    continue
                for column in columns:
                    counts[column] += int(row[column])
                if int(row["gradient_history_loss"]) or int(row["gradient_output_loss"]):
                    failed.add(row["problem"])
        entry["verified_prediction_losses_tau_1e_4"] = counts
        entry["gradient_loss_problem_names"] = sorted(failed)
    report["rounds"][label] = entry
print(json.dumps(report, indent=2))
