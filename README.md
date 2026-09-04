# Blockwise Direct Search (BDS)

BDS is a package for solving nonlinear optimization problems without using derivatives. The current version can handle unconstrained problems.

## What is BDS?

BDS is a derivative-free package using blockwise direct-search methods. The current version is implemented in MATLAB, and it is being implemented in other programming languages.

See [Haitian LI's poster](https://lht97.github.io/documents/poster.pdf) on BDS for more information.

## How to install BDS?

1. Clone a lightweight solver-only working tree:

```bash
git clone --depth 1 --filter=blob:none --sparse --single-branch \
  --branch main https://github.com/blockwise-direct-search/bds.git
cd bds
git sparse-checkout set src examples
```

This checks out the files needed to use BDS, including `README.md`, `LICENSE`,
`setup.m`, `src/`, and `examples/`, without checking out the research,
documentation, test, or workflow directories.

2. In MATLAB, change the current directory to the cloned `bds` folder and run:

```matlab
setup
```

If setup succeeds, BDS is ready to use. Run `help bds` for the complete solver
interface and option contracts.

MATLAB R2017a and earlier are not supported. If you encounter a problem, please
[open an issue](https://github.com/blockwise-direct-search/bds/issues).

## Production BDS capabilities

The public `bds` solver combines four capabilities in one implementation:
acceleration, optional termination criteria, automatic initial-step selection,
and robust handling of invalid function evaluations.

### Acceleration

The public `bds` solver includes three acceleration mechanisms, all enabled by
default:

- **Productive-direction memory** tries a small ordered collection of previously
  successful directions before regular block polling.
- **Iteration-pattern search** extrapolates along the net successful displacement
  of the current iteration after regular polling.
- **Momentum extrapolation** combines successful iteration displacements across
  iterations and searches along the resulting momentum direction.

The two post-poll mechanisms use the same candidate step factors `1`, `2`, and
`4`; pattern candidates are considered before momentum candidates. The default
function-evaluation budget is `500*length(x0)`, and the default noiseless
expansion factor is `2.0`.

The default accelerated solver can be called directly:

```matlab
[xopt, fopt] = bds(fun, x0);
```

Each mechanism can be controlled independently. To recover the non-accelerated
polling behavior under otherwise identical explicit options, disable all three:

```matlab
options.use_productive_direction_memory = false;
options.use_iteration_pattern_step = false;
options.use_momentum_extrapolation = false;
[xopt, fopt] = bds(fun, x0, options);
```

### Optional termination criteria

BDS provides two optional stopping mechanisms in addition to the evaluation
budget, target value, and step-size conditions:

- function-value stopping detects when the best value changes little over a
  configurable window;
- estimated-gradient stopping uses a reference-scaled gradient estimate with an
  optional consistency check.

```matlab
options.use_function_value_stop = true;
options.use_estimated_gradient_stop = true;
[xopt, fopt, exitflag, output] = bds(fun, x0, options);
```

Both mechanisms are disabled by default and can be enabled independently.

### Automatic initial step size

The polling step can be initialized automatically from the scale of the initial
point while respecting the step tolerance:

```matlab
options.alpha_init = 'auto';
[xopt, fopt] = bds(fun, x0, options);
```

An explicit scalar or vector `alpha_init` remains available when the polling
scale is known in advance.

### Invalid function evaluations

BDS evaluates the objective through
[`eval_fun.m`](src/private/eval_fun.m). Its core invalid-evaluation handling is:

```matlab
is_valid = true;

try
    f_real = fun(x);
catch
    warning('The function evaluation failed.');
    f_real = nan;
    is_valid = false;
end

f = f_real;
if isnan(f_real)
    f = inf;
    is_valid = false;
end
```

Thus, an evaluation that throws an error is recorded as `NaN`, and either an
error or a returned `NaN` gives the algorithm the value `Inf` and marks the
point as invalid. This prevents the point from being accepted as an improvement
while preserving the raw failed value for diagnosis. The evaluation still
counts toward the function-evaluation budget, and the point is reported through
the solver output.

```matlab
[xopt, fopt, exitflag, output] = bds(fun, x0);
invalid_points = output.invalid_points;
```

Run `help bds` for all stopping parameters, histories, exit flags, and output
fields.

## Tests and reproducible benchmarks

- [Tests](https://github.com/bladesopt/bds/actions) at
  [bladesopt/bds](https://github.com/bladesopt/bds)

### Correctness and maintenance

Production BDS regression, unit tests, gradient estimation, NORMA verification,
MATLAB spelling, and TeX/Bib spelling run on every push. The remaining
correctness workflows run on separate days of the monthly schedule. Scheduled
workflows can also be started manually when an additional run is needed.

| Workflow | Status |
| --- | --- |
| Production BDS regression | [![BDS regression](https://github.com/bladesopt/bds/actions/workflows/bds_regression_test.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/bds_regression_test.yml) |
| Unit tests | [![Unit tests](https://github.com/bladesopt/bds/actions/workflows/unit_test.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/unit_test.yml) |
| Stress tests | [![Stress tests](https://github.com/bladesopt/bds/actions/workflows/stress_test.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/stress_test.yml) |
| Parallel behavior | [![Parallel tests](https://github.com/bladesopt/bds/actions/workflows/parallel_test.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/parallel_test.yml) |
| Recursive calls | [![Recursive tests](https://github.com/bladesopt/bds/actions/workflows/recursive_test.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/recursive_test.yml) |
| Gradient estimation | [![Gradient tests](https://github.com/bladesopt/bds/actions/workflows/gradient_test.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/gradient_test.yml) |
| Simplified BDS verification | [![Simplified BDS](https://github.com/bladesopt/bds/actions/workflows/verify_simplified_bds.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/verify_simplified_bds.yml) |
| NORMA verification | [![NORMA](https://github.com/bladesopt/bds/actions/workflows/verify_norma.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/verify_norma.yml) |
| MATLAB spelling | [![MATLAB spelling](https://github.com/bladesopt/bds/actions/workflows/spelling.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/spelling.yml) |
| TeX/Bib spelling | [![TeX/Bib spelling](https://github.com/bladesopt/bds/actions/workflows/spell_check.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/spell_check.yml) |

### Solver comparisons on S2MPJ

Each workflow compares production BDS with one solver from the
[S2MPJ problem collection](https://github.com/GrattonToint/S2MPJ). Small
problems have dimensions 1--5 and big problems have dimensions 6--50.
Feature-level results are uploaded separately and automatically combined into
merged artifacts.

| Comparison | Size | Status |
| --- | --- | --- |
| BDS vs BFO | small | [![BDS vs BFO small](https://github.com/bladesopt/bds/actions/workflows/profile_bds_bfo_small_s2mpj.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/profile_bds_bfo_small_s2mpj.yml) |
| BDS vs BFO | big | [![BDS vs BFO big](https://github.com/bladesopt/bds/actions/workflows/profile_bds_bfo_big_s2mpj.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/profile_bds_bfo_big_s2mpj.yml) |
| BDS vs NOMAD | small | [![BDS vs NOMAD small](https://github.com/bladesopt/bds/actions/workflows/profile_bds_nomad_small_s2mpj.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/profile_bds_nomad_small_s2mpj.yml) |
| BDS vs NOMAD | big | [![BDS vs NOMAD big](https://github.com/bladesopt/bds/actions/workflows/profile_bds_nomad_big_s2mpj.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/profile_bds_nomad_big_s2mpj.yml) |
| BDS vs NEWUOA | small | [![BDS vs NEWUOA small](https://github.com/bladesopt/bds/actions/workflows/profile_bds_newuoa_small_s2mpj.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/profile_bds_newuoa_small_s2mpj.yml) |
| BDS vs NEWUOA | big | [![BDS vs NEWUOA big](https://github.com/bladesopt/bds/actions/workflows/profile_bds_newuoa_big_s2mpj.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/profile_bds_newuoa_big_s2mpj.yml) |
| BDS vs BFGS without supplied gradients | small | [![BDS vs BFGS small](https://github.com/bladesopt/bds/actions/workflows/profile_bds_bfgs_no_gradient_small_s2mpj.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/profile_bds_bfgs_no_gradient_small_s2mpj.yml) |
| BDS vs BFGS without supplied gradients | big | [![BDS vs BFGS big](https://github.com/bladesopt/bds/actions/workflows/profile_bds_bfgs_no_gradient_big_s2mpj.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/profile_bds_bfgs_no_gradient_big_s2mpj.yml) |

### BDS capability benchmarks on S2MPJ

| Experiment | Size | Status |
| --- | --- | --- |
| Acceleration off vs on | small | [![BDS acceleration small](https://github.com/bladesopt/bds/actions/workflows/benchmark_bds_acceleration_small.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/benchmark_bds_acceleration_small.yml) |
| Acceleration off vs on | big | [![BDS acceleration big](https://github.com/bladesopt/bds/actions/workflows/benchmark_bds_acceleration_big.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/benchmark_bds_acceleration_big.yml) |
| Function/gradient stopping | big | [![BDS termination big](https://github.com/bladesopt/bds/actions/workflows/benchmark_bds_termination_big.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/benchmark_bds_termination_big.yml) |
| Invalid function evaluations | big | [![Invalid evaluations](https://github.com/bladesopt/bds/actions/workflows/invalid_function_evaluation_test.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/invalid_function_evaluation_test.yml) |

The experiment workflows reuse
`tests/profile_optiprofiler.m` with
[OptiProfiler](https://github.com/optiprofiler/optiprofiler). Their complete
feature matrices are substantially more expensive than the core correctness
checks, so the workflows run on separate days of a monthly schedule. They
remain manually triggerable for additional or replacement runs.
