// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {MockERC1155B, ERC1155B} from "./mocks/MockERC1155B.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "../src/Vault.sol";
import "../src/invariants/XtYK.sol";

contract VaultERC1155BTest is Test {
    bytes4 public constant ERC20_INTERFACE_ID = type(IERC20).interfaceId;
    bytes4 public constant ERC1155B_INTERFACE_ID = type(ERC1155B).interfaceId;

    Vault public vault;
    XtYK public xyk;
    MockERC1155B public token0;
    MockERC20 public token1;
    uint256 computedPairId;

    function setUp() public {
        vault = new Vault();
        xyk = new XtYK();
        token0 = new MockERC1155B();
        token1 = new MockERC20("", "", 18);
        for (uint256 i; i < 101; i++) token0.mint(address(0xBEEF), i);
        token1.mint(address(0xBEEF), type(uint128).max);
        vm.startPrank(address(0xBEEF));
        token0.setApprovalForAll(address(vault), true);
        token1.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function testCreatePairERC20ERC1155B() public {
        assertTrue(address(token0) < address(token1));

        uint256 pairId = vault.createPair(
            address(token0),
            0,
            ERC1155B_INTERFACE_ID,
            address(token1),
            0,
            ERC20_INTERFACE_ID,
            xyk
        );
        computedPairId = uint256(
            keccak256(
                abi.encode(
                    address(token0),
                    0,
                    ERC1155B_INTERFACE_ID,
                    address(token1),
                    0,
                    ERC20_INTERFACE_ID,
                    address(xyk)
                )
            )
        );

        assertTrue(pairId == computedPairId);
    }

    function testAddLiquidityERC20ERC1155B() public {
        testCreatePairERC20ERC1155B();
        bytes memory pairData = abi.encode(
            address(token0),
            0,
            ERC1155B_INTERFACE_ID,
            address(token1),
            0,
            ERC20_INTERFACE_ID,
            address(xyk)
        );

        uint256[] memory ids = new uint256[](100);
        for (uint256 i; i < 100; i++) ids[i] = i;

        bytes memory _transferData = abi.encode(ids, "");
        bytes memory data = abi.encode(_transferData, "");

        vm.prank(address(0xBEEF));
        vault.addLiquidity(address(0xBEEF), 100, 1 gwei, 0, pairData, data);
        // assertEq(token0.balanceOf(address(vault)), 100);
        assertEq(token1.balanceOf(address(vault)), 1 gwei);
    }

    function testSwapERC20toERC1155B() public {
        testAddLiquidityERC20ERC1155B();

        bytes memory pairData = abi.encode(
            address(token0),
            0,
            ERC1155B_INTERFACE_ID,
            address(token1),
            0,
            ERC20_INTERFACE_ID,
            address(xyk)
        );

        vm.prank(address(0xBEEF));
        vault.swap(address(0xBEEF), address(token1), 0.5 gwei, 1, pairData, "");
    }

    function testSwapERC1155BtoERC20() public {
        testAddLiquidityERC20ERC1155B();
        bytes memory pairData = abi.encode(
            address(token0),
            0,
            ERC1155B_INTERFACE_ID,
            address(token1),
            0,
            ERC20_INTERFACE_ID,
            address(xyk)
        );

        uint256[] memory ids = new uint256[](1);
        ids[0] = 100;
        bytes memory data = abi.encode(ids);

        vm.prank(address(0xBEEF));
        vault.swap(address(0xBEEF), address(token0), 1, 0, pairData, data);
    }

    function testRemoveLiquidityERC20() public {
        testAddLiquidityERC20ERC1155B();

        bytes memory pairData = abi.encode(
            address(token0),
            0,
            ERC1155B_INTERFACE_ID,
            address(token1),
            0,
            ERC20_INTERFACE_ID,
            address(xyk)
        );

        vm.prank(address(0xBEEF));
        vault.removeLiquidity(address(0xBEEF), 1 gwei * 1, 1, 1, pairData);
    }
}
