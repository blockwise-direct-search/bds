function summary=verify_bds_rolling_saved_traces(c15_root,c13_root,result_directory,mode)
%VERIFY_BDS_ROLLING_SAVED_TRACES Replay recorded objective values, not new runs.
% For each of six features and four stopping modes, select twelve evenly
% spaced files from the sorted saved trace list (288 total). Every requested
% point must exactly match the recorded point before its value is returned.
% This covers the actual noisy/transformed experiments without re-generating
% noise or claiming a new performance comparison.
% MODE='full-plain' replays every one of the 133 problems in all four modes.
if nargin<4,mode='sample';end
assert(ismember(mode,{'sample','full-plain'}));
root=fileparts(fileparts(mfilename('fullpath')));
oldpath=path();cleanup=onCleanup(@()path(oldpath));
addpath(fullfile(root,'src'));
files={};
features={'plain','noisy_1e-4','noisy_1e-2', ...
    'rotated','rotated_noisy_1e-4','rotated_noisy_1e-2'};
if strcmp(mode,'full-plain'),features={'plain'};end
for feature=features
    for stop_mode={'off','f','g','fg'}
        if strcmp(stop_mode{1},'off')
            folder=fullfile(c13_root,'evaluations','G',feature{1},'traces','G_p0a1');
        else
            folder=fullfile(c15_root,'evaluations','G',feature{1},'traces',['p0a1_' stop_mode{1}]);
        end
        listing=dir(fullfile(folder,'*.mat'));
        [~,order]=sort({listing.name});listing=listing(order);
        assert(numel(listing)>=12);
        chosen=unique(round(linspace(1,numel(listing),12)));
        if strcmp(mode,'full-plain')
            assert(numel(listing)==133);
            chosen=1:numel(listing);
        end
        for j=chosen
            files{end+1}=fullfile(folder,listing(j).name); %#ok<AGROW>
        end
    end
end
if strcmp(mode,'full-plain'),expected_count=532;else,expected_count=288;end
assert(numel(files)==expected_count,'BDS:ReplayCoverage','Unexpected replay coverage.');
counts=zeros(size(files));
parfor j=1:numel(files)
    counts(j)=replay(files{j});
    fprintf('ROLLING_REPLAY_PASS %d/%d\n',j,numel(files));
end
summary=struct('passed',numel(files),'failed',0,'calls',sum(counts), ...
    'files',{files},'calls_per_trace',counts);
summary.mode=mode;
if strcmp(mode,'full-plain'),name='full_plain_replay_summary.mat';else
    name='saved_replay_summary.mat';
end
save(fullfile(result_directory,name),'summary');
fprintf('ROLLING_REPLAY_OK cases=%d calls=%d\n',summary.passed,summary.calls);
end

function calls=replay(file)
data=load(file,'trace');t=data.trace;
assert(strcmp(t.status,'returned'));
calls=0;bad_point=false;rng(t.algorithm_seed,'twister');
[x,f,flag,output]=bds(@recorded_value,t.x0,t.options);
expected=t.solver_output;
if isfield(expected,'c12_stats'),expected=rmfield(expected,'c12_stats');end
assert(~bad_point && calls==t.calls && isequaln(x,t.output) && isequaln(f,t.fopt) ...
    && flag==t.exitflag && isequaln(output,expected), ...
    'BDS:SavedReplayOutput','Output mismatch: %s',file);
    function f=recorded_value(point)
        calls=calls+1;
        % eval_fun catches errors, so also validate calls and outputs afterward.
        if calls>t.calls || ~isequaln(point(:),t.points(:,calls))
            bad_point=true;
            error('BDS:SavedReplayPoint','Point mismatch: %s call %d',file,calls);
        end
        f=t.values(calls);
    end
end
