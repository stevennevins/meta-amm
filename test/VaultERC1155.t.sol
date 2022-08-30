// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {MockERC1155} from "./mocks/MockERC1155.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "../src/Vault.sol";
import "../src/invariants/XtYK.sol";

contract VaultERC1155Test is Test {
    bytes4 public constant ERC20_INTERFACE_ID = type(IERC20).interfaceId;
    bytes4 public constant ERC1155_INTERFACE_ID = type(IERC1155).interfaceId;
    Vault public vault;
    XtYK public xyk;
    MockERC1155 public token0;
    MockERC20 public token1;
    uint256 computedPairId;

    function setUp() public {
        vault = new Vault();
        xyk = new XtYK();
        token0 = new MockERC1155();
        token1 = new MockERC20("", "", 18);
        token0.mint(address(0xBEEF), 1, type(uint96).max);
        token1.mint(address(0xBEEF), type(uint96).max);
        vm.startPrank(address(0xBEEF));
        token0.setApprovalForAll(address(vault), true);
        token1.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function testCreatePairERC1155ERC20() public {
        assertTrue(address(token0) < address(token1));

        uint256 pairId = vault.createPair(
            address(token0),
            1,
            ERC1155_INTERFACE_ID,
            address(token1),
            0,
            ERC20_INTERFACE_ID,
            xyk
        );
        computedPairId = uint256(
            keccak256(
                abi.encode(
                    address(token0),
                    1,
                    ERC1155_INTERFACE_ID,
                    address(token1),
                    0,
                    ERC20_INTERFACE_ID,
                    address(xyk)
                )
            )
        );

        assertTrue(pairId == computedPairId);
    }

    function testAddLiquidityERC1155ERC20() public {
        testCreatePairERC1155ERC20();

        bytes memory pairData = abi.encode(
            address(token0),
            1,
            ERC1155_INTERFACE_ID,
            address(token1),
            0,
            ERC20_INTERFACE_ID,
            address(xyk)
        );

        bytes memory data = abi.encode("", "");

        vm.prank(address(0xBEEF));
        vault.addLiquidity(address(0xBEEF), 1 gwei, 1 gwei, 1, pairData, data);
        assertEq(token0.balanceOf(address(vault), 1), 1 gwei);
        assertEq(token1.balanceOf(address(vault)), 1 gwei);
    }

    function testSwapERC20toERC1155() public {
        testAddLiquidityERC1155ERC20();

        bytes memory pairData = abi.encode(
            address(token0),
            1,
            ERC1155_INTERFACE_ID,
            address(token1),
            0,
            ERC20_INTERFACE_ID,
            address(xyk)
        );

        vm.prank(address(0xBEEF));
        vault.swap(address(0xBEEF), address(token1), 0.5 gwei, 1, pairData, "");
    }

    function testSwapERC1155toERC20() public {
        testAddLiquidityERC1155ERC20();
        bytes memory pairData = abi.encode(
            address(token0),
            1,
            ERC1155_INTERFACE_ID,
            address(token1),
            0,
            ERC20_INTERFACE_ID,
            address(xyk)
        );

        bytes memory data = abi.encode("");

        vm.prank(address(0xBEEF));
        vault.swap(address(0xBEEF), address(token0), 0.5 gwei, 0, pairData, data);
    }

    function testRemoveLiquidityERC20() public {
        testAddLiquidityERC1155ERC20();
        bytes memory pairData = abi.encode(
            address(token0),
            1,
            ERC1155_INTERFACE_ID,
            address(token1),
            0,
            ERC20_INTERFACE_ID,
            address(xyk)
        );

        vm.prank(address(0xBEEF));
        vault.removeLiquidity(address(0xBEEF), 1 gwei * 1 gwei - 1000, 1, 1, pairData);
    }
}
