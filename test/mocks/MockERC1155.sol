// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC1155} from "solmate/tokens/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    /// metadata stuff for 1155
    string public constant name = "";
    string public constant symbol = "";

    function uri(uint256) public pure override returns (string memory) {
        return "";
    }

    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) public virtual {
        _mint(to, id, amount, "");
    }

    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) public virtual {
        _burn(from, id, amount);
    }
}
