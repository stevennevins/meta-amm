// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

import {Asset} from "./ReserveStructs.sol";

library TransferLib {
    /**
     * @dev Internal function to transfer ERC20 tokens from the vault to
     *      a given recipient.
     *
     * @param token      The ERC20 token to transfer.
     * @param to         The recipient of the transfer.
     * @param amount     The amount to transfer.
     */
    function _ERC20Transfer(
        address token,
        address to,
        uint128 amount
    ) internal {
        require(token.code.length != 0, "not token");
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );

        // NOTE: revert reasons are not "bubbled up" at the moment
        if (!ok) revert();
        if (data.length != 0 && data.length >= 32) {
            if (!abi.decode(data, (bool))) revert("bad input");
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
    function _ERC20TransferFrom(
        address token,
        address from,
        address to,
        uint128 amount
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
    function _ERC721Transfer(
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
    function _ERC1155Transfer(
        address token,
        address from,
        address to,
        uint256 id,
        uint128 amount
    ) internal {
        require(token.code.length != 0, "not token");
        IERC1155(token).safeTransferFrom(from, to, id, amount, "");
    }

    /**
     * @dev Internal function to transfer ERC20 tokens from the vault to
     *      a given recipient.
     *
     * @param asset      The ERC20 token to transfer.
     * @param to         The recipient of the transfer.
     * @param amount     The amount to transfer.
     */
    function _ERC20Transfer(
        Asset memory asset,
        address to,
        uint128 amount
    ) internal {
        require(asset.token.code.length != 0, "not token");
        require(asset.identifier == 0, "not erc20");
        (bool ok, bytes memory data) = asset.token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );

        // NOTE: revert reasons are not "bubbled up" at the moment
        if (!ok) revert();
        if (data.length != 0 && data.length >= 32) {
            if (!abi.decode(data, (bool))) revert("bad input");
        }
    }

    /**
     * @dev Internal function to transfer ERC20 tokens from a given originator
     *      to a given recipient. Sufficient approvals must be set on the
     *      contract performing the transfer.
     *
     * @param asset      The ERC20 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param amount     The amount to transfer.
     */
    function _ERC20TransferFrom(
        Asset memory asset,
        address from,
        address to,
        uint128 amount
    ) internal {
        require(asset.token.code.length != 0, "not token");
        require(asset.identifier == 0, "not erc20");
        (bool ok, bytes memory data) = asset.token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );

        // NOTE: revert reasons are not "bubbled up" at the moment
        if (!ok) revert();
        if (data.length != 0 && data.length >= 32) {
            if (!abi.decode(data, (bool))) revert("bad input");
        }
    }

    /**
     * @dev Internal function to transfer ERC1155 tokens from a given
     *      originator to a given recipient. Sufficient approvals must be set on
     *      the contract performing the transfer and contract recipients must
     *      implement onReceived to indicate that they are willing to accept the
     *      transfer.
     *
     * @param asset      The ERC1155 token to transfer.
     * @param from       The originator of the transfer.
     * @param to         The recipient of the transfer.
     * @param amount     The amount to transfer.
     */
    function _ERC1155Transfer(
        Asset memory asset,
        address from,
        address to,
        uint128 amount
    ) internal {
        require(asset.token.code.length != 0, "not token");
        IERC1155(asset.token).safeTransferFrom(from, to, asset.identifier, amount, "");
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
     * @param ids         The ids to transfer.
     * @param amounts     The amounts to transfer.
     */
    function _ERC1155BatchTransfer(
        address token,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        require(token.code.length != 0, "not token");
        IERC1155(token).safeBatchTransferFrom(from, to, ids, amounts, data);
    }
}
