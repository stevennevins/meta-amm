// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC165Checker} from "openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";
import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155B} from "../test/mocks/ERC1155B.sol";

import {ICurve, Pair} from "./interfaces/ICurve.sol";
import {TransferLib} from "./lib/TransferLib.sol";

/// a minimalistic meta AMM
contract Vault is ERC1155, ERC1155TokenReceiver {
    using ERC165Checker for address;
    using TransferLib for address;
    /// metadata stuff for 1155
    string public constant name = "";
    string public constant symbol = "";

    bytes4 public constant IERC20_ID = type(IERC20).interfaceId;
    bytes4 public constant IERC721_ID = type(IERC721).interfaceId;
    bytes4 public constant IERC1155_ID = type(IERC1155).interfaceId;
    bytes4 public constant ERC1155B_ID = type(ERC1155B).interfaceId;

    function uri(uint256) public pure override returns (string memory) {
        return "";
    }

    mapping(uint256 => Pair) public pairs; /// pairId => Pair
    mapping(address => mapping(uint256 => uint256)) public enumeratedIds; /// token adddress => index => id held by Vault, balanceOf(address(this)) = current index
    mapping(address => uint128) public currentIndex; /// for ERC1155B: token address => current Index

    function addLiquidity(
        address to,
        uint128 token0Amount,
        uint128 token1Amount,
        uint128 minK,
        bytes calldata pairData,
        bytes calldata transferData
    ) external returns (uint128 k) {
        k = _addLiquidity(to, token0Amount, token1Amount, pairData, transferData);

        require(k >= minK, "liquidity must be greater than minK liquidity");
    }

    function removeLiquidity(
        address from,
        uint128 k,
        uint128 minAmount0Out,
        uint128 minAmount1Out,
        bytes calldata pairData
    ) external returns (uint128 amount0Out, uint128 amount1Out) {
        (amount0Out, amount1Out) = _removeLiquidity(from, k, pairData);

        require(amount0Out >= minAmount0Out, "amountOut must be greater than minAmountOut");
        require(amount1Out >= minAmount1Out, "amountOut must be greater than minAmountOut");
    }

    function swap(
        address to,
        address tokenIn,
        uint128 amountIn,
        uint128 minAmountOut,
        bytes calldata pairData,
        bytes calldata transferData
    ) external returns (address tokenOut, uint128 amountOut) {
        (tokenOut, amountOut) = _swap(to, tokenIn, amountIn, pairData, transferData);

        require(amountOut >= minAmountOut, "amountOut must be greater than minAmountOut");
    }

    function _addLiquidity(
        address to,
        uint128 token0Amount,
        uint128 token1Amount,
        bytes calldata pairData,
        bytes calldata transferData
    ) internal returns (uint128 k) {
        uint256 pairId = uint256(keccak256(pairData));
        Pair storage pair = pairs[pairId];

        (address token0, , , address token1, , , ICurve invariant) = abi.decode(
            pairData,
            (address, uint256, bytes4, address, uint256, bytes4, ICurve)
        );
        require(token0 < token1, "tokens must be sorted");

        require(address(invariant).code.length != 0, "amm must be a contract");
        k = invariant.addLiquidity(pair, token0Amount, token1Amount);
        pair.reserve0 += token0Amount;
        pair.reserve1 += token1Amount;

        (bytes memory token0Data, bytes memory token1Data) = abi.decode(
            transferData,
            (bytes, bytes)
        );

        _mint(to, pairId, k, "");
        _transfer(token0, to, address(this), token0Amount, pairData, token0Data);
        _transfer(token1, to, address(this), token1Amount, pairData, token1Data);
    }

    function _removeLiquidity(
        address from,
        uint128 k,
        bytes calldata pairData
    ) internal returns (uint128 amount0Out, uint128 amount1Out) {
        uint256 pairId = uint256(keccak256(pairData));
        Pair storage pair = pairs[pairId];

        (address token0, , , address token1, , , ICurve invariant) = abi.decode(
            pairData,
            (address, uint256, bytes4, address, uint256, bytes4, ICurve)
        );
        require(token0 < token1, "tokens must be sorted");
        require(address(invariant).code.length != 0, "amm must be a contract");
        (amount0Out, amount1Out) = invariant.removeLiquidity(pair, k);
        pair.reserve0 -= amount0Out;
        pair.reserve1 -= amount1Out;

        _burn(from, pairId, k);
        _transfer(token0, address(this), from, amount0Out, pairData, "");
        _transfer(token1, address(this), from, amount1Out, pairData, "");
    }

    function _swap(
        address to,
        address tokenIn,
        uint128 amountIn,
        bytes calldata pairData,
        bytes calldata transferData
    ) internal returns (address tokenOut, uint128 amountOut) {
        uint256 pairId = uint256(keccak256(pairData));
        Pair storage pair = pairs[pairId];
        (address token0, , , address token1, , , ICurve invariant) = abi.decode(
            pairData,
            (address, uint256, bytes4, address, uint256, bytes4, ICurve)
        );

        require(token0 < token1, "tokens must be sorted");
        require(tokenIn == token0 || tokenIn == token1, "invalid token");

        require(address(invariant).code.length != 0, "amm must be a contract");
        (tokenOut, amountOut) = (tokenIn == token0)
            ? (token1, invariant.swap(pair.reserve0, pair.reserve1, amountIn))
            : (token0, invariant.swap(pair.reserve1, pair.reserve0, amountIn));

        (token0 == tokenIn) ? pair.reserve0 += amountIn : pair.reserve0 -= amountOut;

        _transfer(tokenIn, to, address(this), amountIn, pairData, transferData);
        _transfer(tokenOut, address(this), to, amountOut, pairData, "");
    }

    function _transfer(
        address token,
        address from,
        address to,
        uint128 amount,
        bytes calldata pairData,
        bytes memory transferData
    ) internal {
        uint256 tokenId;
        (
            address token0,
            uint256 token0Id,
            bytes4 token0InterfaceId,
            ,
            uint256 token1Id,
            bytes4 token1InterfaceId,

        ) = abi.decode(pairData, (address, uint256, bytes4, address, uint256, bytes4, ICurve));

        bytes4 interfaceId = (token == token0) ? token0InterfaceId : token1InterfaceId;
        if (interfaceId == IERC20_ID) {
            if (from == address(this)) {
                token._performERC20Transfer(to, amount);
            } else {
                token._performERC20TransferFrom(from, to, amount);
            }
        } else if (interfaceId == IERC721_ID) {
            if (from == address(this)) {
                uint256 upper = IERC721(token).balanceOf(from);
                uint256 lower = upper - amount;
                for (; lower < upper; lower++) {
                    token._performERC721Transfer(from, to, lower);
                }
            } else {
                uint256[] memory ids = abi.decode(transferData, (uint256[]));
                uint256 length = ids.length;
                uint256 totalIds = IERC721(token).balanceOf(to);
                for (uint256 i; i < length; i++) {
                    tokenId = ids[i];
                    enumeratedIds[token][totalIds++] = tokenId;
                    token._performERC721Transfer(from, to, tokenId);
                }
            }
        } else if (interfaceId == IERC1155_ID) {
            tokenId = (token == token0) ? token0Id : token1Id;
            token._performERC1155Transfer(from, to, tokenId, amount, transferData);
        } else if (interfaceId == ERC1155B_ID) {
            if (from == address(this)) {
                uint256[] memory ids = new uint256[](uint256(amount));
                uint256[] memory amounts = new uint256[](uint256(amount));
                uint256 upper = currentIndex[token];
                uint256 lower = upper - amount;
                currentIndex[token] = uint128(lower);
                for (uint256 i; lower < upper; lower++) {
                    ids[i] = enumeratedIds[token][lower];
                    amounts[i++] = 1;
                }
                token._performERC1155BatchTransfer(from, to, ids, amounts, "");
            } else {
                (uint256[] memory ids, uint256[] memory amounts) = abi.decode(
                    transferData,
                    (uint256[], uint256[])
                );
                uint256 length = ids.length;
                uint256 totalIds = currentIndex[token];
                for (uint256 i; i < length; i++) enumeratedIds[token][totalIds++] = ids[i];
                currentIndex[token] += uint128(length);
                token._performERC1155BatchTransfer(from, to, ids, amounts, "");
            }
        } else revert("token must support ERC20, ERC721, or ERC1155");
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
