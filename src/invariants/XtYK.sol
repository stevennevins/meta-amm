// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ICurve, Pair} from "../interfaces/ICurve.sol";

contract XYK is ICurve {
    uint96 public constant MIN_LP = 10**3;

    function addLiquidity(
        Pair memory pair,
        uint96 token0Amount,
        uint96 token1Amount
    ) external pure returns (uint96 k) {
        uint96 reserve0 = pair.reserve0;
        uint96 reserve1 = pair.reserve1;

        uint96 totalK = reserve0 * reserve1;

        if (totalK == 0) {
            k = token0Amount * token1Amount - MIN_LP;
        } else {
            k = _min((token0Amount * totalK) / reserve0, (token1Amount * totalK) / reserve1);
        }

        require(k != 0, "insufficient K");
    }

    function removeLiquidity(Pair memory pair, uint96 k)
        external
        pure
        returns (uint96 amount0Out, uint96 amount1Out)
    {
        uint96 reserve0 = pair.reserve0;
        uint96 reserve1 = pair.reserve1;

        uint96 totalK = reserve0 * reserve1;

        amount0Out = (k * reserve0) / totalK;
        amount1Out = (k * reserve1) / totalK;

        require(amount0Out != 0 && amount1Out != 0, "insufficient K");
    }

    function swap(
        Pair memory pair,
        address tokenIn,
        uint96 amountIn
    ) external pure returns (uint96 amountOut) {
        uint96 reserve0 = pair.reserve0;
        uint96 reserve1 = pair.reserve1;

        if (tokenIn == pair.token0) {
            amountOut = _getAmountOut(amountIn, reserve0, reserve1);
        } else {
            require(tokenIn == pair.token1, "invalid input token");
            amountOut = _getAmountOut(amountIn, reserve1, reserve0);
        }
    }

    function _getAmountOut(
        uint96 amountIn,
        uint96 reserveAmountIn,
        uint96 reserveAmountOut
    ) internal pure returns (uint96 amountOut) {
        amountOut = (amountIn * reserveAmountOut) / reserveAmountIn;
    }

    function _min(uint96 x, uint96 y) private pure returns (uint96 z) {
        z = x < y ? x : y;
    }
}
