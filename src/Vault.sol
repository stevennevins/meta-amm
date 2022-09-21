// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";

import {ICurve} from "./interfaces/ICurve.sol";
import {TransferLib} from "./lib/TransferLib.sol";
import {Reserves, Asset, Pair} from "./lib/ReserveStructs.sol";

/// a minimalistic meta AMM
contract Vault is ERC1155, ERC1155TokenReceiver {
    using TransferLib for address;
    using TransferLib for Asset;

    Asset public NULL_ASSET = Asset(address(0), 0);

    function uri(uint256) public pure override returns (string memory) {
        return "";
    }

    mapping(uint256 => Reserves) public reserves; /// pairId => Reserves
    /// we should already have for fungibles with the amount of k
    /// mapping(address => mapping(uint256 => uint256)) public balance;

    /// I think the sauce will be allowing people to scope their own ids
    /// maybe let people deposit to a Reserve where the hash is based on the address
    /// they're giving controll over their ids ie either Jitty or themselves

    mapping(address => mapping(uint256 => uint256)) public enumeratedIds; /// token address => index => id held by Vault, balanceOf(address(this)) = current index
    mapping(address => mapping(address => mapping(uint256 => uint256))) public userEnumeratedIds; /// token address => index => id held by Vault, balanceOf(address(this)) = current index
    mapping(address => uint128) public currentIndex; /// for ERC1155B: token address => current Index

    function addLiquidity(
        address to,
        uint128 asset0Amount,
        uint128 asset1Amount,
        uint128 minK,
        Pair calldata pair
    ) external returns (uint128 k) {
        k = _addLiquidity(to, asset0Amount, asset1Amount, pair);

        require(k >= minK, "K < minK");
    }

    function addInternalBalance(
        address to,
        Asset calldata asset,
        uint128 amount
    ) external returns (uint128 k) {
        k = _addInternalBalance(to, asset, amount);
    }

    function removeInternalBalance(
        address to,
        Asset calldata asset,
        uint128 k
    ) external returns (uint128 amountOut) {
        amountOut = _removeInternalBalance(to, asset, k);
    }

    function removeLiquidity(
        address from,
        uint128 k,
        uint128 minAmount0Out,
        uint128 minAmount1Out,
        Pair calldata pair
    ) external returns (uint128 amount0Out, uint128 amount1Out) {
        (amount0Out, amount1Out) = _removeLiquidity(from, k, pair);

        require(amount0Out >= minAmount0Out, "amountOut < minAmountOut");
        require(amount1Out >= minAmount1Out, "amountOut < minAmountOut");
    }

    function swap(
        address to,
        Asset calldata assetIn,
        uint128 amountIn,
        uint128 minAmountOut,
        Pair calldata pair
    ) external returns (Asset memory assetOut, uint128 amountOut) {
        (assetOut, amountOut) = _swap(to, assetIn, amountIn, pair);

        require(amountOut >= minAmountOut, "amountOut < minAmountOut");
    }

    function _addLiquidity(
        address to,
        uint128 asset0Amount,
        uint128 asset1Amount,
        Pair calldata pair
    ) internal returns (uint128 k) {
        uint256 pairId = uint256(keccak256(abi.encode(pair)));
        Reserves storage reserves = reserves[pairId];

        require(pair.asset0.token < pair.asset1.token, "asset0 > asset1");

        k = ICurve(pair.invariant).addLiquidity(reserves, asset0Amount, asset1Amount);
        reserves.reserve0 += asset0Amount;
        reserves.reserve1 += asset1Amount;

        pair.asset0._ERC1155Transfer(to, address(this), asset0Amount);
        pair.asset1._ERC1155Transfer(to, address(this), asset1Amount);

        _mint(to, pairId, k, "");
    }

    function _removeLiquidity(
        address from,
        uint128 k,
        Pair calldata pair
    ) internal returns (uint128 amount0Out, uint128 amount1Out) {
        uint256 pairId = uint256(keccak256(abi.encode(pair)));
        Reserves storage reserves = reserves[pairId];

        require(pair.asset0.token < pair.asset1.token, "asset0 > asset1");
        require(pair.invariant.code.length != 0, "amm must be a contract");
        (amount0Out, amount1Out) = ICurve(pair.invariant).removeLiquidity(reserves, k);
        reserves.reserve0 -= amount0Out;
        reserves.reserve1 -= amount1Out;

        _burn(from, pairId, k);
        pair.asset0._ERC1155Transfer(address(this), from, amount0Out);
        pair.asset1._ERC1155Transfer(address(this), from, amount1Out);
    }

    function _addInternalBalance(
        address from,
        Asset calldata asset,
        uint128 amount
    ) internal returns (uint128 k) {
        uint256 pairId = uint256(keccak256(abi.encode(Pair(asset, NULL_ASSET, address(0)))));
        k = amount;
        asset._ERC20TransferFrom(from, address(this), amount);
        _mint(from, pairId, amount, "");
    }

    function _removeInternalBalance(
        address from,
        Asset calldata asset,
        uint128 k
    ) internal returns (uint128 amountOut) {
        uint256 pairId = uint256(keccak256(abi.encode(Pair(asset, NULL_ASSET, address(0)))));
        amountOut = k;
        asset._ERC20Transfer(from, k);
        _burn(from, pairId, k);
    }

    function _swap(
        address to,
        Asset calldata assetIn,
        uint128 amountIn,
        Pair calldata pair
    ) internal returns (Asset memory assetOut, uint128 amountOut) {
        uint256 pairId = uint256(keccak256(abi.encode(pair)));
        Reserves storage reserves = reserves[pairId];
        require(pair.asset0.token < pair.asset1.token, "asset0 > asset1");
        require(
            assetIn.token == pair.asset0.token || assetIn.token == pair.asset1.token,
            "invalid token"
        );

        require(pair.invariant.code.length != 0, "amm must be a contract");
        (assetOut, amountOut) = (assetIn.token == pair.asset0.token)
            ? (
                pair.asset1,
                ICurve(pair.invariant).swap(reserves.reserve0, reserves.reserve1, amountIn)
            )
            : (
                pair.asset0,
                ICurve(pair.invariant).swap(reserves.reserve1, reserves.reserve0, amountIn)
            );

        /// #TODO
        /// missing reserve update for asset1
        (pair.asset0.token == assetIn.token)
            ? reserves.reserve0 += amountIn
            : reserves.reserve0 -= amountOut;

        assetIn.token._ERC1155Transfer(to, address(this), assetIn.identifier, amountIn);
        assetOut.token._ERC1155Transfer(address(this), to, assetOut.identifier, amountOut);
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
