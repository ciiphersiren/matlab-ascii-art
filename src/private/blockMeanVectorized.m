function B = blockMeanVectorized(A, nRows, nCols)
%BLOCKMEANVECTORIZED Average a matrix over a grid of blocks without loops.
%   B = BLOCKMEANVECTORIZED(A, NROWS, NCOLS) divides the matrix A into an
%   NROWS-by-NCOLS grid of blocks and returns the mean of each block. Block
%   boundaries are defined by BLOCKEDGES, so the size of A does not need to
%   be a multiple of the grid size.
%
%   The sums are computed separably with cumulative sums. With
%   C = CUMSUM(A, 1), the sum of rows r0+1 through r1 is C(r1,:) - C(r0,:),
%   so indexing C with the vectors of block edges reduces A to an
%   NROWS-by-N matrix in one pass. The same step along dimension 2 then
%   runs on that much smaller matrix. Only one pass touches every element
%   of A, and blocks may have unequal sizes, which a RESHAPE-based
%   approach cannot handle.
%
%   Example
%       B = blockMeanVectorized(magic(6), 2, 3)
%
%   See also BLOCKMEANLOOP, BLOCKEDGES, CUMSUM.

arguments
    A (:,:) double
    nRows (1,1) double {mustBeInteger, mustBePositive}
    nCols (1,1) double {mustBeInteger, mustBePositive}
end

[r0, r1] = blockEdges(size(A, 1), nRows);
[c0, c1] = blockEdges(size(A, 2), nCols);

% Edge index 0 means "before the first element", whose cumulative sum is
% 0. Index with max(edge, 1) and zero those rows/columns with a mask.
C = cumsum(A, 1);
rowSums = C(r1, :) - C(max(r0, 1), :) .* (r0 > 0);

C = cumsum(rowSums, 2);
sums = C(:, c1) - C(:, max(c0, 1)) .* (c0 > 0).';

B = sums ./ ((r1 - r0) .* (c1 - c0).');   % block areas via implicit expansion
end