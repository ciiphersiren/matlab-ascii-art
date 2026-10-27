%% DEMO_BASIC  Convert an image to ASCII art with IMG2ASCII.
%   Loads sample.png or sample.jpg from the examples folder, prints the
%   ASCII art to the Command Window, and shows the original image next to
%   the ASCII rendering in a figure. If no sample image is found, a
%   synthetic image (a shaded sphere on a gradient) is generated instead.
%
%   See also IMG2ASCII.

%% Set up the path
thisDir = fileparts(mfilename("fullpath"));
if isempty(thisDir)
    thisDir = pwd;   % running a selection rather than the whole script
end
addpath(fullfile(thisDir, "..", "src"));

%% Load a sample image, or generate one
candidates = fullfile(thisDir, ["sample.png", "sample.jpg"]);
found = candidates(isfile(candidates));

if ~isempty(found)
    [img, map] = imread(found(1));
    if ~isempty(map)
        img = ind2rgb(img, map);
    end
    [~, name, ext] = fileparts(found(1));
    source = name + ext;
else
    % Horizontal gradient background with a sphere lit from the upper left
    [x, y] = meshgrid(linspace(-1.6, 1.6, 320), linspace(-1.2, 1.2, 240));
    img = rescale(x, 0.1, 0.9);

    inside = x.^2 + y.^2 <= 1;
    z = sqrt(max(0, 1 - x.^2 - y.^2));
    light = [-1 -1 1.5] / norm([-1 -1 1.5]);
    shade = max(0, light(1)*x + light(2)*y + light(3)*z);
    img(inside) = 0.05 + 0.95 * shade(inside);

    source = "synthetic gradient + circle";
end

%% Convert and print to the Command Window
txt = img2ascii(img, Width=80);
fprintf("ASCII art of %s (%d x %d characters):\n\n", source, size(txt, 1), size(txt, 2));
disp(txt)

%% Show the original next to the ASCII rendering
fig = figure(Name="img2ascii demo", Color="w");
fig.Position(3:4) = [1100 450];
tl = tiledlayout(fig, 1, 2, TileSpacing="compact", Padding="compact");

ax1 = nexttile(tl);
if size(img, 3) == 1
    imagesc(ax1, img, [0 1]);
    colormap(ax1, gray(256));
else
    image(ax1, img);
end
axis(ax1, "image", "off");
title(ax1, "Original: " + source, Interpreter="none");

ax2 = nexttile(tl);
axis(ax2, [0 1 0 1]);
axis(ax2, "off");
title(ax2, "ASCII art");

% Pick the largest monospace font size that fits the text in the axes.
% Line height is about 1.2x the font size; character width about 0.6x.
drawnow
ax2.Units = "pixels";
axSize = ax2.Position(3:4);
fontPx = min(axSize(2) / (1.2 * size(txt, 1)), axSize(1) / (0.6 * size(txt, 2)));
ax2.Units = "normalized";

text(ax2, 0, 0.5, txt, FontName="Courier", FontUnits="pixels", FontSize=fontPx, ...
    HorizontalAlignment="left", VerticalAlignment="middle", Interpreter="none");
