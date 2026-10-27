%% RUNALLTESTS  Run the test suite with a results table and code coverage.
%   Runs every test class in the tests folder, prints a table of results,
%   and writes an HTML code coverage report for src/ (including
%   src/private) to the coverage folder. Coverage is skipped with a warning
%   if this MATLAB release does not support it. The script errors at the
%   end if any test failed or if line coverage is below minCoverage, so it
%   can also be used in CI.
%
%   See also RUNTESTS, MATLAB.UNITTEST.TESTRUNNER.

import matlab.unittest.TestRunner
import matlab.unittest.TestSuite
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageReport
import matlab.unittest.plugins.codecoverage.CoberturaFormat

% The script errors if line coverage of src/ falls below this percentage.
% Set it a few points below the current value so small changes still pass.
minCoverage = 95;

testsDir = fileparts(mfilename("fullpath"));
if isempty(testsDir)
    testsDir = pwd;   % running a selection rather than the whole script
end
rootDir = fileparts(testsDir);
srcDir = fullfile(rootDir, "src");
reportDir = fullfile(rootDir, "coverage");
coberturaFile = fullfile(reportDir, "coverage.xml");

% CoberturaFormat needs its folder to exist already. coverage/ is not in
% the repo, so it is missing in a fresh checkout.
if ~isfolder(reportDir)
    mkdir(reportDir);
end

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
        IncludingSubfolders=true, ...
        Producing=[CoverageReport(reportDir), CoberturaFormat(coberturaFile)]));
catch err
    % In CI, fail instead of silently skipping the coverage check
    if getenv("CI") == "true"
        rethrow(err);
    end
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
    % Overall line rate (0 to 1) is an attribute of the root element
    xml = xmlread(coberturaFile);
    coverage = 100 * str2double(char(xml.getDocumentElement.getAttribute("line-rate")));
    fprintf("Line coverage of src/: %.1f%% (minimum %d%%)\n", coverage, minCoverage);
    fprintf("Coverage report: %s\n", fullfile(reportDir, "index.html"));

    % On GitHub Actions, also show the number on the workflow run page
    summaryFile = getenv("GITHUB_STEP_SUMMARY");
    if ~isempty(summaryFile)
        fid = fopen(summaryFile, "a");
        fprintf(fid, "### Line coverage of src/: %.1f%% (minimum %d%%)\n", ...
            coverage, minCoverage);
        fclose(fid);
    end
end

assertSuccess(results);

if hasCoverage && coverage < minCoverage
    error("asciiart:tests:lowCoverage", ...
        "Line coverage %.1f%% is below the minimum of %d%%.", coverage, minCoverage);
end
