%% RUNALLTESTS  Run the test suite with a results table and code coverage.
%   Runs every test class in the tests folder, prints a table of results,
%   and writes an HTML code coverage report for src/ (including
%   src/private) to the coverage folder. Coverage is skipped with a warning
%   if this MATLAB release does not support it. The script errors at the
%   end if any test failed, so it can also be used in CI.
%
%   See also RUNTESTS, MATLAB.UNITTEST.TESTRUNNER.

import matlab.unittest.TestRunner
import matlab.unittest.TestSuite
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageReport

testsDir = fileparts(mfilename("fullpath"));
if isempty(testsDir)
    testsDir = pwd;   % running a selection rather than the whole script
end
rootDir = fileparts(testsDir);
srcDir = fullfile(rootDir, "src");
reportDir = fullfile(rootDir, "coverage");

% Collect *Test.m files only. TestSuite.fromFolder would also treat this
% script as a script-based test and run it recursively.
files = dir(fullfile(testsDir, "*Test.m"));
suites = arrayfun(@(f) TestSuite.fromFile(fullfile(f.folder, f.name)), files, ...
    UniformOutput=false);
suite = [suites{:}];
runner = TestRunner.withTextOutput;

hasCoverage = true;
try
    runner.addPlugin(CodeCoveragePlugin.forFolder(srcDir, ...
        IncludingSubfolders=true, Producing=CoverageReport(reportDir)));
catch err
    hasCoverage = false;
    warning("asciiart:tests:noCoverage", "Code coverage disabled: %s", err.message);
end

results = runner.run(suite);

%% Results
disp(table(results))
fprintf("%d passed, %d failed, %d incomplete (%.2f s total)\n", ...
    nnz([results.Passed]), nnz([results.Failed]), nnz([results.Incomplete]), ...
    sum([results.Duration]));

if hasCoverage
    fprintf("Coverage report: %s\n", fullfile(reportDir, "index.html"));
end

assertSuccess(results);
