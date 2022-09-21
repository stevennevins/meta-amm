// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

struct Asset {
    address token;
    uint256 identifier;
}

struct Pair {
    Asset asset0;
    Asset asset1;
    address invariant;
}

struct Reserves {
    uint128 reserve0;
    uint128 reserve1;
}

struct PairInfo {
    Pair pair;
    Reserves reserves;
}

struct AssetInfo {
    Asset asset;
    uint128 reserve;
}
