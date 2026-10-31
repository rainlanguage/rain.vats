// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable-5.7.0/token/ERC20/ERC20Upgradeable.sol";
import {LibERC20Storage} from "src/lib/LibERC20Storage.sol";

/// @dev A minimal `ERC20Upgradeable` subclass that exposes `_mint` / `_burn`
/// and the `LibERC20Storage` helpers as external methods. The library uses
/// `internal` functions so they get inlined into this contract and read /
/// write its own storage at the OZ ERC-7201 namespaced slot — exactly the
/// invariant being tested.
contract TestERC20 is ERC20Upgradeable {
    constructor() initializer {
        __ERC20_init("Test", "TST");
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    function libBalanceOf(address account) external view returns (uint256) {
        return LibERC20Storage.underlyingBalance(account);
    }

    function libTotalSupply() external view returns (uint256) {
        return LibERC20Storage.underlyingTotalSupply();
    }

    function libSetBalance(address account, uint256 newBalance) external {
        LibERC20Storage.setUnderlyingBalance(account, newBalance);
    }

    function libSetTotalSupply(uint256 newTotalSupply) external {
        LibERC20Storage.setUnderlyingTotalSupply(newTotalSupply);
    }
}
