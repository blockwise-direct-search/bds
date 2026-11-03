"""Check downloaded native plot bytes, metadata, counts, and PDF contents.

Run from this directory or pass the plots directory. This check is read-only;
rendered PDF inspection is recorded separately in PLOT_PLAN.md.
"""

import hashlib
import json
from pathlib import Path
import sys

from pypdf import PdfReader


root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent / "plots"
features = (
    "plain", "noisy_1e-4", "noisy_1e-2", "linearly_transformed",
    "linearly_transformed_noisy_1e-4", "linearly_transformed_noisy_1e-2",
)
summary = json.loads((root / "evidence/EXPERIMENT_SUMMARY.json").read_text())
assert summary["status"] == "completed"
pdf_count = page_count = source_count = 0
for seed_index, seed_base in ((1, 20260828), (2, 20261030)):
    seed_name = f"seed{seed_index}"
    totals = [0] * 6
    for feature in features:
        directory = root / seed_name / feature
        report = json.loads((directory / "VERIFIED.json").read_text())
        assert report["status"] == "verified"
        assert report["seed"] == seed_base and report["feature"] == feature
        assert report["n_problems"] == 133
        assert report["n_runs"] == (1 if feature == "plain" else 5)
        assert report["selected_labels"] == ["FG_old", "FG_new"]
        assert report["new_solver_calls"] == 0
        assert report["native_data_exact_match"] and report["source_files_unchanged"]
        assert report["native_curve_check_orders"] == [1, 2, 3, 4]
        assert report["pdf_postprocessing"] is False
        expected = next(item for item in summary[seed_name]["features"] if item["name"] == feature)
        assert report["all_variant_total_calls"] == expected["total_evaluations"]
        totals = [a + b for a, b in zip(totals, report["all_variant_total_calls"])]
        sources = json.loads((directory / "SOURCES.json").read_text())
        assert len(sources) == 133 * report["n_runs"]
        assert len({item["file"] for item in sources}) == len(sources)
        source_count += len(sources)
        pdfs = sorted(directory.glob("*.pdf"))
        assert len(pdfs) == 4
        for pdf in pdfs:
            # MATLAB makeValidName replaces both punctuation characters by '_'.
            key = pdf.name.replace("-", "_").replace(".", "_")
            digest = hashlib.sha256(pdf.read_bytes()).hexdigest()
            assert digest == report["pdf_sha256"][key], pdf
            reader = PdfReader(pdf)
            assert len(reader.pages) == (4 if "all_tolerances" in pdf.name else 1)
            for page in reader.pages:
                # PDF text extraction may omit layout spaces between words.
                text = "".join(page.extract_text().split())
                assert all(label in text for label in ("BDS-old", "BDS-new", "Performanceratio")), (pdf, text)
                assert float(page.mediabox.width) > 0 and float(page.mediabox.height) > 0
            pdf_count += 1
            page_count += len(reader.pages)
    assert totals == summary[seed_name]["total_evaluations"]

assert pdf_count == 48 and page_count == 120 and source_count == 6916
transfer_files = 0
for line in (root / "SHA256SUMS").read_text().splitlines():
    digest, relative = line.split("  ", 1)
    file = (root / relative).resolve()
    assert file.is_relative_to(root.resolve())
    assert hashlib.sha256(file.read_bytes()).hexdigest() == digest, file
    transfer_files += 1

print(json.dumps({
    "status": "verified", "pdf_files": pdf_count, "pdf_pages": page_count,
    "source_cases": source_count, "native_groups": 12,
    "transfer_files_sha256_verified": transfer_files,
    "totals_match_original_experiment": True,
    "all_pdf_pages_have_both_labels_and_axes": True,
}, indent=2))
