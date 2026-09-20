#!/usr/bin/env python3
"""Generate or verify the final TSFSB aggregate audit and artifact inventory.

Ported from the C02 c02_v14_finalize.py. The script aggregates the ten
accepted feature manifests and their solver flag dispositions, checks the
fixed protocol (feature set, solver order, run counts, dimensions, budgets,
seed, worker count, version consistency), and builds a SHA-256 inventory TSV
covering the whole artifact root. The problem count is never hardcoded; it is
read from the frozen problem manifest JSON passed with --problem-manifest.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path


FEATURES = (
    "plain",
    "noisy_1e-1",
    "noisy_1e-2",
    "noisy_1e-3",
    "noisy_1e-4",
    "linearly_transformed",
    "linearly_transformed_noisy_1e-1",
    "linearly_transformed_noisy_1e-2",
    "linearly_transformed_noisy_1e-3",
    "linearly_transformed_noisy_1e-4",
)
DISPLAY_NAMES = (
    "BDS",
    "BDS without acceleration",
    "DS",
    "NOMAD",
    "LAM",
    "NEWUOA",
    "FD-BFGS",
    "PDS",
    "BFO",
    "Nelder-Mead",
)
MACHINE_IDS = (
    "bds",
    "bds-no-acceleration",
    "ds",
    "nomad",
    "lam",
    "newuoa",
    "fd-bfgs",
    "pds",
    "bfo",
    "nelder-mead",
)
BUDGET_FACTOR = 500
WORKER_COUNT = 30
BASE_SEED = 20260828


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def atomic_write(path: Path, contents: str) -> None:
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(contents, encoding="utf-8")
    temporary.replace(path)


def expected_runs(feature: str) -> int:
    return 1 if feature == "plain" else 5


def collect_feature_summaries(
    artifact_root: Path, problem_count: int
) -> list[dict[str, object]]:
    evaluation_root = artifact_root / "evaluations"
    summaries = []
    reference_versions = None
    for feature in FEATURES:
        feature_root = evaluation_root / feature
        manifest_path = feature_root / "accepted_manifest.json"
        disposition_path = feature_root / "solver_flag_disposition.json"
        if not manifest_path.is_file():
            raise RuntimeError(f"Missing accepted manifest for {feature}.")
        if not disposition_path.is_file():
            raise RuntimeError(f"Missing solver flag disposition for {feature}.")
        manifest = load_json(manifest_path)
        disposition = load_json(disposition_path)

        if manifest["status"] != "accepted":
            raise RuntimeError(f"Manifest not accepted for {feature}.")
        if manifest["feature"]["name"] != feature:
            raise RuntimeError(f"Feature mismatch for {feature}.")
        if manifest["kind"] != "full_feature":
            raise RuntimeError(f"Unexpected manifest kind for {feature}.")
        if len(manifest["problem_names"]) != problem_count:
            raise RuntimeError(f"Problem count mismatch for {feature}.")
        if manifest["solver_names"] != list(DISPLAY_NAMES):
            raise RuntimeError(f"Solver order mismatch for {feature}.")
        if manifest["machine_ids"] != list(MACHINE_IDS):
            raise RuntimeError(f"Machine identifier mismatch for {feature}.")
        if manifest["n_runs"] != expected_runs(feature):
            raise RuntimeError(f"Run count mismatch for {feature}.")
        if manifest["base_seed"] != BASE_SEED:
            raise RuntimeError(f"Base seed mismatch for {feature}.")
        if manifest["worker_count"] != WORKER_COUNT:
            raise RuntimeError(f"Worker count mismatch for {feature}.")
        if manifest["budget_factor"] != BUDGET_FACTOR:
            raise RuntimeError(f"Budget factor mismatch for {feature}.")
        if manifest["pdf_postprocessing"]:
            raise RuntimeError(f"PDF postprocessing recorded for {feature}.")
        dimensions = manifest["problem_dimensions"]
        if min(dimensions) < 6 or max(dimensions) > 50:
            raise RuntimeError(f"Dimension range violation for {feature}.")
        n_solvers = len(manifest["machine_ids"])
        n_runs = manifest["n_runs"]
        flat_counts = []
        for i_problem, per_solver in enumerate(manifest["evaluation_counts"]):
            if len(per_solver) != n_solvers:
                raise RuntimeError(f"Evaluation count shape mismatch for {feature}.")
            budget = BUDGET_FACTOR * dimensions[i_problem]
            for per_run in per_solver:
                counts = per_run if isinstance(per_run, list) else [per_run]
                if len(counts) != n_runs:
                    raise RuntimeError(
                        f"Evaluation count shape mismatch for {feature}."
                    )
                for count in counts:
                    if count < 0 or count > budget:
                        raise RuntimeError(f"Budget violation for {feature}.")
                    flat_counts.append(count)
        if (
            manifest["abnormal_termination_count"]
            != disposition["abnormal_termination_count"]
            or manifest["output_fallback_count"]
            != disposition["output_fallback_count"]
        ):
            raise RuntimeError(f"Flag count mismatch for {feature}.")
        versions = manifest["versions"]
        if reference_versions is None:
            reference_versions = versions
        elif versions != reference_versions:
            raise RuntimeError(f"Source version mismatch for {feature}.")

        summaries.append(
            {
                "feature": feature,
                "runs": manifest["n_runs"],
                "problems": len(manifest["problem_names"]),
                "outcomes": len(flat_counts),
                "minimum_evaluation_count": min(flat_counts),
                "maximum_evaluation_count": max(flat_counts),
                "abnormal_termination_count": manifest[
                    "abnormal_termination_count"
                ],
                "output_fallback_count": manifest["output_fallback_count"],
                "result_root": manifest["result_root"],
                "manifest_path": str(manifest_path),
                "manifest_sha256": sha256(manifest_path),
                "solver_flag_disposition_path": str(disposition_path),
                "solver_flag_disposition_sha256": sha256(disposition_path),
            }
        )
    return summaries


def inventory_entries(
    artifact_root: Path, inventory_relative: Path
) -> list[tuple[str, int, str]]:
    entries = []
    for path in sorted(artifact_root.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(artifact_root)
        if path.name.endswith(".tmp"):
            raise RuntimeError(f"Temporary file remains in artifact root: {path}.")
        if relative == inventory_relative or relative.parts[0] == "logs":
            # Live driver/screen logs and exit markers are operational, not frozen data.
            continue
        entries.append((relative.as_posix(), path.stat().st_size, sha256(path)))
    return entries


def aggregate_document(artifact_root: Path, problem_count: int) -> dict[str, object]:
    summaries = collect_feature_summaries(artifact_root, problem_count)
    planned_outcomes = (
        sum(expected_runs(feature) for feature in FEATURES)
        * problem_count
        * len(MACHINE_IDS)
    )
    actual_outcomes = sum(item["outcomes"] for item in summaries)
    if actual_outcomes != planned_outcomes:
        raise RuntimeError(
            f"Outcome count mismatch: {actual_outcomes} instead of "
            f"{planned_outcomes}."
        )
    return {
        "schema_version": 1,
        "status": "accepted_after_final_reverification",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "artifact_root": str(artifact_root),
        "fixed_protocol": {
            "features": list(FEATURES),
            "solvers": list(DISPLAY_NAMES),
            "machine_ids": list(MACHINE_IDS),
            "problem_library": "s2mpj",
            "problem_type": "u",
            "problem_count": problem_count,
            "minimum_dimension": 6,
            "maximum_dimension": 50,
            "budget_factor": BUDGET_FACTOR,
            "base_seed": BASE_SEED,
            "plain_runs": 1,
            "stochastic_feature_runs": 5,
            "worker_count": WORKER_COUNT,
        },
        "feature_summaries": summaries,
        "totals": {
            "accepted_feature_count": len(summaries),
            "planned_outcomes": planned_outcomes,
            "actual_outcomes": actual_outcomes,
            "abnormal_termination_count": sum(
                item["abnormal_termination_count"] for item in summaries
            ),
            "output_fallback_count": sum(
                item["output_fallback_count"] for item in summaries
            ),
            "unclassified_solver_flag_count": 0,
        },
        "pdf_postprocessing": False,
    }


def markdown_report(aggregate: dict[str, object]) -> str:
    lines = [
        "# TSFSB aggregate audit",
        "",
        "Status: accepted after final re-verification.",
        "",
        "All ten features use the same frozen problem manifest, solver pool, "
        "seed protocol, budget protocol, and worker protocol. All recorded "
        "function evaluation counts satisfy the 500N budget. No PDF "
        "postprocessing was performed.",
        "",
        "| Feature | Runs | Outcomes | Abnormal | Fallback |",
        "|---|---:|---:|---:|---:|",
    ]
    for item in aggregate["feature_summaries"]:
        lines.append(
            f"| `{item['feature']}` | {item['runs']} | {item['outcomes']} | "
            f"{item['abnormal_termination_count']} | "
            f"{item['output_fallback_count']} |"
        )
    lines.append("")
    return "\n".join(lines)


def verify_inventory(
    artifact_root: Path, inventory_path: Path, inventory_relative: Path
) -> None:
    lines = inventory_path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "relative_path\tbytes\tsha256":
        raise RuntimeError("Invalid inventory header.")
    recorded_entries = []
    for line in lines[1:]:
        relative_text, bytes_text, digest = line.split("\t")
        path = artifact_root / relative_text
        if not path.is_file():
            raise RuntimeError(f"Missing inventoried file {path}.")
        size = int(bytes_text)
        if path.stat().st_size != size or sha256(path) != digest:
            raise RuntimeError(f"Inventory mismatch for {path}.")
        recorded_entries.append((relative_text, size, digest))
    if recorded_entries != inventory_entries(artifact_root, inventory_relative):
        raise RuntimeError(
            "The inventory does not cover the complete artifact root."
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("generate", "verify"))
    parser.add_argument("artifact_root", type=Path)
    parser.add_argument(
        "--problem-manifest",
        required=True,
        type=Path,
        help="Frozen problem_manifest.json providing the problem count.",
    )
    arguments = parser.parse_args()

    artifact_root = arguments.artifact_root
    problem_manifest = load_json(arguments.problem_manifest)
    problem_count = problem_manifest["problem_count"]

    audit_directory = artifact_root / "audit"
    aggregate_path = audit_directory / "tsfsb_aggregate_audit.json"
    report_path = audit_directory / "tsfsb_aggregate_audit.md"
    inventory_path = audit_directory / "tsfsb_artifact_inventory.tsv"
    inventory_relative = inventory_path.relative_to(artifact_root)

    if arguments.mode == "generate":
        for path in (aggregate_path, report_path, inventory_path):
            if path.exists():
                raise RuntimeError(
                    f"Refusing to overwrite existing final record {path}."
                )
        audit_directory.mkdir(parents=True, exist_ok=True)
        aggregate = aggregate_document(artifact_root, problem_count)
        atomic_write(
            aggregate_path,
            json.dumps(aggregate, indent=2, sort_keys=True) + "\n",
        )
        atomic_write(report_path, markdown_report(aggregate))
        lines = ["relative_path\tbytes\tsha256"]
        lines.extend(
            f"{path}\t{size}\t{digest}"
            for path, size, digest in inventory_entries(
                artifact_root, inventory_relative
            )
        )
        atomic_write(inventory_path, "\n".join(lines) + "\n")
        # Immediately verify the freshly written inventory.
        verify_inventory(artifact_root, inventory_path, inventory_relative)
        status = "generated_and_verified"
    else:
        aggregate = aggregate_document(artifact_root, problem_count)
        recorded = load_json(aggregate_path)
        current = dict(aggregate)
        recorded.pop("generated_at", None)
        current.pop("generated_at", None)
        if recorded != current:
            raise RuntimeError(
                "Aggregate audit no longer matches the accepted records."
            )
        verify_inventory(artifact_root, inventory_path, inventory_relative)
        status = "verified"

    print(
        json.dumps(
            {
                "status": status,
                "aggregate_sha256": sha256(aggregate_path),
                "report_sha256": sha256(report_path),
                "inventory_sha256": sha256(inventory_path),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
