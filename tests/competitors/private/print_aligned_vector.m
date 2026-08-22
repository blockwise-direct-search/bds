function print_aligned_vector(x)
% Print a vector with aligned columns and there
% will be at most n elements in each row.

% Check whether the input is a vector.
if ~isnumvec(x)
    error('Input X must be a numeric vector.');
end

% The maximum number of elements displayed in each row.
% Set to 3 for better readability.
n = 3;
% Ensure x is a column vector.
x = x(:);

% Display the vector by rows and there will be n elements
% in each row at most.
for i = 1:n:length(x)
    row = x(i:min(i+n-1, length(x)));
    % Print each element in scientific notation with fixed
    % width for column alignment, separated by 4 spaces.
    fprintf('%23.16E    ', row);
    fprintf('\n');
end
end
