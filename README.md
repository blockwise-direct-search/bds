# Blockwise Direct Search (BDS)

BDS is a MATLAB solver for unconstrained nonlinear optimization without derivatives.
For an introduction to the method, see [Haitian Li's slides on blockwise direct search](https://lht97.github.io/documents/2026_PhD_Symposium_Optimization_Algorithms_Software_Applications_Talk.pdf).

## Getting started

BDS requires MATLAB R2017b or later. To download the solver and examples, run

```bash
git clone --depth 1 --filter=blob:none --sparse --single-branch \
  --branch main https://github.com/blockwise-direct-search/bds.git
cd bds
git sparse-checkout set src examples
```

In MATLAB, open the cloned `bds` directory and run the following example.
The objective attains its minimum at `[1; 1]`.

```matlab
setup
fun = @(x) (x(1) - 1)^2 + 2 * (x(2) - 1)^2;
x0 = [3; -2];
[xopt, fopt] = bds(fun, x0)
```

## Solver options

BDS uses search acceleration by default. The pattern direction follows the displacement
over the shortest sequence of block visits ending at the current poll that covers every block.
Each block maintains its own momentum by accumulating pattern directions over successive
visits to that block. Set `options.use_search_acceleration = false` to turn acceleration off.
See the [acceleration overview](https://github.com/blockwise-direct-search/bds/blob/main/docs/BDS_ACCELERATION_OVERVIEW.md) for details.

- **Termination.** BDS can stop when the best function value changes little or when the estimated gradient is small. Both criteria are off by default and can be enabled independently.
- **Initial step sizes.** Set `options.alpha_init = 'auto'` to choose step sizes from `x0` when each block contains one pair of standard coordinate directions.
- **Block visits.** Set `options.Algorithm` to `'cyclic'`, `'permuted'`, or `'random'` to choose the visit order, or to `'ds'` to use a single block.
- **Failed evaluations.** If the objective throws an error or returns `NaN`, BDS treats the value as `Inf` and counts the evaluation. Set `options.output_xhist = true` to record these points in `output.invalid_points`.

Pass options as the third argument to `bds(fun, x0, options)`. Run `help bds` for all options and outputs.

## Tests and benchmarks

[![BDS regression](https://github.com/bladesopt/bds/actions/workflows/bds_regression_test.yml/badge.svg?branch=main)](https://github.com/bladesopt/bds/actions/workflows/bds_regression_test.yml)

- [Run the tests](https://github.com/blockwise-direct-search/bds/blob/main/tests/README.md)
- [Explore the benchmarks](https://github.com/blockwise-direct-search/bds/tree/main/research)
- [View GitHub Actions results](https://github.com/bladesopt/bds/actions)
