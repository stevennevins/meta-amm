// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "../src/Vault.sol";
import "../src/invariants/XtYK.sol";

contract VaultERC20Test is Test {
    bytes4 public constant ERC20_INTERFACE_ID = type(IERC20).interfaceId;

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
        token0.mint(address(0xBEEF), type(uint128).max);
        token1.mint(address(0xBEEF), type(uint128).max);
        vm.startPrank(address(0xBEEF));
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function testCreatePairERC20() public {
        assertTrue(address(token0) < address(token1));

        computedPairId = uint256(
            keccak256(
                abi.encode(
                    address(token0),
                    0,
                    ERC20_INTERFACE_ID,
                    address(token1),
                    0,
                    ERC20_INTERFACE_ID,
                    address(xyk)
                )
            )
        );
    }

    function testAddLiquidityERC20() public {
        testCreatePairERC20();

        bytes memory pairData = abi.encode(
            address(token0),
            0,
            ERC20_INTERFACE_ID,
            address(token1),
            0,
            ERC20_INTERFACE_ID,
            address(xyk)
        );

        bytes memory _transferData = abi.encode(new uint256[](0), "");
        bytes memory data = abi.encode(_transferData, _transferData);
        vault.addLiquidity(address(0xBEEF), 1 gwei, 1 gwei, 1, pairData, data);
        assertEq(token0.balanceOf(address(vault)), 1 gwei);
        assertEq(token1.balanceOf(address(vault)), 1 gwei);
    }

    function testSwapERC20() public {
        testAddLiquidityERC20();
        bytes memory pairData = abi.encode(
            address(token0),
            0,
            ERC20_INTERFACE_ID,
            address(token1),
            0,
            ERC20_INTERFACE_ID,
            address(xyk)
        );

        bytes memory data = abi.encode(new uint256[](0), "");
        vault.swap(address(0xBEEF), address(token0), 0.0001 gwei, 1, pairData, data);
    }

    function testRemoveLiquidityERC20() public {
        testAddLiquidityERC20();
        bytes memory pairData = abi.encode(
            address(token0),
            0,
            ERC20_INTERFACE_ID,
            address(token1),
            0,
            ERC20_INTERFACE_ID,
            address(xyk)
        );

        vault.removeLiquidity(address(0xBEEF), 1 gwei * 1 gwei - 1000, 1, 1, pairData);
    }
}
