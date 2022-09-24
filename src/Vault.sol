// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";

import {AssetWrapper} from "./AssetWrapper.sol";

import {ICurve} from "./interfaces/ICurve.sol";
import {TransferLib} from "./lib/TransferLib.sol";
import {Reserves, Asset, Pair} from "./lib/ReserveStructs.sol";

/// a minimalistic meta AMM
contract Vault is AssetWrapper, ERC1155, ERC1155TokenReceiver {
    using TransferLib for Asset;

    function uri(uint256) public pure override returns (string memory) {
        return "";
    }

    mapping(uint256 => Reserves) public pairReserves; /// pairId => Reserves

    function addLiquidity(
        address to,
        uint128 asset0Amount,
        uint128 asset1Amount,
        Pair calldata pair
    ) external returns (uint128) {
        return _addLiquidity(to, asset0Amount, asset1Amount, pair);
    }

    function removeLiquidity(
        address from,
        uint128 k,
        Pair calldata pair
    ) external returns (uint128, uint128) {
        return _removeLiquidity(from, k, pair);
    }

    function swap(
        address to,
        Asset calldata assetIn,
        uint128 amountIn,
        Pair calldata pair
    ) external returns (Asset memory, uint128) {
        return _swap(to, assetIn, amountIn, pair);
    }

    function _addLiquidity(
        address to,
        uint128 asset0Amount,
        uint128 asset1Amount,
        Pair calldata pair
    ) internal returns (uint128 k) {
        uint256 pairId = uint256(keccak256(abi.encode(pair)));
        Reserves storage reserves = pairReserves[pairId];

        require(pair.asset0.token < pair.asset1.token, "asset0 > asset1");

        k = ICurve(pair.invariant).addLiquidity(reserves, asset0Amount, asset1Amount);
        reserves.reserve0 += asset0Amount;
        reserves.reserve1 += asset1Amount;

        pair.asset0._transferERC1155(to, address(this), asset0Amount);
        pair.asset1._transferERC1155(to, address(this), asset1Amount);

        _mint(to, pairId, k, "");
    }

    function _removeLiquidity(
        address from,
        uint128 k,
        Pair calldata pair
    ) internal returns (uint128 amount0Out, uint128 amount1Out) {
        uint256 pairId = uint256(keccak256(abi.encode(pair)));
        Reserves storage reserves = pairReserves[pairId];

        require(pair.asset0.token < pair.asset1.token, "asset0 > asset1");
        (amount0Out, amount1Out) = ICurve(pair.invariant).removeLiquidity(reserves, k);
        reserves.reserve0 -= amount0Out;
        reserves.reserve1 -= amount1Out;

        _burn(from, pairId, k);
        pair.asset0._transferERC1155(address(this), from, amount0Out);
        pair.asset1._transferERC1155(address(this), from, amount1Out);
    }

    function _swap(
        address to,
        Asset calldata assetIn,
        uint128 amountIn,
        Pair calldata pair
    ) internal returns (Asset memory assetOut, uint128 amountOut) {
        uint256 pairId = uint256(keccak256(abi.encode(pair)));
        Reserves storage reserves = pairReserves[pairId];
        if (assetIn.token == pair.asset0.token) {
            amountOut = ICurve(pair.invariant).swap(reserves.reserve0, reserves.reserve1, amountIn);
            (reserves.reserve0 += amountIn, reserves.reserve1 -= amountOut, assetOut = pair.asset1);
        } else if (assetIn.token == pair.asset1.token) {
            amountOut = ICurve(pair.invariant).swap(reserves.reserve1, reserves.reserve0, amountIn);
            (reserves.reserve0 -= amountOut, reserves.reserve1 += amountIn, assetOut = pair.asset0);
        }
        assetIn._transferERC1155(to, address(this), amountIn);
        assetOut._transferERC1155(address(this), to, amountOut);
    }

    function _afterWrap(
        address to,
        uint256 id,
        uint256 amount
    ) internal override {
        _mint(to, id, amount, "");
    }

    function _afterUnwrap(
        address from,
        uint256 id,
        uint256 amount
    ) internal override {
        _burn(from, id, amount);
    }

    /// @notice Handles the receipt of a single ERC1155 token type
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual override returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    /// @notice Handles the receipt of multiple ERC1155 token types
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual override returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}
