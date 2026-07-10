// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// @dev Minimal view of the vault `deposit` entrypoint re-entered on refund.
interface IEthRefundReenterVault {
    function deposit(uint256 assets, address receiver, uint256 depositMinShareRatio, bytes memory receiptInformation)
        external
        payable
        returns (uint256);
}

/// @title EthRefundReenterDepositor
/// @notice TEST depositor that is a REAL, reentrant recipient of the ETH refund
/// (row 11). `deposit` sends any leftover contract balance back to the caller
/// via `Address.sendValue` AFTER `_deposit` has completed and released the
/// `nonReentrant` guard. This contract deposits with `msg.value`, then re-enters
/// `deposit` from its `receive()` when the refund arrives.
///
/// Because the refund fires OUTSIDE the guard, the re-entrant deposit is a fresh,
/// independent, SUCCESSFUL deposit — it mints its own shares under its own new
/// receipt id, with no stale state carried across. The test asserts both
/// deposits landed. If the guard spanned the refund (the mutation this test
/// discriminates), the nested deposit would revert, `sendValue` would revert on
/// the failed call, and the outer deposit would revert too — no shares minted.
contract EthRefundReenterDepositor {
    IEthRefundReenterVault internal iVault;
    uint256 internal iReenterAssets;
    address internal iReenterReceiver;
    bool internal iEntered;

    /// Number of times the refund re-entered a deposit. Expected: exactly 1.
    uint256 public reenterCount;

    constructor(IEthRefundReenterVault vault) {
        iVault = vault;
    }

    /// Perform the outer deposit, sending `msg.value` to be refunded.
    function deposit(uint256 outerAssets, address outerReceiver, uint256 reenterAssets, address reenterReceiver)
        external
        payable
    {
        iReenterAssets = reenterAssets;
        iReenterReceiver = reenterReceiver;
        iVault.deposit{value: msg.value}(outerAssets, outerReceiver, 0, "");
    }

    /// The ETH refund lands here, outside the vault's reentrancy guard.
    receive() external payable {
        if (!iEntered && address(iVault) != address(0)) {
            iEntered = true;
            reenterCount++;
            iVault.deposit(iReenterAssets, iReenterReceiver, 0, "");
        }
    }
}
