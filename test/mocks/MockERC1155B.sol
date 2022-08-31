// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC1155B} from "./ERC1155B.sol";
import "openzeppelin-contracts/contracts/utils/introspection/ERC165Storage.sol";

contract MockERC1155B is ERC1155B, ERC165Storage {
    /// metadata stuff for 1155
    string public constant name = "";
    string public constant symbol = "";

    constructor() {
        _registerInterface(type(ERC1155B).interfaceId);
    }

    function uri(uint256) public pure override returns (string memory) {
        return "";
    }

    function mint(address to, uint256 id) public virtual {
        _mint(to, id, "");
    }

    function batchMint(address to, uint256[] memory ids) public virtual {
        _batchMint(to, ids, "");
    }

    function batchBurn(address from, uint256[] memory ids) public virtual {
        _batchBurn(from, ids);
    }

    function burn(uint256 id) public virtual {
        _burn(id);
    }
}
