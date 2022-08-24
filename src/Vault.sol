// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {ICurve, Pair} from "./interfaces/ICurve.sol";
import {TransferLib} from "./lib/TransferLib.sol";

/// a minimalistic meta AMM
contract Vault is ERC1155 {
    /// metadata stuff for 1155
    string public constant name = "";
    string public constant symbol = "";

    function uri(uint256) public pure override returns (string memory) {
        return "";
    }

    mapping(uint256 => Pair) public pairs; /// pairId => Pair

    function createPair(
        address token0,
        uint256 token0Id,
        address token1,
        uint256 token1Id,
        ICurve invariant
    ) external returns (uint256 pairId) {
        if (token0 >= token1) {
            require(token0 != token1, "token0 and token1 must be different");
            /// sort tokens to prevent duplicates
            (token1, token1Id, token0, token0Id) = (token0, token0Id, token1, token1Id);
        }

        pairId = uint256(keccak256(abi.encode(token0, token0Id, token1, token1Id, invariant)));

        require(address(invariant).code.length != 0, "amm must be a contract");
        require(address(pairs[pairId].invariant) == address(0), "pair already exists");

        pairs[pairId] = Pair(token0, 0, token0Id, token1, 0, token1Id, invariant);
    }

    function addLiquidity(
        address to,
        uint256 pairId,
        uint96 token0Amount,
        uint96 token1Amount,
        uint96 minK,
        bytes calldata
    ) external returns (uint96 k) {
        Pair storage pair = pairs[pairId];

        k = pair.invariant.addLiquidity(pair, token0Amount, token1Amount);
        pair.reserve0 += token0Amount;
        pair.reserve1 += token1Amount;

        _mint(to, pairId, k, "");
        TransferLib.transfer(pair, pair.token0, to, address(this), token0Amount, "");
        TransferLib.transfer(pair, pair.token1, to, address(this), token1Amount, "");

        require(k >= minK, "liquidity must be greater than minK liquidity");
    }

    function removeLiquidity(
        address from,
        uint256 pairId,
        uint96 k,
        uint96 minAmount0Out,
        uint96 minAmount1Out
    ) external returns (uint96 amount0Out, uint96 amount1Out) {
        Pair storage pair = pairs[pairId];

        (amount0Out, amount1Out) = pair.invariant.removeLiquidity(pair, k);
        pair.reserve0 -= amount0Out;
        pair.reserve1 -= amount1Out;

        _burn(from, pairId, k);
        TransferLib.transfer(pair, pair.token0, address(this), from, amount0Out, "");
        TransferLib.transfer(pair, pair.token1, address(this), from, amount1Out, "");

        require(amount0Out >= minAmount0Out, "amountOut must be greater than minAmountOut");
        require(amount1Out >= minAmount1Out, "amountOut must be greater than minAmountOut");
    }

    function swap(
        address to,
        uint256 pairId,
        address tokenIn,
        uint256 tokenInId,
        uint96 amountIn,
        uint256 minAmountOut,
        bytes calldata
    ) external returns (uint96 amountOut) {
        Pair storage pair = pairs[pairId];

        amountOut = pair.invariant.swap(pair, tokenIn, amountIn);
        (pair.token0 == tokenIn) ? pair.reserve0 += amountIn : pair.reserve1 += amountIn;
        (pair.token0 == tokenIn) ? pair.reserve1 -= amountOut : pair.reserve0 -= amountOut;

        TransferLib.transfer(pair, tokenIn, to, address(this), amountIn, "");
        TransferLib.transfer(pair, tokenIn, address(this), to, amountOut, "");

        require(amountOut >= minAmountOut, "amountOut must be greater than minAmountOut");
    }
}
