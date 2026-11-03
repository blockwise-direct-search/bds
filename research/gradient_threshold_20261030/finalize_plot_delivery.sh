#!/usr/bin/env bash
# Postprocess completed native plots only. Never start solver evaluations.
set -euo pipefail
plot_root=/home/lhtian97/Work/bds_gradient_threshold_plots_20261102
experiment_root=/home/lhtian97/Work/bds_gradient_threshold_20261030
delivery="$plot_root/delivery"
test "$(find "$delivery" -name VERIFIED.json | wc -l)" -eq 12
python3 "$plot_root/control/summarize_native_curves.py" "$delivery" > "$delivery/NATIVE_CURVE_SUMMARY.json"
mkdir -p "$delivery/evidence"
python3 "$experiment_root/control/prepare.py" "$experiment_root" audit > "$delivery/evidence/source_audit_after.json"
cp "$plot_root/logs/source_audit_before.json" "$delivery/evidence/source_audit_before.json"
cp "$experiment_root/SUMMARY.json" "$delivery/evidence/EXPERIMENT_SUMMARY.json"
cp "$experiment_root/run.status" "$delivery/evidence/run.status"
for marker in "$delivery"/seed*/*/VERIFIED.json; do
    directory=${marker%/*}
    for order in 2 4; do
        pdftoppm -f 1 -singlefile -scale-to 1200 -png \
            "$directory/history_tau_1e-$order.pdf" "$directory/history_tau_1e-$order"
    done
    pdftoppm -f 4 -singlefile -scale-to 1200 -png \
        "$directory/output_all_tolerances.pdf" "$directory/output_tau_1e-4"
done
cd "$delivery"
find seed1 seed2 evidence -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
sha256sum NATIVE_CURVE_SUMMARY.json >> SHA256SUMS
printf 'PLOT_DELIVERY_READY native_groups=12 pdfs=48 solver_calls=0\n'
