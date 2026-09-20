function seed = tsfsb_pds_seed(x0)
%TSFSB_PDS_SEED Deterministic per-problem seed for the randomized PDS solver.
%
%   New for TSFSB. The seed is an integer in [0, 2^32 - 1] derived from
%   x0 by FNV-1a 32-bit hashing over typecast(double(x0(:)), 'uint8'),
%   folded with numel(x0). Pure MATLAB, no toolboxes.
%
%   Usage: the seed is passed through the existing options.seed interface
%   of tests/competitors/pds.m, which builds RandStream('mt19937ar',
%   'Seed', options.seed). The same seed is used for every run of the
%   same problem because the OptiProfiler solver-handle interface cannot
%   pass per-run seeds to the handles; the runs of one feature still
%   differ through the feature realization (noise draws and the
%   orthogonal transformation, both seeded by OptiProfiler per run).
%
%   FNV-1a 32-bit: hash = 2166136261; for each byte b,
%   hash = mod(bitxor(hash, b) * 16777619, 2^32). The multiplication is
%   evaluated in double precision, which is exact below 2^53. The fold
%   with the dimension appends numel(x0) as a final mixing step.

x0 = double(x0(:));
if isempty(x0) || any(~isfinite(x0))
    error('tsfsb_pds_seed:InvalidInitialPoint', ...
        'x0 must be a nonempty finite real vector.');
end

bytes = typecast(x0, 'uint8');
modulus = 2^32;
hash = 2166136261;
for i = 1:numel(bytes)
    hash = mod(bitxor(uint32(hash), uint32(bytes(i))), modulus);
    hash = mod(double(hash) * 16777619, modulus);
end
hash = mod(hash + numel(x0), modulus);
seed = double(hash);

end
