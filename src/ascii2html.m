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
