function ascii2txt(txt, filename)
%ASCII2TXT Save ASCII art to a text file.
%   ASCII2TXT(TXT, FILENAME) writes the character matrix TXT to the text
%   file FILENAME, one matrix row per line. The file is UTF-8 encoded, so
%   Unicode charsets such as "░▒▓█" are preserved. Lines end with a
%   newline character (LF), and trailing spaces are kept so every line has
%   the same length. An existing file is overwritten.
%
%   Example
%       txt = img2ascii("peppers.png", Width=80);
%       ascii2txt(txt, "peppers.txt");
%       type peppers.txt
%
%   See also IMG2ASCII, ASCII2PNG, ASCII2HTML.

arguments
    txt (:,:) char
    filename (1,1) string {mustBeNonzeroLengthText}
end

[fid, msg] = fopen(filename, "w", "n", "UTF-8");
if fid < 0
    error("asciiart:io:cannotOpenFile", "Cannot open ""%s"" for writing: %s", filename, msg);
end
closeFile = onCleanup(@() fclose(fid));

% Append a newline to each row and write everything in one call. TXT is
% passed as data, not as the format, so characters like % and \ are safe.
lines = [txt, repmat(newline, size(txt, 1), 1)].';
fprintf(fid, "%s", lines(:).');
end
