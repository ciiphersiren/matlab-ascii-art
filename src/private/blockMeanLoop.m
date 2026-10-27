function B = blockMeanLoop(A, nRows, nCols)
%BLOCKMEANLOOP Average a matrix over a grid of blocks using for-loops.
%   B = BLOCKMEANLOOP(A, NROWS, NCOLS) divides the matrix A into an
%   NROWS-by-NCOLS grid of blocks and returns the mean of each block. Block
%   boundaries are defined by BLOCKEDGES, so the size of A does not need to
%   be a multiple of the grid size.
%
%   This is the reference implementation: it visits every pixel of every
%   block with explicit loops. BLOCKMEANVECTORIZED gives the same result
%   much faster.
%
%   Example
%       B = blockMeanLoop(magic(6), 2, 3)
%
%   See also BLOCKMEANVECTORIZED, BLOCKEDGES.

arguments
    A (:,:) double
    nRows (1,1) double {mustBeInteger, mustBePositive}
    nCols (1,1) double {mustBeInteger, mustBePositive}
end

[r0, r1] = blockEdges(size(A, 1), nRows);
[c0, c1] = blockEdges(size(A, 2), nCols);

B = zeros(nRows, nCols);
for j = 1:nCols
    for i = 1:nRows
        s = 0;
        for c = c0(j)+1 : c1(j)
            for r = r0(i)+1 : r1(i)       % innermost loop runs down a column (memory order)
                s = s + A(r, c);
            end
        end
        B(i, j) = s / ((r1(i) - r0(i)) * (c1(j) - c0(j)));
    end
end
end