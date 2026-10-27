function mustBeImageSource(img)
%MUSTBEIMAGESOURCE Validate that IMG is a filename or a nonempty image array.
%   Argument validator shared by IMG2ASCII and IMG2ASCIICOLOR. The number
%   of color channels is checked later by LOADIMAGE, after a file is read.
if isStringScalar(img) || (ischar(img) && isrow(img))
    return
end
if ~(isnumeric(img) || islogical(img)) || isempty(img) || ~isreal(img)
    error("asciiart:input:invalidImage", ...
        "Image must be a filename or a nonempty, real numeric or logical array.");
end
end
