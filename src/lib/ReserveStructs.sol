// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

struct Reserve {
    address token;
    uint256 identifier;
}

struct Pair {
    uint128 reserve0;
    uint128 reserve1;
}
