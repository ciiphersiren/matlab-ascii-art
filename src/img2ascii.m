function txt = img2ascii(img, opts)
%IMG2ASCII Convert an image to ASCII art.
%   TXT = IMG2ASCII(IMG) converts the image IMG to ASCII art and returns it
%   as a character matrix that is 100 characters wide. IMG is either the
%   name of an image file or an image array. Image arrays can be grayscale
%   (M-by-N) or RGB (M-by-N-by-3), of class uint8, uint16, int16, single,
%   double, or logical. Floating-point images are expected in [0, 1];
%   values outside that range are clipped.
%
%   TXT = IMG2ASCII(IMG, Name=Value) specifies options using one or more
%   name-value arguments:
%
%     Width            - Number of characters per row, specified as a
%                        positive integer. Default: 100.
%     Charset          - Characters used for shading, ordered from
%                        lightest (least ink) to darkest (most ink),
%                        specified as a string scalar or character vector.
%                        Default: " .:-=+*#%@".
%     Invert           - Flip the brightness mapping, specified as a
%                        logical scalar. Use true when displaying on a dark
%                        background so that bright image regions get dense
%                        characters. Default: false.
%     AspectCorrection - Row scale factor, specified as a positive scalar.
%                        Characters are roughly twice as tall as they are
%                        wide, so the row count is scaled by this factor to
%                        keep the image proportions. Default: 0.5.
%     Contrast         - "stretch", "equalize", or "none". Default:
%                        "stretch". See ADJUSTTONE.
%     Gamma            - Gamma exponent, positive scalar. Default: 1.
%                        See ADJUSTTONE.
%     Sharpen          - Edge-sharpening amount, nonnegative scalar.
%                        Default: 0. See ADJUSTTONE.
%
%   TXT is a char matrix of size NumRows-by-Width, where
%   NumRows = max(1, round(Width * M/N * AspectCorrection)) for an M-by-N
%   image.
%
%   Each character represents the average brightness of the image region
%   it covers. RGB images are converted to grayscale using the luminance
%   Rec. 601 weights 0.299 R + 0.587 G + 0.114 B, which sum to 1 so a gray
%   RGB image matches its grayscale version. Block boundaries are rounded
%   outward to whole pixels, so a pixel that straddles a boundary counts
%   toward both neighboring blocks. Image sizes therefore do not need to be
%   multiples of the output grid size, and nothing is cropped or padded.
%   Tone adjustments (Contrast, Gamma, Sharpen) are applied to the
%   averaged grid, so they act at the scale of single characters.
%
%   Examples
%       % Convert an image file that ships with MATLAB
%       txt = img2ascii("peppers.png");
%       disp(txt)
%
%       % Narrower output for a dark-themed Command Window
%       txt = img2ascii("peppers.png", Width=60, Invert=true);
%       disp(txt)
%
%       % Horizontal gradient with a custom character set
%       img = repmat(linspace(0, 1, 200), 50, 1);
%       disp(img2ascii(img, Width=40, Charset=" .oO@"))
%
%       % Busy photo: more columns, sharper edges, even use of shades
%       txt = img2ascii("peppers.png", Width=140, Sharpen=1, Contrast="equalize");
%
%   See also IMG2ASCIICOLOR, ADJUSTTONE, ASCII2TXT, ASCII2PNG, IMREAD.

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

gray = toGrayscale(img);
[h, w] = size(gray);

% Output grid size: Width columns, rows follow the image aspect ratio
nCols = opts.Width;
nRows = max(1, round(nCols * (h / w) * opts.AspectCorrection));

small = blockMeanVectorized(gray, nRows, nCols);
small = adjustTone(small, Contrast=opts.Contrast, Gamma=opts.Gamma, Sharpen=opts.Sharpen);

% Map brightness to characters. By default bright regions get light
% characters (dark ink on a light background).
chars = char(opts.Charset);
n = numel(chars);
if ~opts.Invert
    small = 1 - small;
end
idx = min(max(floor(small * n) + 1, 1), n);   % clamp guards round-off at 0 and 1
txt = reshape(chars(idx), size(idx));
end

function gray = toGrayscale(img)
%TOGRAYSCALE Load IMG if needed and convert it to grayscale double in [0, 1].
gray = loadImage(img);
if size(gray, 3) == 3
    gray = 0.299 * gray(:,:,1) + 0.587 * gray(:,:,2) + 0.114 * gray(:,:,3);
end
end
