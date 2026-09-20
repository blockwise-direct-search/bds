#!/usr/bin/env python3
"""Classify solver flags recorded in one accepted TSFSB feature manifest.

Ported from the C02 c02_v14_solver_flag_gate.py. The gate reads an accepted
feature manifest, expands the abnormal termination and output fallback flag
arrays into per-(problem, solver, run) entries, and fails on any flag whose
(problem, solver, run) tuple is not listed in ALLOWED_FAILURES below. New
failures are investigated and classified by appending entries with their
classification evidence; the gate fails as long as a flag is unclassified.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


# No solver failure has been classified yet. Each accepted classification
# must record the classification, the exception identifier, the origin, the
# output disposition, and the expected evaluation count, as in C02.
ALLOWED_FAILURES = {
    ("plain", "INDEF", "fd-bfgs", 1): {
        "classification": "reproducible_solver_failure",
        "exception_id": "MATLAB:roots:NonFiniteInput",
        "origin": "MATLAB fminunc lineSearch",
        "output_disposition": "OptiProfiler initial point penalty",
        "expected_evaluation_count": 3619,
    },
    ("linearly_transformed", "INDEF", "fd-bfgs", 1): {
        "classification": "reproducible_solver_failure",
        "exception_id": "MATLAB:roots:NonFiniteInput",
        "origin": "MATLAB fminunc lineSearch",
        "output_disposition": "OptiProfiler initial point penalty",
        "expected_evaluation_count": 3653,
    },
    ("linearly_transformed", "INDEF", "fd-bfgs", 2): {
        "classification": "reproducible_solver_failure",
        "exception_id": "MATLAB:roots:NonFiniteInput",
        "origin": "MATLAB fminunc lineSearch",
        "output_disposition": "OptiProfiler initial point penalty",
        "expected_evaluation_count": 3620,
    },
    ("linearly_transformed", "INDEF", "fd-bfgs", 3): {
        "classification": "reproducible_solver_failure",
        "exception_id": "MATLAB:roots:NonFiniteInput",
        "origin": "MATLAB fminunc lineSearch",
        "output_disposition": "OptiProfiler initial point penalty",
        "expected_evaluation_count": 3587,
    },
    ("linearly_transformed", "INDEF", "fd-bfgs", 4): {
        "classification": "reproducible_solver_failure",
        "exception_id": "MATLAB:roots:NonFiniteInput",
        "origin": "MATLAB fminunc lineSearch",
        "output_disposition": "OptiProfiler initial point penalty",
        "expected_evaluation_count": 3655,
    },
    ("linearly_transformed", "INDEF", "fd-bfgs", 5): {
        "classification": "reproducible_solver_failure",
        "exception_id": "MATLAB:roots:NonFiniteInput",
        "origin": "MATLAB fminunc lineSearch",
        "output_disposition": "OptiProfiler initial point penalty",
        "expected_evaluation_count": 3666,
    },
}


def flag_entries(manifest: dict[str, object], flag_key: str) -> list[dict[str, object]]:
    feature = manifest["feature"]["name"]
    problem_names = manifest["problem_names"]
    machine_ids = manifest["machine_ids"]
    evaluation_counts = manifest["evaluation_counts"]
    flags = manifest[flag_key]
    entries = []
    n_problems = len(problem_names)
    n_solvers = len(machine_ids)
    n_runs = manifest["n_runs"]
    # MATLAB jsonencode writes an N-D array as nested lists indexed
    # [problem][solver][run]. A trailing singleton run dimension may be
    # encoded at depth two; normalize both encodings to depth three.
    if n_runs == 1 and not isinstance(flags[0][0], list):
        flags = [[[flags[p][s]] for s in range(n_solvers)] for p in range(n_problems)]
    if (
        len(flags) != n_problems
        or len(flags[0]) != n_solvers
        or len(flags[0][0]) != n_runs
    ):
        raise RuntimeError(
            f"The {flag_key} array shape does not match the manifest shape."
        )
    for i_problem in range(n_problems):
        for i_solver in range(n_solvers):
            for i_run in range(n_runs):
                if not flags[i_problem][i_solver][i_run]:
                    continue
                count = evaluation_counts[i_problem][i_solver]
                if isinstance(count, list):
                    count = count[i_run]
                entries.append(
                    {
                        "feature": feature,
                        "problem": problem_names[i_problem],
                        "solver": machine_ids[i_solver],
                        "run": i_run + 1,
                        "evaluation_count": count,
                    }
                )
    return entries


def entry_key(entry: dict[str, object]) -> tuple[object, ...]:
    return (
        entry["feature"],
        entry["problem"],
        entry["solver"],
        entry["run"],
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()

    manifest = json.loads(arguments.manifest.read_text(encoding="utf-8"))
    if manifest.get("status") != "accepted":
        raise RuntimeError("The manifest does not have status accepted.")
    feature = manifest["feature"]["name"]
    abnormal = flag_entries(manifest, "abnormal_termination_flags")
    fallback = flag_entries(manifest, "output_fallback_flags")

    unclassified_abnormal = sorted(
        key for key in (entry_key(entry) for entry in abnormal)
        if key not in ALLOWED_FAILURES
    )
    unclassified_fallback = sorted(
        key for key in (entry_key(entry) for entry in fallback)
        if key not in ALLOWED_FAILURES
    )
    if unclassified_abnormal or unclassified_fallback:
        raise RuntimeError(
            "Unclassified solver flags: "
            f"abnormal={unclassified_abnormal} "
            f"fallback={unclassified_fallback}"
        )

    dispositions = []
    for entry in abnormal + fallback:
        key = entry_key(entry)
        expected = ALLOWED_FAILURES[key]
        errors = manifest.get("raw_traces", {}).get("failures", [])
        if isinstance(errors, dict):
            errors = [errors]
        matching = [e for e in errors if e["problem"] == entry["problem"]
                    and e["solver"] == entry["solver"] and e["run"] == entry["run"]]
        if len(matching) != 1 or matching[0]["identifier"] != expected["exception_id"]:
            raise RuntimeError(f"Exception evidence does not match prior classification: {key}")
        if entry["evaluation_count"] != expected["expected_evaluation_count"]:
            raise RuntimeError(
                f"Unexpected evaluation count for {key}: "
                f"{entry['evaluation_count']} instead of "
                f"{expected['expected_evaluation_count']}."
            )
        disposition = dict(entry)
        disposition.update(expected)
        dispositions.append(disposition)

    result = {
        "status": (
            "accepted_with_classified_solver_failures"
            if dispositions
            else "accepted_without_solver_failures"
        ),
        "feature": feature,
        "abnormal_termination_count": len(abnormal),
        "output_fallback_count": len(fallback),
        "dispositions": dispositions,
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = arguments.output.with_name(arguments.output.name + ".tmp")
    temporary.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(arguments.output)
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
