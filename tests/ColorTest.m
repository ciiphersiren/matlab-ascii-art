classdef ColorTest < matlab.unittest.TestCase
%COLORTEST Unit tests for img2asciiColor and ascii2html.
%
%   See also IMG2ASCIICOLOR, ASCII2HTML, IMG2ASCIITEST, EXPORTTEST.

    properties (TestParameter)
        % Image size, Width, and the expected number of rows
        ColorShape = struct( ...
            "landscapeRGB",  struct(ImageSize=[240 320 3], Width=80, Rows=30), ...
            "portraitRGB",   struct(ImageSize=[320 240 3], Width=60, Rows=40), ...
            "grayscale",     struct(ImageSize=[100 100],   Width=50, Rows=25), ...
            "singlePixel",   struct(ImageSize=[1 1 3],     Width=10, Rows=5))
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
        %% img2asciiColor
        function colorOutputMatchesTextSize(testCase, ColorShape)
            img = rand(ColorShape.ImageSize);
            [txt, colors] = img2asciiColor(img, Width=ColorShape.Width);

            testCase.verifySize(txt, [ColorShape.Rows ColorShape.Width]);
            testCase.verifySize(colors, [ColorShape.Rows ColorShape.Width 3]);
            testCase.verifyClass(colors, "double");
            testCase.verifyGreaterThanOrEqual(colors, 0);
            testCase.verifyLessThanOrEqual(colors, 1);
        end

        function textMatchesImg2ascii(testCase)
            img = rand(120, 160, 3);
            [txt, ~] = img2asciiColor(img, Width=40, Invert=true, Sharpen=1);
            testCase.verifyEqual(txt, img2ascii(img, Width=40, Invert=true, Sharpen=1));
        end

        function grayscaleGivesGrayColors(testCase)
            [~, colors] = img2asciiColor(rand(60, 80), Width=20);
            testCase.verifyEqual(colors(:,:,2), colors(:,:,1));
            testCase.verifyEqual(colors(:,:,3), colors(:,:,1));
        end

        function solidRedImageGivesRedColors(testCase)
            img = cat(3, 255 * ones(60, 80, "uint8"), zeros(60, 80, 2, "uint8"));
            [txt, colors] = img2asciiColor(img, Width=20);

            expected = repmat(reshape([1 0 0], 1, 1, 3), size(txt, 1), size(txt, 2));
            testCase.verifyEqual(colors, expected, AbsTol=1e-12);
        end

        %% ascii2html
        function solidRedImageGivesRedHtml(testCase)
            img = cat(3, ones(60, 80), zeros(60, 80, 2));
            % Charset without a space so every character is visible
            [txt, colors] = img2asciiColor(img, Width=20, Charset="#");
            filename = fullfile(testCase.Folder, "red.html");
            ascii2html(txt, colors, filename);

            html = fileread(filename);
            spans = string(regexp(html, '(?<=<span style="color:)#[0-9A-F]{6}', "match"));

            testCase.verifyNotEmpty(spans, "No colored spans found.");
            testCase.verifyEqual(unique(spans), "#FF0000");
            % One color per row, so consecutive characters share one span
            testCase.verifyNumElements(spans, size(txt, 1));
        end

        function htmlIsStandaloneWithBlackBackground(testCase)
            filename = fullfile(testCase.Folder, "art.html");
            ascii2html('ab', rand(1, 2, 3), filename);
            html = fileread(filename);

            testCase.verifySubstring(html, "<!DOCTYPE html>");
            testCase.verifySubstring(html, "background: #000000");
            testCase.verifySubstring(html, "monospace");
        end

        function htmlEscapesSpecialCharacters(testCase)
            filename = fullfile(testCase.Folder, "art.html");
            ascii2html('<&>', zeros(1, 3, 3), filename);
            html = fileread(filename);
            testCase.verifySubstring(html, "&lt;&amp;&gt;");
        end

        function htmlSizeMismatchErrors(testCase)
            filename = fullfile(testCase.Folder, "art.html");
            testCase.verifyError(@() ascii2html('abc', zeros(1, 2, 3), filename), ...
                "asciiart:input:sizeMismatch");
        end
    end
end
