// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ICurve, Reserves} from "../interfaces/ICurve.sol";
import "forge-std/Test.sol";

contract XtYK is ICurve {
    uint128 public constant MIN_LP = 10**3;

    function addLiquidity(
        Reserves calldata reserves,
        uint128 amount0,
        uint128 amount1
    ) external pure returns (uint128) {
        (uint128 reserve0, uint128 reserve1) = (reserves.reserve0, reserves.reserve1);
        uint128 totalK = reserve0 * reserve1;

        if (totalK > 0) return _min((amount0 * totalK) / reserve0, (amount1 * totalK) / reserve1);
        uint128 k = amount0 * amount1;
        require(k > MIN_LP, "k too low");

        return k;
    }

    function removeLiquidity(Reserves calldata reserves, uint128 k)
        external
        pure
        returns (uint128, uint128)
    {
        (uint128 reserve0, uint128 reserve1) = (reserves.reserve0, reserves.reserve1);
        uint128 totalK = reserve0 * reserve1;
        return ((k * reserve0) / totalK, (k * reserve1) / totalK);
    }

    function swap(
        uint128 reserveIn,
        uint128 reserveOut,
        uint128 amountIn
    ) external pure returns (uint128) {
        return _getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function _getAmountOut(
        uint128 amountIn,
        uint128 reserveAmountIn,
        uint128 reserveAmountOut
    ) internal pure returns (uint128) {
        return (amountIn * reserveAmountOut) / reserveAmountIn;
    }

    function _min(uint128 x, uint128 y) private pure returns (uint128 z) {
        z = x < y ? x : y;
    }
}
