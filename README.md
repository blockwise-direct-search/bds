# Blockwise Direct Search (BDS)

BDS is a package for solving nonlinear optimization problems without using derivatives. The current version can handle unconstrained problems.

## What is BDS?

BDS is a derivative-free package using blockwise direct-search methods. The current version is implemented in MATLAB, and it is being implemented in other programming languages.

See [Haitian LI's poster](https://lht97.github.io/documents/poster.pdf) on BDS for more information.

## Accelerated BDS

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

Run `help bds` for the complete option contracts, stopping criteria, and output
fields.

## How to install BDS?

1. Clone this repository. You should then get a folder named `bds` containing
   this README file and `setup.m`.
2. In MATLAB, change the current directory to that folder and run:

```matlab
setup
```

If setup succeeds, BDS is ready to use. Run `help bds` for more information.

MATLAB R2017a and earlier are not supported. If you encounter a problem, please
[open an issue](https://github.com/blockwise-direct-search/bds/issues).

## Testing

The core regression suites run through GitHub Actions:

- [Unit test](https://github.com/blockwise-direct-search/bds/actions/workflows/unit_test.yml)
- [Stress test](https://github.com/blockwise-direct-search/bds/actions/workflows/stress_test.yml)
- [Parallel test](https://github.com/blockwise-direct-search/bds/actions/workflows/parallel_test.yml)
- [Recursive test](https://github.com/blockwise-direct-search/bds/actions/workflows/recursive_test.yml)
- [Gradient test](https://github.com/blockwise-direct-search/bds/actions/workflows/gradient_test.yml)
- [Acceleration and stopping regressions](docs/BDS_ACCELERATION_OVERVIEW.md)

Large comparisons under [`research/`](research/README.md) reuse
`tests/profile_optiprofiler.m` with
[Optiprofiler](https://github.com/optiprofiler/optiprofiler). Their historical
workflow matrix is intentionally not part of the production CI surface.
