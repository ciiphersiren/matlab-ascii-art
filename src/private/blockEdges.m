function [lo, hi] = blockEdges(n, nOut)
%BLOCKEDGES Pixel ranges covered by each output block along one dimension.
%   [LO, HI] = BLOCKEDGES(N, NOUT) splits N pixels into NOUT blocks. Block
%   k covers pixels LO(k)+1 through HI(k). LO and HI are NOUT-by-1 column
%   vectors.
%
%   Block k ideally spans [k-1, k] * N/NOUT. LO rounds that start down and
%   HI rounds the end up, so a pixel that straddles a boundary belongs to
%   both neighboring blocks. When N is a multiple of NOUT the blocks are
%   exact and do not overlap. Every block contains at least one pixel, even
%   when NOUT > N.
%
%   Example
%       [lo, hi] = blockEdges(10, 4)   % lo = [0 2 5 7]', hi = [3 5 8 10]'

k = (1:nOut).';
lo = floor((k - 1) * n / nOut);
hi = ceil(k * n / nOut);
end