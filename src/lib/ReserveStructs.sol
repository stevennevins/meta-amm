// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

struct Pair {
    address token0;
    address token1;
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
