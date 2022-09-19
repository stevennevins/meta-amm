// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC1155, ERC1155TokenReceiver} from "solmate/tokens/ERC1155.sol";

import {ICurve, Pair} from "./interfaces/ICurve.sol";
import {TransferLib} from "./lib/TransferLib.sol";

/// a minimalistic meta AMM
contract Vault is ERC1155, ERC1155TokenReceiver {
    using TransferLib for address;

    function uri(uint256) public pure override returns (string memory) {
        return "";
    }

    mapping(uint256 => Pair) public pairs; /// pairId => Pair

    /// I think the sauce will be allowing people to scope their own ids
    /// maybe let people deposit to a Reserve where the hash is based on the address
    /// they're giving controll over their ids ie either Jitty or themselves
    // mapping(uint256 => Reserve) public internalBalances; ///

    mapping(address => mapping(uint256 => uint256)) public enumeratedIds; /// token adddress => index => id held by Vault, balanceOf(address(this)) = current index
    mapping(address => uint128) public currentIndex; /// for ERC1155B: token address => current Index

    function addLiquidity(
        address to,
        uint128 token0Amount,
        uint128 token1Amount,
        uint128 minK,
        bytes calldata pairData
    ) external returns (uint128 k) {
        k = _addLiquidity(to, token0Amount, token1Amount, pairData);

        require(k >= minK, "K < minK");
    }

    function removeLiquidity(
        address from,
        uint128 k,
        uint128 minAmount0Out,
        uint128 minAmount1Out,
        bytes calldata pairData
    ) external returns (uint128 amount0Out, uint128 amount1Out) {
        (amount0Out, amount1Out) = _removeLiquidity(from, k, pairData);

        require(amount0Out >= minAmount0Out, "amountOut < minAmountOut");
        require(amount1Out >= minAmount1Out, "amountOut < minAmountOut");
    }

    function swap(
        address to,
        address tokenIn,
        uint128 amountIn,
        uint128 minAmountOut,
        bytes calldata pairData
    ) external returns (address tokenOut, uint128 amountOut) {
        (tokenOut, amountOut) = _swap(to, tokenIn, amountIn, pairData);

        require(amountOut >= minAmountOut, "amountOut < minAmountOut");
    }

    function _addLiquidity(
        address to,
        uint128 token0Amount,
        uint128 token1Amount,
        bytes calldata pairData
    ) internal returns (uint128 k) {
        uint256 pairId = uint256(keccak256(pairData));
        Pair storage pair = pairs[pairId];

        (address token0, , address token1, , ICurve invariant) = abi.decode(
            pairData,
            (address, uint256, address, uint256, ICurve)
        );
        require(token0 < token1, "token0 > token1");

        require(address(invariant).code.length != 0, "amm must be a contract");
        k = invariant.addLiquidity(pair, token0Amount, token1Amount);
        pair.reserve0 += token0Amount;
        pair.reserve1 += token1Amount;

        _mint(to, pairId, k, "");
        _transfer(token0, to, address(this), token0Amount, pairData);
        _transfer(token1, to, address(this), token1Amount, pairData);
    }

    function _removeLiquidity(
        address from,
        uint128 k,
        bytes calldata pairData
    ) internal returns (uint128 amount0Out, uint128 amount1Out) {
        uint256 pairId = uint256(keccak256(pairData));
        Pair storage pair = pairs[pairId];

        (address token0, , address token1, , ICurve invariant) = abi.decode(
            pairData,
            (address, uint256, address, uint256, ICurve)
        );
        require(token0 < token1, "token0 > token1");
        require(address(invariant).code.length != 0, "amm must be a contract");
        (amount0Out, amount1Out) = invariant.removeLiquidity(pair, k);
        pair.reserve0 -= amount0Out;
        pair.reserve1 -= amount1Out;

        _burn(from, pairId, k);
        _transfer(token0, address(this), from, amount0Out, pairData);
        _transfer(token1, address(this), from, amount1Out, pairData);
    }

    function _swap(
        address to,
        address tokenIn,
        uint128 amountIn,
        bytes calldata pairData
    ) internal returns (address tokenOut, uint128 amountOut) {
        uint256 pairId = uint256(keccak256(pairData));
        Pair storage pair = pairs[pairId];
        (address token0, , address token1, , ICurve invariant) = abi.decode(
            pairData,
            (address, uint256, address, uint256, ICurve)
        );

        require(token0 < token1, "token0 > token1");
        require(tokenIn == token0 || tokenIn == token1, "invalid token");

        require(address(invariant).code.length != 0, "amm must be a contract");
        (tokenOut, amountOut) = (tokenIn == token0)
            ? (token1, invariant.swap(pair.reserve0, pair.reserve1, amountIn))
            : (token0, invariant.swap(pair.reserve1, pair.reserve0, amountIn));

        (token0 == tokenIn) ? pair.reserve0 += amountIn : pair.reserve0 -= amountOut;

        _transfer(tokenIn, to, address(this), amountIn, pairData);
        _transfer(tokenOut, address(this), to, amountOut, pairData);
    }

    function _transfer(
        address token,
        address from,
        address to,
        uint128 amount,
        bytes calldata pairData
    ) internal {
        uint256 tokenId;
        (address token0, uint256 token0Id, , uint256 token1Id, ) = abi.decode(
            pairData,
            (address, uint256, address, uint256, ICurve)
        );
        tokenId = (token == token0) ? token0Id : token1Id;
        token._performERC1155Transfer(from, to, tokenId, amount, "");
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
