function ascii2png(txt, filename, opts)
%ASCII2PNG Render ASCII art to an image file.
%   ASCII2PNG(TXT, FILENAME) renders the character matrix TXT in a
%   monospace font and saves it as an image. The format follows the file
%   extension of FILENAME (.png recommended; .jpg and .tif also work).
%   The text is drawn in an invisible figure, so nothing appears on
%   screen, and saved with EXPORTGRAPHICS at 150 DPI.
%
%   ASCII2PNG(TXT, FILENAME, Name=Value) specifies options using one or
%   more name-value arguments:
%
%     FontSize        - Font size in points, specified as a positive
%                       scalar. Default: 10.
%     BackgroundColor - Background color, specified as a color name,
%                       hexadecimal color code, or RGB triplet.
%                       Default: "white".
%     TextColor       - Text color, specified the same way.
%                       Default: "black".
%
%   For light text on a dark background, create TXT with Invert=true so
%   that bright image regions get dense characters.
%
%   Examples
%       txt = img2ascii("peppers.png", Width=80);
%       ascii2png(txt, "peppers_ascii.png");
%
%       % Green-on-black terminal look
%       txt = img2ascii("peppers.png", Width=80, Invert=true);
%       ascii2png(txt, "peppers_terminal.png", ...
%           BackgroundColor="black", TextColor="#33FF66");
%
%   See also IMG2ASCII, ASCII2TXT, ASCII2HTML, EXPORTGRAPHICS, VALIDATECOLOR.

arguments
    txt (:,:) char
    filename (1,1) string {mustBeNonzeroLengthText}
    opts.FontSize (1,1) double {mustBePositive, mustBeFinite} = 10
    opts.BackgroundColor = "white"
    opts.TextColor = "black"
end

bg = validatecolor(opts.BackgroundColor);
fg = validatecolor(opts.TextColor);
margin = 2 * opts.FontSize;   % pixels on each side

% WindowStyle="normal" because docked figures (the default in some
% environments, such as MATLAB Online) ignore Position changes
fig = figure(Visible="off", WindowStyle="normal", Color=bg, Units="pixels");
closeFigure = onCleanup(@() close(fig));

% Axes fill the figure and draw only their background, so the exported
% image includes the margin around the text
ax = axes(fig, Units="normalized", Position=[0 0 1 1], Color=bg, ...
    XColor="none", YColor="none", XTick=[], YTick=[]);

t = text(ax, 0, 0, txt, Units="pixels", FontName="FixedWidth", ...
    FontSize=opts.FontSize, Color=fg, Interpreter="none", ...
    HorizontalAlignment="left", VerticalAlignment="bottom");

% Size the figure to the rendered text plus the margin, then place the
% text at the bottom-left corner of the margin
extent = t.Extent;
fig.Position(3:4) = ceil(extent(3:4) + 2 * margin);
t.Position = [margin margin 0];

exportgraphics(fig, filename, BackgroundColor=bg, Resolution=150);
end
