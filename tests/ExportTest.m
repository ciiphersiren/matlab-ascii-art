classdef ExportTest < matlab.unittest.TestCase
%EXPORTTEST Unit tests for ascii2txt and ascii2png.
%   Every test writes into a temporary folder that is deleted afterwards.
%
%   See also ASCII2TXT, ASCII2PNG, IMG2ASCIITEST, COLORTEST.

    properties (TestParameter)
        % Character matrices to round-trip through a text file
        TxtCase = struct( ...
            "plain",           ['ab cd'; ' x  y'], ...
            "trailingSpaces",  ['@@   '; '     '; '  .  '], ...
            "formatChars",     ['%d\n'; '"''%%'], ...
            "unicode",         char([0x2591 0x2592; 0x2593 0x2588]), ...
            "singleChar",      '#')

        PngOptions = struct( ...
            "defaults", {{}}, ...
            "darkTheme", {{"BackgroundColor", "black", "TextColor", "#33FF66", "FontSize", 8}}, ...
            "rgbColors", {{"BackgroundColor", [1 1 0.9], "TextColor", [0.2 0.2 0.5]}})
    end

    properties
        Folder   % temporary folder for the current test
    end

    methods (TestClassSetup)
        function addSrcToPath(testCase)
            srcDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "src");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcDir));
        end
    end

    methods (TestMethodSetup)
        function createTemporaryFolder(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Folder = fixture.Folder;
        end
    end

    methods (Test)
        %% ascii2txt
        function txtRoundTrip(testCase, TxtCase)
            filename = fullfile(testCase.Folder, "art.txt");
            ascii2txt(TxtCase, filename);
            testCase.verifyEqual(ExportTest.readTextFile(filename), TxtCase);
        end

        function txtRoundTripOfImageOutput(testCase)
            txt = img2ascii(rand(120, 160), Width=60);
            filename = fullfile(testCase.Folder, "art.txt");
            ascii2txt(txt, filename);
            testCase.verifyEqual(ExportTest.readTextFile(filename), txt);
        end

        function txtOverwritesExistingFile(testCase)
            filename = fullfile(testCase.Folder, "art.txt");
            ascii2txt(repmat('x', 5, 20), filename);
            ascii2txt('short', filename);
            testCase.verifyEqual(ExportTest.readTextFile(filename), 'short');
        end

        function txtUnwritableLocationErrors(testCase)
            filename = fullfile(testCase.Folder, "no_such_folder", "art.txt");
            testCase.verifyError(@() ascii2txt('abc', filename), "asciiart:io:cannotOpenFile");
        end

        %% ascii2png
        function pngIsCreatedAndValid(testCase, PngOptions)
            txt = img2ascii(rand(60, 80), Width=40);
            filename = fullfile(testCase.Folder, "art.png");
            nFigures = numel(findall(groot, "Type", "figure"));

            ascii2png(txt, filename, PngOptions{:});

            testCase.verifyTrue(isfile(filename), "PNG file was not created.");
            info = imfinfo(filename);
            testCase.verifyEqual(info.Format, 'png');
            img = imread(filename);
            testCase.verifyGreaterThan(size(img, [1 2]), [0 0]);
            testCase.verifyEqual(numel(findall(groot, "Type", "figure")), nFigures, ...
                "ascii2png should close its invisible figure.");
        end

        function pngCornerHasBackgroundColor(testCase)
            filename = fullfile(testCase.Folder, "art.png");
            ascii2png(['@@'; '@@'], filename, BackgroundColor="black", TextColor="white");
            img = imread(filename);
            testCase.verifyEqual(squeeze(img(1, 1, :)).', uint8([0 0 0]));
        end

        function pngInvalidColorErrors(testCase)
            filename = fullfile(testCase.Folder, "art.png");
            testCase.verifyError(@() ascii2png('abc', filename, TextColor="notacolor"), ?MException);
        end
    end

    methods (Static)
        function txt = readTextFile(filename)
            %READTEXTFILE Read a UTF-8 text file back into a char matrix.
            fid = fopen(filename, "r", "n", "UTF-8");
            closeFile = onCleanup(@() fclose(fid));
            contents = fread(fid, "*char").';
            lines = splitlines(string(contents));
            if lines(end) == ""
                lines(end) = [];   % text after the final newline
            end
            txt = char(lines);
        end
    end
end
