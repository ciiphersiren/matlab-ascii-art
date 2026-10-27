%% BENCHMARK_BLOCKMEAN  Compare loop and vectorized block averaging.
%   Times BLOCKMEANLOOP and BLOCKMEANVECTORIZED with TIMEIT on square
%   images from 256x256 to 4096x4096, checks that both give the same
%   result, and plots time against image size on log-log axes.
%
%   Both functions live in src/private, which only code in src/ can call.
%   This script temporarily makes src/private the current folder so the
%   functions are in scope, and restores the original folder afterwards.
%
%   See also TIMEIT.

%% Settings
sizes = 256 * 2.^(0:4);   % 256, 512, 1024, 2048, 4096
nCols = 100;              % img2ascii default Width
nRows = 50;               % 100 * (square image) * 0.5 AspectCorrection
tol = 1e-9;

thisDir = fileparts(mfilename("fullpath"));
if isempty(thisDir)
    thisDir = pwd;   % running a selection rather than the whole script
end
privateDir = fullfile(thisDir, "..", "src", "private");

tLoop = zeros(size(sizes));
tVec = zeros(size(sizes));

oldDir = cd(privateDir);
try
    %% Correctness: compare against a reshape-based mean on an exact grid
    % 200x300 into 50x100 gives 4x3 blocks with no overlap, so the result
    % must match a plain mean over reshaped blocks.
    A = rand(200, 300);
    expected = squeeze(mean(reshape(A, 4, 50, 3, 100), [1 3]));
    assert(max(abs(blockMeanLoop(A, 50, 100) - expected), [], "all") < tol, ...
        "blockMeanLoop does not match the reshape reference.");
    assert(max(abs(blockMeanVectorized(A, 50, 100) - expected), [], "all") < tol, ...
        "blockMeanVectorized does not match the reshape reference.");

    %% Timing
    fprintf("%10s %12s %12s %10s\n", "Size", "Loop (s)", "Vector (s)", "Speedup");
    for k = 1:numel(sizes)
        n = sizes(k);
        A = rand(n);

        % Same answer on sizes that do not divide evenly into the grid
        err = max(abs(blockMeanLoop(A, nRows, nCols) - ...
            blockMeanVectorized(A, nRows, nCols)), [], "all");
        assert(err < tol, "Results differ at %dx%d (max error %g).", n, n, err);

        tLoop(k) = timeit(@() blockMeanLoop(A, nRows, nCols));
        tVec(k) = timeit(@() blockMeanVectorized(A, nRows, nCols));

        fprintf("%10s %12.4g %12.4g %9.1fx\n", n + "x" + n, ...
            tLoop(k), tVec(k), tLoop(k) / tVec(k));
    end
catch err
    cd(oldDir);
    rethrow(err);
end
cd(oldDir);

%% Plot
pixels = sizes.^2;

fig = figure(Name="Block mean benchmark", Color="w");
ax = axes(fig);
loglog(ax, pixels, tLoop, "-o", LineWidth=1.5, DisplayName="Nested for-loops");
hold(ax, "on");
loglog(ax, pixels, tVec, "-s", LineWidth=1.5, DisplayName="Vectorized (separable cumsum)");
hold(ax, "off");

grid(ax, "on");
xticks(ax, pixels);
xticklabels(ax, sizes + "^2");
xlabel(ax, "Image size (pixels)");
ylabel(ax, "Time (s)");
title(ax, sprintf("Block averaging into a %dx%d grid", nRows, nCols));
subtitle(ax, sprintf("Speedup of vectorized over loops: %.1fx to %.1fx", ...
    min(tLoop ./ tVec), max(tLoop ./ tVec)));
legend(ax, Location="northwest");