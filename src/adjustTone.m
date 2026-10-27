function out = adjustTone(gray, opts)
%ADJUSTTONE Enhance a grayscale image for ASCII rendering.
%   OUT = ADJUSTTONE(GRAY) stretches the contrast of the grayscale image
%   GRAY so that its 1st and 99th brightness percentiles map to 0 and 1.
%   GRAY is a real matrix with values in [0, 1]. OUT is a double matrix of
%   the same size with values in [0, 1].
%
%   OUT = ADJUSTTONE(GRAY, Name=Value) specifies options using one or more
%   name-value arguments:
%
%     Contrast - Global contrast method, specified as one of:
%                  "stretch"  - Map the 1st..99th percentiles to [0, 1].
%                               Clips a few outliers and leaves the
%                               shape of the histogram unchanged.
%                  "equalize" - Histogram equalization. Spreads values
%                               evenly across all shades so every
%                               character gets used. Strongest effect on
%                               low-contrast images, but large flat areas
%                               become mid-gray.
%                  "none"     - No global contrast change.
%                Default: "stretch".
%     Gamma    - Gamma exponent applied last, specified as a positive
%                scalar. Values below 1 brighten mid-tones and values
%                above 1 darken them. Default: 1.
%     Sharpen  - Unsharp-mask amount, specified as a nonnegative scalar.
%                Boosts each value by Sharpen times its difference from
%                the 3-by-3 local mean, which makes edges stand out. Try
%                0.5 to 2. Default: 0.
%
%   The steps are applied in the order Sharpen, Contrast, Gamma.
%
%   Examples
%       % Low-contrast ramp stretched to the full range
%       g = repmat(linspace(0.4, 0.6, 50), 10, 1);
%       out = adjustTone(g);
%       [min(out(:)) max(out(:))]
%
%       % Equalize and sharpen
%       out = adjustTone(rand(40, 80), Contrast="equalize", Sharpen=1);
%
%   See also IMG2ASCII.

arguments
    gray (:,:) double {mustBeReal}
    opts.Contrast (1,1) string {mustBeMember(opts.Contrast, ["stretch", "equalize", "none"])} = "stretch"
    opts.Gamma (1,1) double {mustBePositive, mustBeFinite} = 1
    opts.Sharpen (1,1) double {mustBeNonnegative, mustBeFinite} = 0
end

out = gray;
if opts.Sharpen > 0
    out = sharpen(out, opts.Sharpen);
end

switch opts.Contrast
    case "stretch"
        out = stretch(out);
    case "equalize"
        out = equalize(out);
end

out = min(max(out, 0), 1) .^ opts.Gamma;
end

function out = sharpen(g, amount)
%SHARPEN Unsharp mask with a 3-by-3 box blur and replicated edges.
padded = g([1 1:end end], [1 1:end end]);
blurred = conv2(padded, ones(3) / 9, "valid");
out = g + amount * (g - blurred);
end

function out = stretch(g)
%STRETCH Map the 1st..99th percentiles of G to [0, 1].
v = sort(g(:));
n = numel(v);
lo = v(max(1, ceil(0.01 * n)));
hi = v(max(1, ceil(0.99 * n)));
if hi - lo < 1e-6
    out = g;   % flat image: nothing to stretch
    return
end
out = (g - lo) / (hi - lo);
end

function out = equalize(g)
%EQUALIZE Histogram equalization using 256 bins.
%   Each bin maps to the midpoint of its step in the cumulative histogram,
%   so a large flat region lands in the middle of the range it occupies
%   instead of at its top.
nBins = 256;
bin = min(floor(min(max(g, 0), 1) * nBins) + 1, nBins);
counts = accumarray(bin(:), 1, [nBins 1]);
level = (cumsum(counts) - counts / 2) / numel(g);
out = reshape(level(bin), size(g));
end
