// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract JittyTest is Test {
    Vault public vault;

    function setUp() public {
        vault = new Vault();
    }

    function testPass() public {
        assertTrue(true);
    }
}
