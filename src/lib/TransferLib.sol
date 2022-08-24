// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC165Checker} from "openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

import {Pair} from "../interfaces/ICurve.sol";

library TransferLib {
    using ERC165Checker for address;

    function transfer(
        Pair memory pair,
        address token0or1,
        address from,
        address to,
        uint96 amount,
        bytes memory data
    ) internal {
        uint256 token0or1Id;
        if (token0or1.supportsInterface(type(IERC20).interfaceId)) {
            _performERC20Transfer(token0or1, from, to, amount);
        } else if (token0or1.supportsInterface(type(IERC721).interfaceId)) {
            require(token0or1 == pair.token0 || token0or1 == pair.token1, "invalid token");
            token0or1Id = (token0or1 == pair.token0) ? pair.token0Id : pair.token1Id;
            _performERC721Transfer(token0or1, from, to, token0or1Id);
        } else if (token0or1.supportsInterface(type(IERC1155).interfaceId)) {
            require(token0or1 == pair.token0 || token0or1 == pair.token1, "invalid token");
            token0or1Id = (token0or1 == pair.token0) ? pair.token0Id : pair.token1Id;
            _performERC1155Transfer(token0or1, from, to, token0or1Id, amount, data);
        } else {
            require(false, "token0or1 must support ERC20, ERC721, or ERC1155");
        }
    }

    /**
     * @dev Internal function to transfer ERC20 tokens from a given originator
     *      to a given recipient. Sufficient approvals must be set on the
     *      contract performing the transfer.
     *
     * @param token      The ERC20 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param amount     The amount to transfer.
     */
    function _performERC20Transfer(
        address token,
        address from,
        address to,
        uint96 amount
    ) internal {
        require(token.code.length != 0, "not token");
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );

        // NOTE: revert reasons are not "bubbled up" at the moment
        if (!ok) revert();
        if (data.length != 0 && data.length >= 32) {
            if (!abi.decode(data, (bool))) revert("bad input");
        }
    }

    /**
     * @dev Internal function to transfer an ERC721 token from a given
     *      originator to a given recipient. Sufficient approvals must be set on
     *      the contract performing the transfer.
     *
     * @param token      The ERC721 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param id         The tokenId to transfer.
     */
    function _performERC721Transfer(
        address token,
        address from,
        address to,
        uint256 id
    ) internal {
        require(token.code.length != 0, "not token");
        IERC721(token).transferFrom(from, to, id);
    }

    /**
     * @dev Internal function to transfer ERC1155 tokens from a given
     *      originator to a given recipient. Sufficient approvals must be set on
     *      the contract performing the transfer and contract recipients must
     *      implement onReceived to indicate that they are willing to accept the
     *      transfer.
     *
     * @param token      The ERC1155 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param id         The id to transfer.
     * @param amount     The amount to transfer.
     */
    function _performERC1155Transfer(
        address token,
        address from,
        address to,
        uint256 id,
        uint96 amount,
        bytes memory data
    ) internal {
        require(token.code.length != 0, "not token");
        IERC1155(token).safeTransferFrom(from, to, id, amount, data);
    }
}
