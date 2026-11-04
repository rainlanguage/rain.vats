// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC1155Upgradeable} from "@openzeppelin-contracts-upgradeable-5.7.0/token/ERC1155/ERC1155Upgradeable.sol";
import {LibERC1155Storage} from "src/lib/LibERC1155Storage.sol";

/// @dev A minimal `ERC1155Upgradeable` subclass that exposes `_mint` / `_burn`
/// and the `LibERC1155Storage` helpers as external methods. The library uses
/// `internal` functions so they get inlined into this contract and read /
/// write its own storage at the OZ ERC-7201 namespaced slot — exactly the
/// invariant being tested.
contract TestERC1155 is ERC1155Upgradeable {
    constructor() initializer {
        __ERC1155_init("");
    }

    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }

    function burn(address from, uint256 id, uint256 amount) external {
        _burn(from, id, amount);
    }

    function libBalanceOf(address account, uint256 id) external view returns (uint256) {
        return LibERC1155Storage.underlyingBalance(account, id);
    }

    function libSetBalance(address account, uint256 id, uint256 newBalance) external {
        LibERC1155Storage.setUnderlyingBalance(account, id, newBalance);
    }
}
