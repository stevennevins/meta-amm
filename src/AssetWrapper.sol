// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

import {TransferLib} from "./lib/TransferLib.sol";
import {Asset, Pair} from "./lib/ReserveStructs.sol";

contract AssetWrapper {
    using TransferLib for Asset;
    using TransferLib for address;

    Asset public NULL_ASSET = Asset(address(0), 0);

    mapping(address => mapping(address => mapping(uint256 => uint256))) public enumeratedIds; /// owner => token address => index => id
    mapping(address => mapping(address => uint256)) public currentIndex; /// owner => token address => current Index

    function wrapERC20(
        address to,
        Asset calldata asset,
        uint128 amount
    ) external returns (uint256 pairId) {
        pairId = uint256(keccak256(abi.encode(Pair(asset, NULL_ASSET, address(0)))));
        _wrapERC20(to, asset, amount);
        _afterWrap(to, pairId, amount);
    }

    function unwrapERC20(
        address to,
        Asset calldata asset,
        uint128 k
    ) external returns (uint256 pairId) {
        pairId = uint256(keccak256(abi.encode(Pair(asset, NULL_ASSET, address(0)))));
        _unwrapERC20(to, asset, k);
        _afterWrap(to, pairId, k);
    }

    function wrapERC721(
        address from,
        Asset calldata asset,
        uint256[] calldata ids
    ) external returns (uint256 pairId) {
        pairId = uint256(keccak256(abi.encode(Pair(asset, NULL_ASSET, address(0)))));
        _wrapERC721(from, asset, ids);
        _afterWrap(from, pairId, ids.length);
    }

    function unwrapERC721(
        address to,
        uint128 k,
        Asset calldata asset
    ) external returns (uint256 pairId) {
        pairId = uint256(keccak256(abi.encode(Pair(asset, NULL_ASSET, address(0)))));
        _unwrapERC721(to, k, asset);
        _afterWrap(to, pairId, k);
    }

    function _wrapERC721(
        address from,
        Asset calldata asset,
        uint256[] calldata ids
    ) internal {
        require(asset.identifier == 0, "AssetWrapper: invalid identifier");
        uint256 id;
        uint256 amount = ids.length;
        uint256 totalIds = currentIndex[address(this)][asset.token];
        currentIndex[address(this)][asset.token] = totalIds + amount;
        for (uint256 i; i < amount; i++) {
            (id = ids[i], enumeratedIds[address(this)][asset.token][totalIds++] = id);
            IERC721(asset.token).transferFrom(from, address(this), id);
        }
    }

    function _unwrapERC721(
        address to,
        uint128 k,
        Asset calldata asset
    ) internal {
        uint256 upper = currentIndex[address(this)][asset.token];
        uint256 lower = upper - k;
        currentIndex[address(this)][asset.token] = lower;
        for (; lower < upper; lower++) IERC721(asset.token).transferFrom(address(this), to, lower);
    }

    function _wrapERC20(
        address from,
        Asset calldata asset,
        uint128 amount
    ) internal {
        require(asset.identifier == 0, "AssetWrapper: invalid identifier");
        IERC20(asset.token).transferFrom(from, address(this), amount);
    }

    function _unwrapERC20(
        address to,
        Asset calldata asset,
        uint128 k
    ) internal {
        IERC20(asset.token).transfer(to, k);
    }

    function _afterWrap(
        address to,
        uint256 id,
        uint256 amount
    ) internal virtual {}

    function _afterUnwrap(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {}
}
