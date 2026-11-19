function verify_postconditions(fun, xopt, fopt, exitflag, output)
%VERIFY_POSTCONDITIONS verifies whether output is in right form.
%

% Verify whether xopt is a real vector.
if ~isrealvector(xopt)
    error("xopt is not a real vector.");
end

% Verify whether fopt is a real number.
if ~isrealscalar(fopt)
    error("fopt is not a real number.");
end

% Verify whether fun(xopt) == fopt. Why we need to force xopt to be a column vector?
% For CUTest problem, function handle only accept column vector (if a row vector is input,
% the value is not correct). Remember that eval_fun needs to accept both function handle
% and point as input. eval_fun(xopt) is definitely wrong!
if eval_fun(fun, xopt) ~= fopt
    error("fun(xopt) is not equal to fopt.");
end

% Verify whether exitflag is an integer.
if ~isintegerscalar(exitflag)
    error("exitflag is not an integer.");
end

% Verify whether nf is a positive integer.
if ~isfield(output, "funcCount")
    error("output.funcCount does not exist.");
end
nf = output.funcCount;
if ~(isintegerscalar(nf) && nf > 0)
    error("output.funcCount is not a positive integer.");
end

% Verify whether output is a structure.
if ~isstruct(output)
    error("output is not a structure.");
end

% Verify whether output.fhist exists.
if ~isfield(output, "fhist")
    error("output.fhist does not exist.");
end
fhist = output.fhist;
% Verify whether fopt is the minimum of fhist.
if ~(isrealvector(fhist) && fopt == min(fhist))
    error("fopt is not the minimum of fhist.");
end

nhist = length(fhist);

if isfield(output, "xhist")
    xhist = output.xhist;
    % Verify whether xhist is a real matrix of the expected size.
    if ~(isrealmatrix(xhist) && all(size(xhist) == [length(xopt), nhist]))
        error("output.xhist is not a real matrix.");
    end

    % Check whether length(fhist) is equal to length(xhist) and nf respectively.
    if ~(length(fhist) == size(xhist, 2) && size(xhist, 2) == nf)
        error("length of fhist is not equal to length of xhist or nf.");
    end

    % Check whether fhist == fun(xhist).
    fhist_eval = nan(1, length(fhist));
    for i = 1:length(fhist)
        if isrow(xopt)
            fhist_eval(i) = eval_fun(fun, xhist(:, i)');
        else
            fhist_eval(i) = eval_fun(fun, xhist(:, i));
        end
    end
    % In case of fhist_eval(i) = nan or fhist(i) = nan.
    assert(all( (isnan(fhist) & isnan(fhist_eval)) | fhist == fhist_eval ));
end

end
