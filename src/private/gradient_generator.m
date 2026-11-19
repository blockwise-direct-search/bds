function estimated_gradient = gradient_generator(n, num_blocks, batch_size, direction_indices_per_block, alpha_all, random_cubic_function_with_gradient, x, grad_info)

batch_indices = sort(randperm(num_blocks, batch_size));
grad_info.step_size_per_batch = alpha_all(batch_indices);

% Sample batch_size blocks without replacement.
grad_info.sampled_direction_indices_per_batch = direction_indices_per_block(batch_indices);

% Use different way from bds.m to compute function values and divide those function values into corresponding batches.
grad_info.function_values_per_batch = cellfun(@(batch_idx, b) arrayfun(@(d) ...
    random_cubic_function_with_gradient(x + grad_info.step_size_per_batch(b) * grad_info.complete_direction_set(:, batch_idx(d))), ...
    1:length(batch_idx)), ...
    grad_info.sampled_direction_indices_per_batch, num2cell(1:length(grad_info.sampled_direction_indices_per_batch)), ...
    'UniformOutput', false);

grad_info.n = n;
estimated_gradient = estimate_gradient(grad_info);

end
