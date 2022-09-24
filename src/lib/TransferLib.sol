// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

import {Asset} from "./ReserveStructs.sol";

library TransferLib {
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
    // function _ERC1155Transfer(
    //     Asset calldata asset,
    //     address from,
    //     address to,
    //     uint128 amount
    // ) internal {
    //     require(asset.token.code.length != 0, "not token");
    //     IERC1155(asset.token).safeTransferFrom(from, to, asset.identifier, amount, "");
    // }

    function _transferERC1155(
        Asset memory asset,
        address from,
        address to,
        uint128 amount
    ) internal {
        IERC1155(asset.token).safeTransferFrom(from, to, asset.identifier, amount, "");
    }
}
