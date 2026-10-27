classdef Img2AsciiTest < matlab.unittest.TestCase
%IMG2ASCIITEST Unit tests for img2ascii and its block-averaging helpers.
%   Run this class directly with
%
%       results = runtests("tests/Img2AsciiTest.m");
%
%   or run tests/runAllTests.m for a results table and coverage report.
%
%   See also IMG2ASCII, RUNTESTS.

    properties (Constant)
        Charset = ' .:-=+*#%@'   % img2ascii default as char, lightest to darkest

        % Unicode block shades, lightest to darkest. Built from code points
        % so the test does not depend on the file's text encoding.
        Shades = char([0x2591 0x2592 0x2593 0x2588])   % ░▒▓█
    end

    properties (TestParameter)
        % Image size, Width, AspectCorrection, and the row count worked out
        % by hand from round(Width * H/W * AspectCorrection)
        OutputShape = struct( ...
            "square",       struct(ImageSize=[100 100], Width=50, Aspect=0.5, Rows=25), ...
            "landscape",    struct(ImageSize=[240 320], Width=80, Aspect=0.5, Rows=30), ...
            "portrait",     struct(ImageSize=[320 240], Width=60, Aspect=0.5, Rows=40), ...
            "noCorrection", struct(ImageSize=[240 320], Width=80, Aspect=1,   Rows=60), ...
            "roundsUp",     struct(ImageSize=[100 300], Width=10, Aspect=0.5, Rows=2))

        UniformCase = struct( ...
            "blackDefault",  struct(Value=0, Invert=false, Expected='@'), ...
            "whiteDefault",  struct(Value=1, Invert=false, Expected=' '), ...
            "blackInverted", struct(Value=0, Invert=true,  Expected=' '), ...
            "whiteInverted", struct(Value=1, Invert=true,  Expected='@'))

        Contrast = {"none", "stretch", "equalize"}

        SharpenAmount = {0.5, 1, 2}

        ImageType = {"doubleGray", "singleGray", "uint8RGB", "doubleRGB", "pngFile"}

        InvalidImage = struct( ...
            "cellArray",    {{1, 2}}, ...
            "structure",    struct("x", 1), ...
            "emptyArray",   [], ...
            "complexArray", 1i * ones(4), ...
            "stringArray",  ["a.png" "b.png"], ...
            "twoChannels",  rand(4, 4, 2), ...
            "fourDims",     rand(4, 4, 3, 2))

        InvalidOption = struct( ...
            "negativeWidth",    {{"Width", -5}}, ...
            "zeroWidth",        {{"Width", 0}}, ...
            "fractionalWidth",  {{"Width", 2.5}}, ...
            "emptyCharset",     {{"Charset", ""}}, ...
            "zeroAspect",       {{"AspectCorrection", 0}}, ...
            "unknownContrast",  {{"Contrast", "bogus"}}, ...
            "negativeSharpen",  {{"Sharpen", -1}})

        % [imageRows imageCols gridRows gridCols]
        BlockShape = struct( ...
            "exactFit",    [40 60 10 20], ...
            "uneven",      [101 257 13 50], ...
            "upsample",    [5 7 12 20], ...
            "singleRow",   [1 300 1 40], ...
            "singleBlock", [33 17 1 1], ...
            "large",       [512 768 50 100])
    end

    methods (TestClassSetup)
        function addSrcToPath(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(Img2AsciiTest.rootFolder(), "src")));
        end
    end

    methods (Test)
        %% Output size
        function outputHasWidthColumnsAndScaledRows(testCase, OutputShape)
            img = rand(OutputShape.ImageSize);
            txt = img2ascii(img, Width=OutputShape.Width, ...
                AspectCorrection=OutputShape.Aspect);
            testCase.verifyClass(txt, "char");
            testCase.verifySize(txt, [OutputShape.Rows OutputShape.Width]);
        end

        %% Uniform images
        function uniformImageMapsToSingleExtremeChar(testCase, UniformCase)
            img = UniformCase.Value * ones(60, 80);
            txt = img2ascii(img, Width=40, Invert=UniformCase.Invert);
            testCase.verifyEqual(unique(txt), UniformCase.Expected);
        end

        %% Monotonicity
        function gradientDarkensLeftToRight(testCase, Contrast)
            img = repmat(linspace(1, 0, 500), 50, 1);   % white to black
            txt = img2ascii(img, Contrast=Contrast);
            [~, darkness] = ismember(txt, testCase.Charset);

            testCase.verifyGreaterThanOrEqual(diff(darkness, 1, 2), 0, ...
                "Character darkness must not decrease from left to right.");
            testCase.verifyEqual(darkness(:, 1), ones(size(txt, 1), 1), ...
                "Leftmost (white) column should use the lightest character.");
            testCase.verifyEqual(darkness(:, end), numel(testCase.Charset) * ones(size(txt, 1), 1), ...
                "Rightmost (black) column should use the darkest character.");
        end

        %% Input types
        function inputTypesGiveIdenticalOutput(testCase, ImageType)
            [ref, expected] = Img2AsciiTest.levelImage();
            img = testCase.convertImage(ref, ImageType);

            % Contrast="none" keeps each block in the middle of its
            % brightness bin, so the expected characters are exact
            txt = img2ascii(img, Width=8, AspectCorrection=1, Contrast="none");
            testCase.verifyEqual(txt, expected);
            testCase.verifyEqual(txt, img2ascii(ref, Width=8, AspectCorrection=1, Contrast="none"));
        end

        %% Edge cases
        function singlePixelImage(testCase)
            txt = img2ascii(0.5);
            testCase.verifySize(txt, [50 100]);
            testCase.verifyNumElements(unique(txt), 1);
        end

        function veryWideImageGivesOneRow(testCase)
            txt = img2ascii(rand(10, 5000));
            testCase.verifySize(txt, [1 100]);
        end

        function veryTallImage(testCase)
            txt = img2ascii(rand(5000, 10), Width=20);
            testCase.verifySize(txt, [5000 20]);
        end

        function widthLargerThanImage(testCase)
            txt = img2ascii(rand(20, 30), Width=200);
            testCase.verifySize(txt, [67 200]);
            testCase.verifyTrue(all(ismember(txt, testCase.Charset), "all"));
        end

        function singleCharacterCharset(testCase)
            txt = img2ascii(rand(40, 60), Width=30, Charset="#");
            testCase.verifySize(txt, [10 30]);
            testCase.verifyEqual(unique(txt), '#');
        end

        %% Sharpen
        function sharpenLeavesUniformImageUnchanged(testCase, SharpenAmount)
            img = 0.37 * ones(60, 80);   % mid-bin gray, away from character boundaries
            expected = img2ascii(img, Width=40);
            actual = img2ascii(img, Width=40, Sharpen=SharpenAmount);
            testCase.verifyEqual(actual, expected);
        end

        function sharpenIncreasesEdgeContrast(testCase, SharpenAmount)
            % Dark | bright vertical edge on a block boundary: 200 pixels
            % into 100 columns puts the edge between columns 50 and 51.
            % Contrast="none" so the global stretch does not hide the effect.
            img = [0.25 * ones(40, 100), 0.75 * ones(40, 100)];
            plain = img2ascii(img, Width=100, Contrast="none");
            sharp = img2ascii(img, Width=100, Contrast="none", Sharpen=SharpenAmount);

            testCase.verifyGreaterThanOrEqual( ...
                Img2AsciiTest.edgeContrast(sharp, testCase.Charset), ...
                Img2AsciiTest.edgeContrast(plain, testCase.Charset), ...
                "Sharpening should not reduce character contrast across the edge.");
        end

        %% Unicode charset
        function unicodeCharsetUsesOnlyThoseChars(testCase)
            txt = img2ascii(rand(60, 80), Width=40, Charset=string(testCase.Shades));
            testCase.verifyClass(txt, "char");
            testCase.verifySize(txt, [15 40]);
            testCase.verifyTrue(all(ismember(txt, testCase.Shades), "all"), ...
                "Output contains characters outside the Unicode charset.");
        end

        function unicodeCharsetMapsUniformToExtremes(testCase, UniformCase)
            % UniformCase gives the expected default-charset extreme; map
            % ' ' (lightest) and '@' (darkest) to the matching shade.
            if UniformCase.Expected == ' '
                expected = testCase.Shades(1);     % ░
            else
                expected = testCase.Shades(end);   % █
            end
            img = UniformCase.Value * ones(60, 80);
            txt = img2ascii(img, Width=40, Charset=string(testCase.Shades), ...
                Invert=UniformCase.Invert);
            testCase.verifyEqual(unique(txt), expected);
        end

        %% Invalid inputs
        function invalidImageErrors(testCase, InvalidImage)
            testCase.verifyError(@() img2ascii(InvalidImage), ?MException);
        end

        function invalidOptionErrors(testCase, InvalidOption)
            testCase.verifyError(@() img2ascii(rand(10), InvalidOption{:}), ?MException);
        end

        function wrongChannelCountHasErrorId(testCase)
            testCase.verifyError(@() img2ascii(rand(4, 4, 2)), "asciiart:input:invalidImage");
        end

        function missingFileHasErrorId(testCase)
            testCase.verifyError(@() img2ascii("no_such_image_file.png"), "asciiart:input:fileNotFound");
        end

        %% Block averaging: loop vs vectorized
        function loopAndVectorizedMatch(testCase, BlockShape)
            testCase.enterPrivateFolder();
            stream = RandStream("twister", "Seed", 42);
            A = rand(stream, BlockShape(1), BlockShape(2));

            expected = blockMeanLoop(A, BlockShape(3), BlockShape(4));
            actual = blockMeanVectorized(A, BlockShape(3), BlockShape(4));

            testCase.verifySize(actual, BlockShape(3:4));
            testCase.verifyEqual(actual, expected, AbsTol=1e-12);
        end

        function exactGridMatchesReshapeMean(testCase)
            testCase.enterPrivateFolder();
            A = rand(200, 300);
            expected = squeeze(mean(reshape(A, 4, 50, 3, 100), [1 3]));

            testCase.verifyEqual(blockMeanLoop(A, 50, 100), expected, AbsTol=1e-12);
            testCase.verifyEqual(blockMeanVectorized(A, 50, 100), expected, AbsTol=1e-12);
        end
    end

    methods
        function img = convertImage(testCase, ref, type)
            %CONVERTIMAGE Convert the uint8 grayscale REF to another input type.
            switch type
                case "doubleGray"
                    img = double(ref) / 255;
                case "singleGray"
                    img = single(ref) / 255;
                case "uint8RGB"
                    img = repmat(ref, 1, 1, 3);
                case "doubleRGB"
                    img = repmat(double(ref) / 255, 1, 1, 3);
                case "pngFile"
                    folder = testCase.applyFixture( ...
                        matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
                    img = fullfile(folder, "levels.png");
                    imwrite(ref, img);
            end
        end

        function enterPrivateFolder(testCase)
            %ENTERPRIVATEFOLDER Make src/private current for this test only.
            %   Private functions are only visible to code in src/, or when
            %   their folder is the current folder.
            testCase.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture( ...
                fullfile(Img2AsciiTest.rootFolder(), "src", "private")));
        end
    end

    methods (Static)
        function folder = rootFolder()
            folder = fileparts(fileparts(mfilename("fullpath")));
        end

        function c = edgeContrast(txt, charset)
            %EDGECONTRAST Largest darkness change between adjacent columns.
            [~, darkness] = ismember(txt, charset);
            c = max(abs(diff(darkness, 1, 2)), [], "all");
        end

        function [img, expected] = levelImage()
            %LEVELIMAGE 32x64 uint8 image of 8x8 blocks at known brightness.
            %   Each block takes one of 10 levels, each in the middle of a
            %   brightness bin of the default charset. With Width=8 and
            %   AspectCorrection=1 every block becomes one character, and
            %   level j maps to Charset(11 - j).
            levels = uint8(round(255 * ((1:10) - 0.5) / 10));
            levelIdx = mod((0:3).' * 8 + (0:7), 10) + 1;   % 4x8 grid
            img = repelem(levels(levelIdx), 8, 8);
            expected = Img2AsciiTest.Charset(11 - levelIdx);
        end
    end
end
