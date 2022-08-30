// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

struct Pair {
    uint96 reserve0; // first pair token reserve
    uint96 reserve1; // second pair token reserve
}

interface ICurve {
    function addLiquidity(
        Pair memory pair,
        uint96 token0Amount,
        uint96 token1Amount
    ) external returns (uint96);

    function removeLiquidity(Pair memory pair, uint96 k)
        external
        returns (uint96 amount0Out, uint96 amount1Out);

    function swap(Pair memory pairIn, uint96 amountIn) external returns (uint96 amountOut);
}
