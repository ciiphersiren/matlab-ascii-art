function [txt, colors] = img2asciiColor(img, opts)
%IMG2ASCIICOLOR Convert an image to ASCII art with a color per character.
%   [TXT, COLORS] = IMG2ASCIICOLOR(IMG) returns the ASCII art TXT, exactly
%   as IMG2ASCII would, plus COLORS, a NumRows-by-Width-by-3 double array
%   of the average RGB color in [0, 1] of the image region behind each
%   character. Grayscale images give gray colors (R = G = B).
%
%   [TXT, COLORS] = IMG2ASCIICOLOR(IMG, Name=Value) accepts the same
%   name-value arguments as IMG2ASCII: Width, Charset, Invert,
%   AspectCorrection, Contrast, Gamma, and Sharpen. The tone options shape
%   the characters only; COLORS always holds the true average colors.
%
%   Colored characters are usually shown on a dark background, so use
%   Invert=true to give bright regions dense characters.
%
%   Example
%       [txt, colors] = img2asciiColor("peppers.png", Width=100, Invert=true);
%       ascii2html(txt, colors, "peppers.html");
%       web("peppers.html")
%
%   See also IMG2ASCII, ASCII2HTML.

arguments
    img {mustBeImageSource}
    opts.Width (1,1) double {mustBeInteger, mustBePositive} = 100
    opts.Charset (1,1) string {mustBeNonzeroLengthText} = " .:-=+*#%@"
    opts.Invert (1,1) logical = false
    opts.AspectCorrection (1,1) double {mustBePositive, mustBeFinite} = 0.5
    opts.Contrast (1,1) string {mustBeMember(opts.Contrast, ["stretch", "equalize", "none"])} = "stretch"
    opts.Gamma (1,1) double {mustBePositive, mustBeFinite} = 1
    opts.Sharpen (1,1) double {mustBeNonnegative, mustBeFinite} = 0
end

% Load once and pass the array on, so a file is not read twice
rgb = loadImage(img);
args = namedargs2cell(opts);
txt = img2ascii(rgb, args{:});

% Average each channel over the same grid img2ascii used
[nRows, nCols] = size(txt);
if size(rgb, 3) == 1
    rgb = repmat(rgb, 1, 1, 3);
end
colors = zeros(nRows, nCols, 3);
for c = 1:3
    colors(:,:,c) = blockMeanVectorized(rgb(:,:,c), nRows, nCols);
end
end