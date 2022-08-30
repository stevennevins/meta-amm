// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

struct Pair {
    uint128 reserve0; // first pair token reserve
    uint128 reserve1; // second pair token reserve
}

interface ICurve {
    function addLiquidity(
        Pair memory pair,
        uint128 token0Amount,
        uint128 token1Amount
    ) external returns (uint128);

    function removeLiquidity(Pair memory pair, uint128 k)
        external
        returns (uint128 amount0Out, uint128 amount1Out);

    function swap(
        uint128 reserveIn,
        uint128 reserveOut,
        uint128 amountIn
    ) external returns (uint128 amountOut);
}
