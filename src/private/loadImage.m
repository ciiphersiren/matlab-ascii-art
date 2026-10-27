function img = loadImage(img)
%LOADIMAGE Load an image and convert it to double in [0, 1].
%   IMG = LOADIMAGE(SOURCE) returns SOURCE as an M-by-N (grayscale) or
%   M-by-N-by-3 (RGB) double array with values in [0, 1]. SOURCE is either
%   an image filename or an image array. Indexed image files are converted
%   to RGB. Integer types are scaled by their full range, and
%   floating-point values outside [0, 1] are clipped.
%
%   See also IMG2ASCII, IMG2ASCIICOLOR.

if isStringScalar(img) || ischar(img)
    img = readImage(img);
end

if ndims(img) > 3 || ~any(size(img, 3) == [1 3])
    error("asciiart:input:invalidImage", ...
        "Image must be M-by-N (grayscale) or M-by-N-by-3 (RGB).");
end

if isinteger(img)
    lo = double(intmin(class(img)));
    hi = double(intmax(class(img)));
    img = (double(img) - lo) / (hi - lo);
else
    img = double(img);
end

img = min(max(img, 0), 1);
end

function img = readImage(filename)
%READIMAGE Read an image file, converting indexed images to RGB.
if ~exist(filename, "file")
    error("asciiart:input:fileNotFound", "Image file ""%s"" not found.", filename);
end
[img, map] = imread(filename);
if ~isempty(map)
    img = ind2rgb(img, map);
end
end
