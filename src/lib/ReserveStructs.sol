// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

struct Token {
    address token;
    uint256 identifier;
}

struct Pair {
    Token reserve0;
    Token reserve1;
    address invariant;
}

struct Reserves {
    uint128 reserve0;
    uint128 reserve1;
}
