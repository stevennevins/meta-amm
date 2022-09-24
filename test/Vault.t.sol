// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {MockERC1155} from "./mocks/MockERC1155.sol";
import {MockERC721} from "./mocks/MockERC721.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "../src/Vault.sol";
import {XtYK} from "../src/invariants/XtYK.sol";

contract VaultTest is Test {
    Vault public vault;
    XtYK public xyk;
    MockERC1155 public token0;
    MockERC1155 public token1;
    MockERC721 public nft;
    uint256 public computedPairId;

    function setUp() public {
        vault = new Vault();
        xyk = new XtYK();
        token0 = new MockERC1155();
        token1 = new MockERC1155();
        nft = new MockERC721("", "");
        nft.mint(address(0xBEEF), 1);
        nft.mint(address(0xBEEF), 2);
        token0.mint(address(0xBEEF), 1, type(uint128).max);
        token1.mint(address(0xBEEF), 1, type(uint128).max);
        vm.startPrank(address(0xBEEF));
        token0.setApprovalForAll(address(vault), true);
        token1.setApprovalForAll(address(vault), true);
        vm.stopPrank();
    }

    function testCreatePair() public {
        assertTrue(address(token0) < address(token1));

        computedPairId = uint256(
            keccak256(
                abi.encode(Pair(Asset(address(token0), 1), Asset(address(token1), 1), address(xyk)))
            )
        );
    }

    function testAddLiquidity() public {
        testCreatePair();

        Pair memory pair = Pair(Asset(address(token0), 1), Asset(address(token1), 1), address(xyk));

        vm.prank(address(0xBEEF));
        vault.addLiquidity(address(0xBEEF), 1 gwei, 1 gwei, pair);
        assertEq(token0.balanceOf(address(vault), 1), 1 gwei);
        assertEq(token1.balanceOf(address(vault), 1), 1 gwei);
    }

    function testSwap() public {
        testAddLiquidity();

        Pair memory pair = Pair(Asset(address(token0), 1), Asset(address(token1), 1), address(xyk));

        vm.prank(address(0xBEEF));
        vault.swap(address(0xBEEF), Asset(address(token0), 1), 0.5 gwei, pair);
    }

    function testRemoveLiquidity() public {
        testAddLiquidity();
        Pair memory pair = Pair(Asset(address(token0), 1), Asset(address(token1), 1), address(xyk));

        vm.prank(address(0xBEEF));
        vault.removeLiquidity(address(0xBEEF), 1 gwei * 1 gwei - 1000, pair);
    }
}
