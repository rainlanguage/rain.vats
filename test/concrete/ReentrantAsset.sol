// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20} from "@openzeppelin-contracts-5.6.1/token/ERC20/ERC20.sol";

/// @dev Minimal view of the vault `deposit` entrypoint the asset re-enters.
interface IReentrantAssetVault {
    function deposit(uint256 assets, address receiver, uint256 depositMinShareRatio, bytes memory receiptInformation)
        external
        returns (uint256);
}

/// @title ReentrantAsset
/// @notice TEST ERC20 vault asset that is a REAL, hooked, reentrant dependency.
/// When armed it re-enters the vault's `deposit` from inside its own ERC20
/// transfer hooks — `transferFrom` is the `_beforeDeposit` pull (row 8), and
/// `transfer` is the `_afterWithdraw` push (row 9). Because both `_deposit` and
/// `_withdraw` carry `nonReentrant`, the re-entrant deposit reverts with
/// `ReentrancyGuardReentrantCall`, and OpenZeppelin `SafeERC20` bubbles that raw
/// revert out of the hook, so the whole outer operation reverts.
///
/// It is a genuine ERC20 (balances, allowances, transfers all real) so that a
/// deposit can succeed normally BEFORE the transfer hook is armed — the withdraw
/// test relies on a real prior deposit to hold assets and shares.
contract ReentrantAsset is ERC20 {
    IReentrantAssetVault internal iVault;
    bool internal iReenterOnTransferFrom;
    bool internal iReenterOnTransfer;

    constructor() ERC20("Reentrant Asset", "RASSET") {}

    /// Mint tokens for test setup.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// Point the asset at the vault it should re-enter.
    function setVault(IReentrantAssetVault vault) external {
        iVault = vault;
    }

    /// Arm re-entry from the deposit-side `transferFrom` pull (row 8).
    function armTransferFrom() external {
        iReenterOnTransferFrom = true;
    }

    /// Arm re-entry from the withdraw-side `transfer` push (row 9).
    function armTransfer() external {
        iReenterOnTransfer = true;
    }

    /// @inheritdoc ERC20
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (iReenterOnTransferFrom && address(iVault) != address(0)) {
            // Re-enter the guarded deposit; reverts on the nonReentrant guard,
            // which bubbles out through SafeERC20 to the outer deposit.
            iVault.deposit(1, address(this), 0, "");
        }
        return super.transferFrom(from, to, value);
    }

    /// @inheritdoc ERC20
    function transfer(address to, uint256 value) public override returns (bool) {
        if (iReenterOnTransfer && address(iVault) != address(0)) {
            // Re-enter the guarded deposit from inside the withdraw-time push;
            // reverts on the shared nonReentrant guard held by `_withdraw`.
            iVault.deposit(1, address(this), 0, "");
        }
        return super.transfer(to, value);
    }
}
