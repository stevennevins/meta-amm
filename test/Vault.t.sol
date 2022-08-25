// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "../src/Vault.sol";
import "../src/invariants/XtYK.sol";

contract JittyERC20Test is Test {
    Vault public vault;
    XtYK public xyk;
    MockERC20 public token0;
    MockERC20 public token1;
    uint256 computedPairId;

    function setUp() public {
        vault = new Vault();
        xyk = new XtYK();
        token0 = new MockERC20("", "", 18);
        token1 = new MockERC20("", "", 18);
        token0.mint(address(0xBEEF), type(uint96).max);
        token1.mint(address(0xBEEF), type(uint96).max);
        vm.startPrank(address(0xBEEF));
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function testCreatePairERC20() public {
        assertTrue(address(token0) < address(token1));

        uint256 pairId = vault.createPair(address(token0), 0, address(token1), 0, xyk);
        computedPairId = uint256(
            keccak256(abi.encode(address(token0), 0, address(token1), 0, address(xyk)))
        );

        assertTrue(pairId == computedPairId);
    }

    function testAddLiquidityERC20() public {
        testCreatePairERC20();

        vault.addLiquidity(address(0xBEEF), computedPairId, 1 gwei, 1 gwei, 1, "");
        assertEq(token0.balanceOf(address(vault)), 1 gwei);
        assertEq(token1.balanceOf(address(vault)), 1 gwei);
    }

    function testSwapERC20() public {
        testAddLiquidityERC20();
        vault.swap(address(0xBEEF), computedPairId, address(token0), 0.0001 gwei, 1, "");
    }

    function testRemoveLiquidityERC20() public {
        testAddLiquidityERC20();
        vault.removeLiquidity(address(0xBEEF), computedPairId, 1 gwei << 1, 1, 1);
    }
}
