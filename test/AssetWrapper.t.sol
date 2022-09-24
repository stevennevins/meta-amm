// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {MockERC1155} from "./mocks/MockERC1155.sol";
import {MockERC721} from "./mocks/MockERC721.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "../src/AssetWrapper.sol";

contract AssetWrapperTest is Test {
    AssetWrapper public wrapper;
    MockERC721 public nft;
    MockERC20 public erc20;

    function setUp() public {
        wrapper = new AssetWrapper();
        nft = new MockERC721("", "");
        erc20 = new MockERC20("", "", uint8(18));
        nft.mint(address(0xBEEF), 1);
        nft.mint(address(0xBEEF), 2);
        erc20.mint(address(0xBEEF), type(uint128).max);
        vm.startPrank(address(0xBEEF));
        nft.setApprovalForAll(address(wrapper), true);
        erc20.approve(address(wrapper), type(uint128).max);
        vm.stopPrank();
    }

    function testWrapERC721() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        vm.startPrank(address(0xBEEF));
        wrapper.wrapERC721(address(0xBEEF), Asset(address(nft), 0), ids);
        vm.stopPrank();
    }

    function testUnwrapERC721() public {
        testWrapERC721();
        vm.startPrank(address(0xBEEF));
        wrapper.unwrapERC721(address(0xBEEF), 1, Asset(address(nft), 0));
        vm.stopPrank();
    }

    function testWrapERC20() public {
        vm.startPrank(address(0xBEEF));
        wrapper.wrapERC20(address(0xBEEF), Asset(address(erc20), 0), 1 ether);
        vm.stopPrank();
    }

    function testUnwrapERC20() public {
        testWrapERC20();
        vm.startPrank(address(0xBEEF));
        wrapper.unwrapERC20(address(0xBEEF), Asset(address(erc20), 0), 1 ether);
        vm.stopPrank();
    }
}
