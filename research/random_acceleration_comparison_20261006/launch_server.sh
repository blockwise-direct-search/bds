#!/bin/sh
set -u
root=/home/lhtian97/Work/bds_small_comparison_20261006
cd "$root"
matlab -singleCompThread -batch "restoredefaultpath; addpath('$root/source/research/random_acceleration_comparison_20261006'); run_random_acceleration_comparison('$root/source','/home/lhtian97/local/optiprofiler_c02','$root/results');" > matlab.log 2>&1
status=$?
printf '%s\n' "$status" > exit_status.txt
exit "$status"
