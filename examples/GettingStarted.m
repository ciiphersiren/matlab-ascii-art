%% Getting Started with ASCII Art in MATLAB
% This example shows how to turn images into ASCII art with the functions in
% this project. It covers basic conversion, the options that control the look,
% color output, exporting to text, PNG, and HTML, and the performance of the
% core block-averaging step.
%
% Everything uses base MATLAB only. No toolboxes are required.
%
% *Tip:* To view this example with formatted text and inline output,
% right-click |GettingStarted.m| in the Files panel and select *Open as Live
% Script*.

%% Set Up the Path
% The functions are in the |src| folder, next to this |examples| folder.

exampleDir = fileparts(mfilename("fullpath"));
if isempty(exampleDir)
    exampleDir = pwd;   % running a selection rather than the whole script
end
rootDir = fileparts(exampleDir);
addpath(fullfile(rootDir, "src"));

%% Convert an Image
% |img2ascii| takes an image file name or an image array (grayscale or RGB;
% |uint8|, |uint16|, |single|, |double|, or |logical|) and returns a character
% matrix. Each character stands for the average brightness of the image region
% behind it.
%
% This example uses |peppers.png|, which ships with MATLAB.

img = imread("peppers.png");
figure
image(img)
axis image off
title("Original image")

txt = img2ascii(img, Width=80);
disp(txt)

%%
% The result is an ordinary |char| matrix, one row per line of text:

size(txt)

%% Choose the Width
% |Width| sets the number of characters per row. The number of rows follows
% from the image's aspect ratio. More characters keep more detail; fewer give
% a bolder, more abstract look.

disp(img2ascii(img, Width=40))

%% Choose a Character Set
% |Charset| lists the characters to shade with, ordered from *lightest* (least
% ink) to *darkest* (most ink). The default is |" .:-=+*#%@"|. Fewer characters
% give stronger contrast; more give smoother gradients.

disp(img2ascii(img, Width=60, Charset=" .oO@"))

%%
% Unicode characters work too. Block shading gives a dense, pixel-art look:

blocks = string(char([0x20 0x2591 0x2592 0x2593 0x2588]));   % " ░▒▓█"
disp(img2ascii(img, Width=60, Charset=blocks))

%% Invert for Dark Backgrounds
% By default, bright image regions get light characters, which suits dark text
% on a light background. On a dark background, such as a dark-themed Command
% Window, set |Invert| to |true| so bright regions get dense characters.

disp(img2ascii(img, Width=60, Invert=true))

%% Adjust the Tone
% Three options change how brightness maps to characters. They are applied to
% the downsampled grid, so they act at the scale of single characters.
%
% * |Contrast| — |"stretch"| (default) maps the 1st to 99th brightness
% percentiles to the full range. |"equalize"| spreads values evenly so every
% character gets used. |"none"| leaves brightness unchanged.
% * |Gamma| — values below 1 brighten mid-tones; values above 1 darken them.
% * |Sharpen| — an unsharp mask that makes edges stand out. Try 0.5 to 2.
%
% Equalization helps most with images that are mostly mid-tones:

disp(img2ascii(img, Width=60, Contrast="equalize"))

%%
% Sharpening makes outlines crisper, which helps busy photos:

disp(img2ascii(img, Width=60, Sharpen=1.5))

%% Correct the Aspect Ratio
% Text characters are roughly twice as tall as they are wide. To keep the
% image's proportions, |img2ascii| scales the number of rows by
% |AspectCorrection|, which is 0.5 by default:
%
% $$\textrm{rows} = \textrm{round}\left(\textrm{Width} \cdot \frac{H}{W} \cdot
% \textrm{AspectCorrection}\right)$$
%
% With no correction, the same image looks stretched vertically:

disp(img2ascii(img, Width=40, AspectCorrection=1))

%% Color Mode
% |img2asciiColor| returns the same characters as |img2ascii|, plus the average
% RGB color behind each character. It accepts the same options.

[txtColor, colors] = img2asciiColor(img, Width=80, Invert=true);
size(colors)

%%
% The color grid is a tiny version of the image, one pixel per character:

figure
image(colors)
axis image off
title("Average color behind each character")

%%
% |ascii2html| writes a standalone HTML page with each character in its color.
% The page has a black background, which is why |Invert| is |true| above.
% Consecutive characters with the same color share one |<span>|, which keeps
% the file small.

htmlFile = fullfile(tempdir, "peppers_color.html");
ascii2html(txtColor, colors, htmlFile, Title="Peppers in color ASCII");
web(htmlFile)

%% Export to Text and PNG
% |ascii2txt| saves the art as a UTF-8 text file, one row per line:

txtFile = fullfile(tempdir, "peppers_ascii.txt");
ascii2txt(txt, txtFile);
txtLines = readlines(txtFile);
disp(txtLines(1:5))

%%
% |ascii2png| renders the art in a monospace font and saves it as an image.
% |BackgroundColor| and |TextColor| accept color names, hex codes, or RGB
% triplets.

pngFile = fullfile(tempdir, "peppers_ascii.png");
ascii2png(txt, pngFile);

figure
image(imread(pngFile))
axis image off
title("ascii2png output")

%% Performance: Loops vs. Vectorized
% The core step averages the pixels in each block of the output grid. The
% project includes two implementations in |src/private|:
%
% * |blockMeanLoop| visits every pixel with nested |for|-loops.
% * |blockMeanVectorized| uses cumulative sums. With $C = \textrm{cumsum}(A)$
% down each column, the sum of rows $r_0+1$ through $r_1$ is
% $C(r_1) - C(r_0)$ for every column at once. One pass over the image reduces
% it to one row per block, and the same step along the columns then runs on
% that much smaller matrix.
%
% Both handle image sizes that do not divide evenly into the grid, and they
% give the same result (checked with |assert| and in the unit tests).
%
% The benchmark script times both with |timeit| on images from 256-by-256 to
% 4096-by-4096 and plots the results. It takes about a minute.

run(fullfile(exampleDir, "benchmark_blockmean.m"))

%%
% End to end, converting a full-size photo takes:

fprintf("img2ascii on a %dx%d image: %.1f ms\n", size(img, 1), size(img, 2), ...
    1000 * timeit(@() img2ascii(img, Width=100)));

%% Run the Tests
% The |tests| folder has three |matlab.unittest| test classes:
%
% * |Img2AsciiTest| — output size, brightness mapping, input types, edge cases,
% invalid inputs, tone options, Unicode charsets, and loop/vectorized
% equivalence
% * |ExportTest| — text file round trips and PNG output
% * |ColorTest| — color output and HTML export

testFiles = fullfile(rootDir, "tests", ["Img2AsciiTest.m", "ExportTest.m", "ColorTest.m"]);
results = runtests(testFiles);
disp(results)

%%
% For a results table and an HTML code coverage report of |src|, run the
% |runAllTests| script instead:
%
%   run(fullfile(rootDir, "tests", "runAllTests.m"))

%% Try the Interactive App
% |AsciiArtApp| puts all of this in a window, with live updates as you change
% the controls and buttons to export or copy the result. You can load images
% from MATLAB Drive or upload them from your own computer.
%
%   addpath(fullfile(rootDir, "app"))
%   AsciiArtApp
function ascii2html(txt, colors, filename, opts)
%ASCII2HTML Save colored ASCII art as a standalone HTML file.
%   ASCII2HTML(TXT, COLORS, FILENAME) writes the character matrix TXT to
%   the HTML file FILENAME, with each character colored by the matching
%   RGB triplet in COLORS. COLORS is a NumRows-by-NumCols-by-3 array with
%   values in [0, 1], such as the second output of IMG2ASCIICOLOR. The
%   page uses a monospace font on a black background and needs no other
%   files. The file is UTF-8 encoded.
%
%   To keep the file small, runs of consecutive characters with the same
%   color share one <span>. Spaces take the color of the character before
%   them, since their color is invisible, so they never break a run.
%
%   ASCII2HTML(TXT, COLORS, FILENAME, Name=Value) specifies options using
%   one or more name-value arguments:
%
%     FontSize        - Font size in CSS pixels, specified as a positive
%                       scalar. Default: 10.
%     BackgroundColor - Page background, specified as a color name,
%                       hexadecimal color code, or RGB triplet.
%                       Default: "black".
%     Title           - Page title, specified as a string scalar.
%                       Default: "ASCII art".
%
%   Example
%       [txt, colors] = img2asciiColor("peppers.png", Width=100, Invert=true);
%       ascii2html(txt, colors, "peppers.html");
%       web("peppers.html")
%
%   See also IMG2ASCIICOLOR, ASCII2TXT, ASCII2PNG.

arguments
    txt (:,:) char
    colors (:,:,3) double {mustBeInRange(colors, 0, 1)}
    filename (1,1) string {mustBeNonzeroLengthText}
    opts.FontSize (1,1) double {mustBePositive, mustBeFinite} = 10
    opts.BackgroundColor = "black"
    opts.Title (1,1) string = "ASCII art"
end

if ~isequal(size(colors, [1 2]), size(txt))
    error("asciiart:input:sizeMismatch", ...
        "COLORS must be %d-by-%d-by-3 to match TXT.", size(txt, 1), size(txt, 2));
end

rgb = round(255 * colors);
rows = strings(size(txt, 1), 1);
for r = 1:size(txt, 1)
    rows(r) = rowToHtml(txt(r, :), reshape(rgb(r, :, :), [], 3));
end

bg = rgbToHex(round(255 * validatecolor(opts.BackgroundColor)));
html = join([
    "<!DOCTYPE html>"
    "<html>"
    "<head>"
    "<meta charset=""utf-8"">"
    "<title>" + escapeHtml(opts.Title) + "</title>"
    "<style>"
    "body { background: " + bg + "; margin: 0; padding: 16px; }"
    "pre { font-family: Consolas, ""Courier New"", monospace; font-size: " + opts.FontSize + "px; line-height: 1.2; margin: 0; }"
    "</style>"
    "</head>"
    "<body>"
    "<pre>" + join(rows, newline) + "</pre>"
    "</body>"
    "</html>"
    ], newline) + newline;

[fid, msg] = fopen(filename, "w", "n", "UTF-8");
if fid < 0
    error("asciiart:io:cannotOpenFile", "Cannot open ""%s"" for writing: %s", filename, msg);
end
closeFile = onCleanup(@() fclose(fid));
fprintf(fid, "%s", html);
end

function html = rowToHtml(chars, rgb)
%ROWTOHTML One row of characters as <span> elements, one per color run.
%   CHARS is 1-by-W and RGB is W-by-3 integers in [0, 255].

% Spaces borrow the color of the previous visible character (or the first
% visible one, for leading spaces) so they extend runs instead of breaking them
visible = find(chars ~= ' ');
if isempty(visible)
    html = string(chars);   % all spaces: no color needed
    return
end
src = zeros(size(chars));
src(visible) = visible;
src = cummax(src);
src(src == 0) = visible(1);
rgb = rgb(src, :);

% A new run starts wherever the color differs from the previous column
starts = find([true; any(diff(rgb, 1, 1) ~= 0, 2)]);
stops = [starts(2:end) - 1; numel(chars)];

segments = escapeHtml(arrayfun(@(a, b) chars(a:b), starts, stops, UniformOutput=false));
html = join(compose("<span style=""color:%s"">%s</span>", ...
    rgbToHex(rgb(starts, :)), segments), "");
end

function hex = rgbToHex(rgb)
%RGBTOHEX N-by-3 integers in [0, 255] to an N-by-1 string array "#RRGGBB".
hex = compose("#%02X%02X%02X", rgb(:, 1), rgb(:, 2), rgb(:, 3));
end

function s = escapeHtml(s)
%ESCAPEHTML Escape the characters that are special inside HTML text.
s = replace(string(s), "&", "&amp;");   % first, so later escapes are not doubled
s = replace(s, ["<", ">"], ["&lt;", "&gt;"]);
end
