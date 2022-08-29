// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC165Checker} from "openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";
import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

import {ICurve, Pair} from "./interfaces/ICurve.sol";
import {TransferLib} from "./lib/TransferLib.sol";

import "forge-std/Test.sol";

/// a minimalistic meta AMM
contract Vault is ERC1155, ERC1155TokenReceiver {
    using ERC165Checker for address;
    using TransferLib for address;
    /// metadata stuff for 1155
    string public constant name = "";
    string public constant symbol = "";

    bytes4 public constant ERC20_INTERFACE_ID = type(IERC20).interfaceId;
    bytes4 public constant ERC721_INTERFACE_ID = type(IERC721).interfaceId;
    bytes4 public constant ERC1155_INTERFACE_ID = type(IERC1155).interfaceId;

    function uri(uint256) public pure override returns (string memory) {
        return "";
    }

    mapping(uint256 => Pair) public pairs; /// pairId => Pair
    mapping(address => mapping(uint256 => uint256)) public enumeratedIds; /// token adddress => index => id held , balanceOf(address(this)) = upperBound of index
    /// we only need this for ERC1155 because 721s we can get balanceOf directly (unless balanceOf gets overloaded in ERC1155B)
    mapping(address => uint256) public lengthIds;

    function createPair(
        address token0,
        uint256 token0Id,
        bytes4 token0InterfaceId,
        address token1,
        uint256 token1Id,
        bytes4 token1InterfaceId,
        ICurve invariant
    ) external returns (uint256 pairId) {
        if (token0 >= token1) {
            require(token0 != token1, "token0 and token1 must be different");
            /// sort tokens to prevent duplicates
            (token1, token1Id, token1InterfaceId, token0, token0Id, token0InterfaceId) = (
                token0,
                token0Id,
                token0InterfaceId,
                token1,
                token1Id,
                token1InterfaceId
            );
        }

        /// maybe delegate this to the AMM contract? where the AMM says what tokenInterfaces it accepts
        /// and then we also just check the token supports that interface Id
        require(
            (token0InterfaceId == ERC20_INTERFACE_ID ||
                token0InterfaceId == ERC721_INTERFACE_ID ||
                token0InterfaceId == ERC1155_INTERFACE_ID) &&
                token0.supportsInterface(token0InterfaceId),
            "token0 does not support token0InterfaceId"
        );
        require(
            (token1InterfaceId == ERC20_INTERFACE_ID ||
                token1InterfaceId == ERC721_INTERFACE_ID ||
                token1InterfaceId == ERC1155_INTERFACE_ID) &&
                token1.supportsInterface(token1InterfaceId),
            "token1 does not support token1InterfaceId"
        );

        pairId = uint256(
            keccak256(
                abi.encode(
                    token0,
                    token0Id,
                    token0InterfaceId,
                    token1,
                    token1Id,
                    token1InterfaceId,
                    invariant
                )
            )
        );

        require(address(invariant).code.length != 0, "amm must be a contract");
        require(address(pairs[pairId].invariant) == address(0), "pair already exists");

        pairs[pairId] = Pair(
            token0,
            0,
            token0Id,
            token1,
            0,
            token1Id,
            invariant,
            token0InterfaceId,
            token1InterfaceId
        );
    }

    function addLiquidity(
        address to,
        uint256 pairId,
        uint96 token0Amount,
        uint96 token1Amount,
        uint96 minK,
        bytes calldata data
    ) external returns (uint96 k) {
        Pair storage pair = pairs[pairId];

        k = pair.invariant.addLiquidity(pair, token0Amount, token1Amount);
        pair.reserve0 += token0Amount;
        pair.reserve1 += token1Amount;

        (bytes memory token0Data, bytes memory token1Data) = abi.decode(data, (bytes, bytes));

        _mint(to, pairId, k, "");
        _transfer(pair, pair.token0, to, address(this), token0Amount, token0Data);
        _transfer(pair, pair.token1, to, address(this), token1Amount, token1Data);

        require(k >= minK, "liquidity must be greater than minK liquidity");
    }

    function removeLiquidity(
        address from,
        uint256 pairId,
        uint96 k,
        uint96 minAmount0Out,
        uint96 minAmount1Out
    ) external returns (uint96 amount0Out, uint96 amount1Out) {
        Pair storage pair = pairs[pairId];

        (amount0Out, amount1Out) = pair.invariant.removeLiquidity(pair, k);
        pair.reserve0 -= amount0Out;
        pair.reserve1 -= amount1Out;

        _burn(from, pairId, k);
        _transfer(pair, pair.token0, address(this), from, amount0Out, "");
        _transfer(pair, pair.token1, address(this), from, amount1Out, "");

        require(amount0Out >= minAmount0Out, "amountOut must be greater than minAmountOut");
        require(amount1Out >= minAmount1Out, "amountOut must be greater than minAmountOut");
    }

    function swap(
        address to,
        uint256 pairId,
        address tokenIn,
        uint96 amountIn,
        uint96 minAmountOut,
        bytes calldata data
    ) external returns (address tokenOut, uint96 amountOut) {
        Pair storage pair = pairs[pairId];
        address token0 = pair.token0;
        address token1 = pair.token1;
        require(tokenIn == token0 || tokenIn == token1, "invalid token");

        amountOut = pair.invariant.swap(pair, tokenIn, amountIn);
        tokenOut = (tokenIn == token0) ? token1 : token0;

        (token0 == tokenIn) ? pair.reserve0 += amountIn : pair.reserve0 -= amountOut;
        (token1 == tokenIn) ? pair.reserve1 += amountIn : pair.reserve1 -= amountOut;

        _transfer(pair, tokenIn, to, address(this), amountIn, data);
        _transfer(pair, tokenOut, address(this), to, amountOut, "");

        require(amountOut >= minAmountOut, "amountOut must be greater than minAmountOut");
    }

    function _transfer(
        Pair memory pair,
        address token,
        address from,
        address to,
        uint96 amount,
        bytes memory data
    ) internal {
        uint256 tokenId;
        bytes4 interfaceId = (token == pair.token0)
            ? pair.token0InterfaceId
            : pair.token1InterfaceId;
        if (interfaceId == ERC20_INTERFACE_ID) {
            if (from == address(this)) {
                token._performERC20Transfer(to, amount);
            } else {
                token._performERC20TransferFrom(from, to, amount);
            }
            return;
        }
        if (interfaceId == ERC721_INTERFACE_ID) {
            if (from == address(this)) {
                uint256 upper = IERC721(token).balanceOf(from);
                uint256 lower = upper - amount;
                for (; lower < upper; lower++) {
                    token._performERC721Transfer(from, to, lower);
                }
            } else {
                uint256[] memory ids = abi.decode(data, (uint256[]));
                uint256 length = ids.length;
                uint256 totalIds = IERC721(token).balanceOf(to);
                for (uint256 i; i < length; i++) {
                    tokenId = ids[i];
                    enumeratedIds[token][totalIds++] = tokenId;
                    token._performERC721Transfer(from, to, tokenId);
                }
            }
            return;
        }
        if (interfaceId == ERC1155_INTERFACE_ID) {
            tokenId = (token == pair.token0) ? pair.token0Id : pair.token1Id;
            token._performERC1155Transfer(from, to, tokenId, amount, data);
            return;
        }
        /// also would be nice to add 1155B support
        /// can try and catch if supports interface isn't supported and then revert
        revert("token must support ERC20, ERC721, or ERC1155");
    }

    /// @notice Handles the receipt of a single ERC1155 token type
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual override returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    /// @notice Handles the receipt of multiple ERC1155 token types
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual override returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}
