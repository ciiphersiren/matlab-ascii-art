%% DEMO_EXPORT  Convert an image to ASCII art and save it as text and PNG.
%   Converts examples/sample.jpg (or peppers.png, which ships with MATLAB,
%   if there is no sample) and saves four files to examples/output:
%
%     <name>_ascii.txt           - plain text, UTF-8
%     <name>_ascii.png           - black text on white
%     <name>_ascii_terminal.png  - green text on black
%     <name>_ascii_color.html    - full-color characters, opened with WEB
%
%   See also IMG2ASCII, IMG2ASCIICOLOR, ASCII2TXT, ASCII2PNG, ASCII2HTML.

%% Set up the path and folders
thisDir = fileparts(mfilename("fullpath"));
if isempty(thisDir)
    thisDir = pwd;   % running a selection rather than the whole script
end
addpath(fullfile(thisDir, "..", "src"));

outDir = fullfile(thisDir, "output");
if ~isfolder(outDir)
    mkdir(outDir);
end

%% Pick the source image
source = fullfile(thisDir, "sample.jpg");
if ~isfile(source)
    source = "peppers.png";
end
[~, name] = fileparts(source);

%% Convert and save
txt = img2ascii(source, Width=100);
txtFile = fullfile(outDir, name + "_ascii.txt");
ascii2txt(txt, txtFile);

pngFile = fullfile(outDir, name + "_ascii.png");
ascii2png(txt, pngFile);

% Dark background needs Invert=true so bright regions get dense characters
txtDark = img2ascii(source, Width=100, Invert=true);
darkFile = fullfile(outDir, name + "_ascii_terminal.png");
ascii2png(txtDark, darkFile, BackgroundColor="black", TextColor="#33FF66");

% Color HTML: black page background, so Invert=true here too
[txtColor, colors] = img2asciiColor(source, Width=100, Invert=true);
htmlFile = fullfile(outDir, name + "_ascii_color.html");
ascii2html(txtColor, colors, htmlFile, Title=name + " in color ASCII");

fprintf("Saved:\n  %s\n  %s\n  %s\n  %s\n", txtFile, pngFile, darkFile, htmlFile);
web(htmlFile);

%% Show the saved PNGs
fig = figure(Name="img2ascii export", Color="w");
tl = tiledlayout(fig, 1, 2, TileSpacing="compact", Padding="compact");

ax1 = nexttile(tl);
image(ax1, imread(pngFile));
axis(ax1, "image", "off");
title(ax1, name + "\_ascii.png");

ax2 = nexttile(tl);
image(ax2, imread(darkFile));
axis(ax2, "image", "off");
title(ax2, name + "\_ascii\_terminal.png");