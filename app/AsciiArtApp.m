classdef AsciiArtApp < handle
%ASCIIARTAPP Interactive image-to-ASCII-art converter.
%   ASCIIARTAPP opens the app. It starts with a sample image, and the
%   ASCII art updates live as you change the controls.
%
%   APP = ASCIIARTAPP returns the app object. Close the window or call
%   DELETE(APP) to close the app.
%
%   Controls
%     Load Image  - Open an image file (PNG, JPEG, BMP, TIFF, GIF). In
%                   MATLAB Online this browses MATLAB Drive.
%     Upload from Computer
%                 - Pick an image from your own computer using the
%                   browser's file picker. Works in MATLAB Online too.
%     Width       - Characters per row, 20 to 300.
%     Charset     - Classic, Blocks, Minimal, or Custom (type your own
%                   characters, lightest first).
%     Invert      - Light text on a dark background.
%     Color mode  - Color each character with the image color behind it.
%     Export      - Save as TXT, PNG, or HTML, or copy the text.
%
%   The app is built programmatically with UIFIGURE, so it is plain text
%   and works in MATLAB Online. All conversion and export work is done by
%   the functions in src/.
%
%   Example
%       app = AsciiArtApp;
%
%   See also IMG2ASCII, IMG2ASCIICOLOR, ASCII2TXT, ASCII2PNG, ASCII2HTML.

    properties (Constant, Access = private)
        BlocksCharset = string(char([0x20 0x2591 0x2592 0x2593 0x2588]))   % " ░▒▓█"
        MaxWorkingSize = 1200   % longest image side kept in memory, in pixels (also MAX_SIZE in uploadButton.html)
        DebounceDelay = 0.15    % seconds of quiet before re-rendering
    end

    properties (Access = private)
        % Components
        UIFigure
        LoadButton
        UploadHTML
        ImageAxes
        WidthSlider
        WidthValueLabel
        CharsetDropDown
        CustomCharsetField
        InvertCheckBox
        ColorCheckBox
        ExportTxtButton
        ExportPngButton
        ExportHtmlButton
        CopyButton
        OutputTextArea
        OutputHTML
        StatusLabel

        % State
        Image                   % working copy of the loaded image
        ImageName = "image"     % file name shown in the title and used for exports
        Width = 100             % current slider value, rounded
        Txt = ''                % last rendered ASCII art
        Colors = []             % last rendered colors (color mode only)
        DebounceTimer
    end

    methods
        function app = AsciiArtApp()
            addpath(fullfile(fileparts(mfilename("fullpath")), "..", "src"));
            app.createComponents();
            app.DebounceTimer = timer(ExecutionMode="singleShot", ...
                StartDelay=app.DebounceDelay, ...
                TimerFcn=@(~, ~) app.safely("Rendering failed", @app.render));
            app.safely("Could not load the sample image", @app.loadSample);
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if ~isempty(app.DebounceTimer) && isvalid(app.DebounceTimer)
                stop(app.DebounceTimer);
                delete(app.DebounceTimer);
            end
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end

    methods (Access = private)
        %% Layout
        function createComponents(app)
            app.UIFigure = uifigure(Name="ASCII Art", Position=[100 100 1200 720], ...
                CloseRequestFcn=@(~, ~) delete(app));
            main = uigridlayout(app.UIFigure, [1 2], ColumnWidth={340, "1x"});

            % Left: image and settings
            left = uigridlayout(uipanel(main, Title="Image and settings"), [8 3], ...
                ColumnWidth={60, "1x", 40}, ...
                RowHeight={30, "1x", 50, "fit", "fit", "fit", "fit", "fit"});

            loadRow = uigridlayout(left, [1 2], Padding=0);
            AsciiArtApp.place(loadRow, 1, [1 3]);
            app.LoadButton = uibutton(loadRow, Text="Load Image", ...
                Tooltip="Browse MATLAB Drive (MATLAB Online) or local files (desktop)", ...
                ButtonPushedFcn=@(~, ~) app.safely("Could not load image", @app.loadFromFile));
            app.UploadHTML = uihtml(loadRow, ...
                HTMLSource=fullfile(fileparts(mfilename("fullpath")), "uploadButton.html"), ...
                HTMLEventReceivedFcn=@(~, event) app.safely("Could not upload image", ...
                    @() app.onUploadEvent(event)));

            app.ImageAxes = uiaxes(left);
            AsciiArtApp.place(app.ImageAxes, 2, [1 3]);
            axis(app.ImageAxes, "off");
            app.ImageAxes.Toolbar.Visible = "off";
            disableDefaultInteractivity(app.ImageAxes);

            AsciiArtApp.place(uilabel(left, Text="Width"), 3, 1);
            app.WidthSlider = uislider(left, Limits=[20 300], Value=app.Width, ...
                MajorTicks=[20 100 200 300], ...
                ValueChangingFcn=@(~, event) app.onWidthChanging(event.Value), ...
                ValueChangedFcn=@(src, ~) app.onWidthChanged(src.Value));
            AsciiArtApp.place(app.WidthSlider, 3, 2);
            app.WidthValueLabel = uilabel(left, Text=string(app.Width), ...
                HorizontalAlignment="right");
            AsciiArtApp.place(app.WidthValueLabel, 3, 3);

            AsciiArtApp.place(uilabel(left, Text="Charset"), 4, 1);
            app.CharsetDropDown = uidropdown(left, ...
                Items=["Classic", "Blocks " + strtrim(app.BlocksCharset), "Minimal", "Custom"], ...
                ItemsData=["classic", "blocks", "minimal", "custom"], ...
                ValueChangedFcn=@(~, ~) app.onCharsetChanged());
            AsciiArtApp.place(app.CharsetDropDown, 4, [2 3]);

            AsciiArtApp.place(uilabel(left, Text="Custom"), 5, 1);
            app.CustomCharsetField = uieditfield(left, "text", Value=" .oO@", ...
                Enable="off", Tooltip="Characters from lightest to darkest", ...
                ValueChangedFcn=@(~, ~) app.scheduleRender());
            AsciiArtApp.place(app.CustomCharsetField, 5, [2 3]);

            app.InvertCheckBox = uicheckbox(left, Text="Invert (light text on dark background)", ...
                ValueChangedFcn=@(~, ~) app.scheduleRender());
            AsciiArtApp.place(app.InvertCheckBox, 6, [1 3]);

            app.ColorCheckBox = uicheckbox(left, Text="Color mode", ...
                ValueChangedFcn=@(~, ~) app.scheduleRender());
            AsciiArtApp.place(app.ColorCheckBox, 7, [1 3]);

            buttons = uigridlayout(left, [2 2], Padding=0, RowHeight={"fit", "fit"});
            AsciiArtApp.place(buttons, 8, [1 3]);
            app.ExportTxtButton = uibutton(buttons, Text="Export TXT", ...
                ButtonPushedFcn=@(~, ~) app.safely("Export failed", @app.exportTxt));
            app.ExportPngButton = uibutton(buttons, Text="Export PNG", ...
                ButtonPushedFcn=@(~, ~) app.safely("Export failed", @app.exportPng));
            app.ExportHtmlButton = uibutton(buttons, Text="Export HTML", ...
                ButtonPushedFcn=@(~, ~) app.safely("Export failed", @app.exportHtml));
            app.CopyButton = uibutton(buttons, Text="Copy to Clipboard", ...
                ButtonPushedFcn=@(~, ~) app.safely("Copy failed", @app.copyToClipboard));

            % Right: output. The text area and HTML view share one cell and
            % only one is visible, depending on color mode.
            right = uigridlayout(uipanel(main, Title="ASCII output"), [2 1], ...
                RowHeight={"1x", "fit"});
            app.OutputTextArea = uitextarea(right, Editable="off", WordWrap="off", ...
                FontName="Courier New", FontSize=9);
            AsciiArtApp.place(app.OutputTextArea, 1, 1);
            app.OutputHTML = uihtml(right, Visible="off");
            AsciiArtApp.place(app.OutputHTML, 1, 1);
            app.StatusLabel = uilabel(right, Text="");
            AsciiArtApp.place(app.StatusLabel, 2, 1);
        end

        %% Callbacks
        function onWidthChanging(app, value)
            % While dragging the slider, its Value property still holds the
            % old value, so keep the live value in app.Width
            app.Width = round(value);
            app.WidthValueLabel.Text = string(app.Width);
            app.scheduleRender();
        end

        function onWidthChanged(app, value)
            app.Width = round(value);
            app.WidthSlider.Value = app.Width;   % snap to a whole number
            app.WidthValueLabel.Text = string(app.Width);
            app.scheduleRender();
        end

        function onCharsetChanged(app)
            app.CustomCharsetField.Enable = app.CharsetDropDown.Value == "custom";
            app.scheduleRender();
        end

        function scheduleRender(app)
            %SCHEDULERENDER Re-render after the controls stop changing.
            %   Each call restarts the timer, so a burst of slider events
            %   produces a single render.
            stop(app.DebounceTimer);
            start(app.DebounceTimer);
        end

        %% Rendering
        function render(app)
            if isempty(app.Image) || ~isvalid(app.UIFigure)
                return
            end
            args = namedargs2cell(app.currentOptions());
            [bg, fg] = app.outputColors();

            tic
            if app.ColorCheckBox.Value
                [app.Txt, app.Colors] = img2asciiColor(app.Image, args{:});
                app.OutputHTML.HTMLSource = app.previewHtml(bg);
                app.OutputHTML.Visible = "on";
                app.OutputTextArea.Visible = "off";
            else
                app.Txt = img2ascii(app.Image, args{:});
                app.Colors = [];
                app.OutputTextArea.Value = string(app.Txt);   % one string per row
                app.OutputTextArea.BackgroundColor = bg;
                app.OutputTextArea.FontColor = fg;
                app.OutputTextArea.Visible = "on";
                app.OutputHTML.Visible = "off";
            end
            app.StatusLabel.Text = sprintf("%d x %d characters, rendered in %.0f ms", ...
                size(app.Txt, 2), size(app.Txt, 1), 1000 * toc);
        end

        function html = previewHtml(app, bg)
            %PREVIEWHTML HTML for the color preview, via a temporary file.
            file = [tempname '.html'];
            cleanup = onCleanup(@() delete(file));
            ascii2html(app.Txt, app.Colors, file, BackgroundColor=bg, FontSize=8);
            html = fileread(file, Encoding="UTF-8");
        end

        function opts = currentOptions(app)
            opts.Width = app.Width;
            opts.Charset = app.currentCharset();
            opts.Invert = app.InvertCheckBox.Value;
        end

        function charset = currentCharset(app)
            switch app.CharsetDropDown.Value
                case "classic"
                    charset = " .:-=+*#%@";
                case "blocks"
                    charset = app.BlocksCharset;
                case "minimal"
                    charset = " .*#";
                case "custom"
                    charset = string(app.CustomCharsetField.Value);
                    if strlength(charset) == 0
                        error("Enter at least one character for the custom charset, " + ...
                            "ordered from lightest to darkest.");
                    end
            end
        end

        function [bg, fg] = outputColors(app)
            %OUTPUTCOLORS Background and text colors that match the Invert setting.
            if app.InvertCheckBox.Value
                bg = [0 0 0];
                fg = [0.9 0.9 0.9];
            else
                bg = [1 1 1];
                fg = [0 0 0];
            end
        end

        %% Image loading
        function loadSample(app)
            if ~isempty(which("peppers.png"))
                app.setImage(imread("peppers.png"), "peppers.png");
            else
                % Shaded sphere on a gradient, same as examples/demo_basic.m
                [x, y] = meshgrid(linspace(-1.6, 1.6, 320), linspace(-1.2, 1.2, 240));
                img = rescale(x, 0.1, 0.9);
                inside = x.^2 + y.^2 <= 1;
                z = sqrt(max(0, 1 - x.^2 - y.^2));
                light = [-1 -1 1.5] / norm([-1 -1 1.5]);
                shade = max(0, light(1)*x + light(2)*y + light(3)*z);
                img(inside) = 0.05 + 0.95 * shade(inside);
                app.setImage(img, "sample");
            end
        end

        function loadFromFile(app)
            [file, folder] = uigetfile( ...
                {'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff;*.gif', 'Images'}, "Load Image");
            figure(app.UIFigure);   % bring the app back to the front
            if isequal(file, 0)
                return   % canceled
            end
            [img, map] = imread(fullfile(folder, file));
            if ~isempty(map)
                img = ind2rgb(img, map);
            end
            app.setImage(img, string(file));
        end

        function onUploadEvent(app, event)
            %ONUPLOADEVENT Handle an image sent by uploadButton.html.
            data = event.HTMLEventData;
            switch event.HTMLEventName
                case "ImageUploaded"
                    % Resized uploads are PNG; otherwise the bytes are the
                    % original file, so keep its extension for imread
                    if data.resized
                        ext = ".png";
                    else
                        [~, ~, ext] = fileparts(string(data.name));
                    end
                    app.setImage(AsciiArtApp.decodeDataUrl(data.data, ext), string(data.name));
                case "UploadFailed"
                    error("The browser could not read the file ""%s"".", data.name);
            end
        end

        function setImage(app, img, name)
            % Output is at most 300 characters wide, so about 4 pixels per
            % character is plenty. Subsampling large photos keeps live
            % updates fast.
            step = ceil(max(size(img, [1 2])) / app.MaxWorkingSize);
            app.Image = img(1:step:end, 1:step:end, :);
            app.ImageName = name;

            shown = app.Image;
            if islogical(shown)
                shown = double(shown);
            end
            if size(shown, 3) == 1
                shown = repmat(shown, 1, 1, 3);   % show grayscale as gray, not a colormap
            end
            image(app.ImageAxes, shown);
            axis(app.ImageAxes, "image", "off");
            title(app.ImageAxes, name, Interpreter="none");

            app.render();
        end

        %% Export
        function exportTxt(app)
            file = app.askSaveFile(".txt");
            if file ~= ""
                ascii2txt(app.Txt, file);
                app.StatusLabel.Text = "Saved " + file;
            end
        end

        function exportPng(app)
            file = app.askSaveFile(".png");
            if file ~= ""
                [bg, fg] = app.outputColors();
                ascii2png(app.Txt, file, BackgroundColor=bg, TextColor=fg);
                app.StatusLabel.Text = "Saved " + file;
            end
        end

        function exportHtml(app)
            file = app.askSaveFile(".html");
            if file == ""
                return
            end
            % HTML is always in color, even if the preview is not
            txt = app.Txt;
            colors = app.Colors;
            if isempty(colors)
                args = namedargs2cell(app.currentOptions());
                [txt, colors] = img2asciiColor(app.Image, args{:});
            end
            bg = app.outputColors();
            ascii2html(txt, colors, file, BackgroundColor=bg, Title=app.ImageName);
            app.StatusLabel.Text = "Saved " + file;
        end

        function copyToClipboard(app)
            clipboard("copy", char(join(string(app.Txt), newline)));
            app.StatusLabel.Text = "Copied " + size(app.Txt, 1) + " lines to the clipboard";
        end

        function file = askSaveFile(app, ext)
            %ASKSAVEFILE Ask for an output file name. Returns "" if canceled.
            [~, base] = fileparts(app.ImageName);
            [name, folder] = uiputfile(char("*" + ext), "Export", char(base + "_ascii" + ext));
            figure(app.UIFigure);
            if isequal(name, 0)
                file = "";
            else
                file = string(fullfile(folder, name));
            end
        end

        %% Error handling
        function safely(app, title, fcn)
            %SAFELY Run FCN and show any error in an alert instead of the
            %   Command Window, so a bad file or setting never crashes the app.
            try
                fcn();
            catch err
                if isvalid(app) && isvalid(app.UIFigure)
                    uialert(app.UIFigure, err.message, title);
                else
                    rethrow(err);
                end
            end
        end
    end

    methods (Static, Access = private)
        function place(component, row, col)
            %PLACE Put a component in a grid layout cell (or span).
            component.Layout.Row = row;
            component.Layout.Column = col;
        end

        function img = decodeDataUrl(dataUrl, ext)
            %DECODEDATAURL Image array from a "data:<type>;base64,..." URL.
            %   IMREAD needs a file, so the decoded bytes go through a
            %   temporary file with extension EXT that is deleted afterwards.
            bytes = matlab.net.base64decode(extractAfter(string(dataUrl), ","));
            file = tempname + ext;
            cleanup = onCleanup(@() delete(file));
            fid = fopen(file, "w");
            fwrite(fid, bytes, "uint8");
            fclose(fid);
            try
                [img, map] = imread(file);
            catch
                error("Could not read the uploaded file as an image. " + ...
                    "Supported formats are PNG, JPEG, BMP, TIFF, and GIF.");
            end
            if ~isempty(map)
                img = ind2rgb(img, map);
            end
        end
    end
end