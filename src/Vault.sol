// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC1155} from "solmate/tokens/ERC1155.sol";

import {ICurve} from "./interfaces/ICurve.sol";
import {Reserves, Pair} from "./lib/ReserveStructs.sol";

/// @dev Interface of the ERC20 standard as defined in the EIP.
/// @dev This includes the optional name, symbol, and decimals metadata.
interface IERC20 {
    /// @dev Emitted when `value` tokens are moved from one account (`from`) to another (`to`).
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @dev Emitted when the allowance of a `spender` for an `owner` is set, where `value`
    /// is the new allowance.
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Returns the amount of tokens in existence.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the amount of tokens owned by `account`.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Moves `amount` tokens from the caller's account to `to`.
    function transfer(address to, uint256 amount) external returns (bool);

    /// @notice Returns the remaining number of tokens that `spender` is allowed
    /// to spend on behalf of `owner`
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Sets `amount` as the allowance of `spender` over the caller's tokens.
    /// @dev Be aware of front-running risks: https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Moves `amount` tokens from `from` to `to` using the allowance mechanism.
    /// `amount` is then deducted from the caller's allowance.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /// @notice Returns the name of the token.
    function name() external view returns (string memory);

    /// @notice Returns the symbol of the token.
    function symbol() external view returns (string memory);

    /// @notice Returns the decimals places of the token.
    function decimals() external view returns (uint8);
}

/// a minimalistic meta AMM
contract Vault is ERC1155 {
    function uri(uint256) public pure override returns (string memory) {
        return "";
    }

    mapping(uint256 => Reserves) public pairReserves; /// pairId => Reserves

    function addLiquidity(
        address to,
        uint128 token0Amount,
        uint128 token1Amount,
        Pair calldata pair
    ) external returns (uint128) {
        return _addLiquidity(to, token0Amount, token1Amount, pair);
    }

    function removeLiquidity(
        address from,
        uint128 k,
        Pair calldata pair
    ) external returns (uint128, uint128) {
        return _removeLiquidity(from, k, pair);
    }

    function swap(
        address to,
        address tokenIn,
        uint128 amountIn,
        Pair calldata pair
    ) external returns (address, uint128) {
        return _swap(to, tokenIn, amountIn, pair);
    }

    function _addLiquidity(
        address to,
        uint128 token0Amount,
        uint128 token1Amount,
        Pair calldata pair
    ) internal returns (uint128 k) {
        uint256 pairId = uint256(keccak256(abi.encode(pair)));
        Reserves storage reserves = pairReserves[pairId];

        require(pair.token0 < pair.token1, "token0 > token1");

        k = ICurve(pair.invariant).addLiquidity(reserves, token0Amount, token1Amount);
        reserves.reserve0 += token0Amount;
        reserves.reserve1 += token1Amount;

        IERC20(pair.token0).transferFrom(to, address(this), token0Amount);
        IERC20(pair.token1).transferFrom(to, address(this), token1Amount);

        _mint(to, pairId, k, "");
    }

    function _removeLiquidity(
        address from,
        uint128 k,
        Pair calldata pair
    ) internal returns (uint128 amount0Out, uint128 amount1Out) {
        uint256 pairId = uint256(keccak256(abi.encode(pair)));
        Reserves storage reserves = pairReserves[pairId];

        require(pair.token0 < pair.token1, "token0 > token1");
        (amount0Out, amount1Out) = ICurve(pair.invariant).removeLiquidity(reserves, k);
        reserves.reserve0 -= amount0Out;
        reserves.reserve1 -= amount1Out;

        _burn(from, pairId, k);
        IERC20(pair.token0).transfer(from, amount0Out);
        IERC20(pair.token1).transfer(from, amount1Out);
    }

    function _swap(
        address to,
        address tokenIn,
        uint128 amountIn,
        Pair calldata pair
    ) internal returns (address tokenOut, uint128 amountOut) {
        uint256 pairId = uint256(keccak256(abi.encode(pair)));
        Reserves storage reserves = pairReserves[pairId];
        if (tokenIn == pair.token0) {
            amountOut = ICurve(pair.invariant).swap(reserves.reserve0, reserves.reserve1, amountIn);
            (reserves.reserve0 += amountIn, reserves.reserve1 -= amountOut, tokenOut = pair.token1);
        } else if (tokenIn == pair.token1) {
            amountOut = ICurve(pair.invariant).swap(reserves.reserve1, reserves.reserve0, amountIn);
            (reserves.reserve0 -= amountOut, reserves.reserve1 += amountIn, tokenOut = pair.token0);
        }
        IERC20(tokenIn).transferFrom(to, address(this), amountIn);
        IERC20(tokenOut).transfer(to, amountOut);
    }
}
