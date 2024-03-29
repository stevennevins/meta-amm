// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "../src/MetaAMM.sol";
import {XtYK} from "../src/invariants/XtYK.sol";

contract MetaAMMTest is Test {
    MetaAMM public amm;
    XtYK public xyk;
    MockERC20 public token0;
    MockERC20 public token1;
    uint256 public computedPairId;

    function setUp() public {
        amm = new MetaAMM();
        xyk = new XtYK();
        token0 = new MockERC20("", "", 18);
        token1 = new MockERC20("", "", 18);
        if (address(token0) > address(token1)) (token0, token1) = (token1, token0);
        token0.mint(address(0xBEEF), type(uint128).max);
        token1.mint(address(0xBEEF), type(uint128).max);
        vm.startPrank(address(0xBEEF));
        token0.approve(address(amm), type(uint256).max);
        token1.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }

    function testCreatePair() public {
        assertTrue(address(token0) < address(token1));

        computedPairId = uint256(
            keccak256(abi.encode(Pair(address(token0), address(token1), address(xyk))))
        );
    }

    function testAddLiquidity() public {
        testCreatePair();

        Pair memory pair = Pair(address(token0), address(token1), address(xyk));

        vm.prank(address(0xBEEF));
        amm.addLiquidity(address(0xBEEF), 1 gwei, 1 gwei, pair);
        assertEq(token0.balanceOf(address(amm)), 1 gwei);
        assertEq(token1.balanceOf(address(amm)), 1 gwei);
    }

    function testSwap() public {
        testAddLiquidity();

        Pair memory pair = Pair(address(token0), address(token1), address(xyk));

        vm.prank(address(0xBEEF));
        amm.swap(address(0xBEEF), address(token0), 0.5 gwei, pair);
    }

    function testRemoveLiquidity() public {
        testAddLiquidity();
        Pair memory pair = Pair(address(token0), address(token1), address(xyk));

        vm.prank(address(0xBEEF));
        amm.removeLiquidity(address(0xBEEF), 1 gwei * 1 gwei - 1000, pair);
    }
}
