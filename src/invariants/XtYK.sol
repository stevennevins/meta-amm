// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ICurve, Reserves} from "../interfaces/ICurve.sol";
import "forge-std/Test.sol";

contract XtYK is ICurve {
    uint128 public constant MIN_LP = 10**3;

    function addLiquidity(
        Reserves memory reserves,
        uint128 token0Amount,
        uint128 token1Amount
    ) external pure returns (uint128 k) {
        uint128 reserve0 = reserves.reserve0;
        uint128 reserve1 = reserves.reserve1;

        uint128 totalK = reserve0 * reserve1;

        if (totalK == 0) {
            k = token0Amount * token1Amount - MIN_LP;
        } else {
            k = _min((token0Amount * totalK) / reserve0, (token1Amount * totalK) / reserve1);
        }

        require(k != 0, "insufficient K");
    }

    function removeLiquidity(Reserves memory reserves, uint128 k)
        external
        pure
        returns (uint128 amount0Out, uint128 amount1Out)
    {
        uint128 reserve0 = reserves.reserve0;
        uint128 reserve1 = reserves.reserve1;

        uint128 totalK = reserve0 * reserve1;

        amount0Out = (k * reserve0) / totalK;
        amount1Out = (k * reserve1) / totalK;

        require(amount0Out != 0 && amount1Out != 0, "insufficient K");
    }

    function swap(
        uint128 reserveIn,
        uint128 reserveOut,
        uint128 amountIn
    ) external pure returns (uint128 amountOut) {
        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function _getAmountOut(
        uint128 amountIn,
        uint128 reserveAmountIn,
        uint128 reserveAmountOut
    ) internal pure returns (uint128 amountOut) {
        amountOut = (amountIn * reserveAmountOut) / reserveAmountIn;
    }

    function _min(uint128 x, uint128 y) private pure returns (uint128 z) {
        z = x < y ? x : y;
    }
}
