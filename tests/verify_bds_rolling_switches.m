function verify_bds_rolling_switches()
%VERIFY_BDS_ROLLING_SWITCHES End-to-end checks of independent rolling switches.
% With zero momentum decay and axial updates, pattern-only, momentum-only and
% MP must generate the same complete trace. The axial fixture avoids spurious
% roundoff differences from repeated normalization of general directions.
root=fileparts(fileparts(mfilename('fullpath')));
oldpath=path();cleanup=onCleanup(@()path(oldpath));
addpath(fullfile(root,'src'));
count=0;
for n=[1,3,7]
    for stops=0:3
        x0=zeros(n,1);
        o=bds_paper_options(x0,'external','mp');
        o.alpha_init=1;o.momentum_decay=0;o.StepTolerance=0;
        o.MaxFunctionEvaluations=160*n;o.func_window_size=3;
        o.use_function_value_stop=logical(bitget(stops,1));
        o.use_estimated_gradient_stop=logical(bitget(stops,2));
        o.output_xhist=true;o.output_alpha_hist=true;
        o.output_block_hist=true;o.output_grad_hist=true;
        rng(42);random_state=rng();
        expected=[];
        for switches=1:3
            o.use_iteration_pattern_step=logical(bitget(switches,1));
            o.use_momentum_extrapolation=logical(bitget(switches,2));
            actual=record_bds_execution(@bds,@(x)(x(1)-14.25)^2,x0,o,random_state);
            if isempty(expected),expected=actual;else
                assert(isequaln(actual,expected),'BDS:RollingSwitchMismatch', ...
                    'Axial trace differs: n=%d stops=%d switches=%d.',n,stops,switches);
            end
            count=count+1;
        end
    end
end
fprintf('BDS_ROLLING_SWITCHES_OK cases=%d\n',count);
end
