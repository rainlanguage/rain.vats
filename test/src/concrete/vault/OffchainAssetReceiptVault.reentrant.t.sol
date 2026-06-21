// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {AlwaysAuthorize} from "test/concrete/AlwaysAuthorize.sol";
import {ReentrantDepositReceiver, IReentrantDepositTarget} from "test/concrete/ReentrantDepositReceiver.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts-5.6.1/utils/ReentrancyGuard.sol";

/// @notice Regression tests for reentrancy protection in OffchainAssetReceiptVault.
/// Covers the ERC1155 acceptance-callback surface documented in issue #316 (rows
/// 1/2/7 of the master reentrancy call-site table).
///
/// The vault's `_deposit` and `_withdraw` carry `nonReentrant` from
/// ReentrancyGuard. Any vault entrypoint that re-enters through the ERC1155
/// acceptance callback fired by `receipt().managerMint` therefore reverts with
/// `ReentrancyGuardReentrantCall` before any state is modified.
contract OffchainAssetReceiptVaultReentrantTest is OffchainAssetReceiptVaultTest {
    /// A malicious `receiver` that re-enters `vault.deposit` from within
    /// `onERC1155Received` cannot bypass the `nonReentrant` guard: the nested
    /// deposit reverts and the entire outer transaction reverts too.
    function testDepositReentrancyGuardFires(uint256 assets, string memory shareName, string memory shareSymbol)
        external
    {
        assets = bound(assets, 1, type(uint128).max);
        address admin = makeAddr("admin");
        OffchainAssetReceiptVault vault = createVault(admin, shareName, shareSymbol);

        // Use an always-pass authorizer so authorization is never the revert
        // cause — the nonReentrant guard is what we want to observe.
        AlwaysAuthorize alwaysAuth = new AlwaysAuthorize();
        vm.prank(admin);
        vault.setAuthorizer(alwaysAuth);

        // The receiver re-enters vault.deposit from onERC1155Received.
        ReentrantDepositReceiver reentrant =
            new ReentrantDepositReceiver(IReentrantDepositTarget(address(vault)), assets);

        // The nested deposit fires inside managerMint → onERC1155Received,
        // hits the locked nonReentrant guard, and the revert propagates to
        // the outer deposit — which therefore reverts with the same error.
        vm.prank(admin);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vault.deposit(assets, address(reentrant), 0, "");
    }

    /// Positive control: without a reentrant receiver the same deposit (under
    /// AlwaysAuthorize) succeeds — confirming the revert above is solely the
    /// reentrancy guard, not a setup issue.
    function testDepositSucceedsWithNonReentrantReceiver(
        uint256 assets,
        string memory shareName,
        string memory shareSymbol
    ) external {
        assets = bound(assets, 1, type(uint128).max);
        address admin = makeAddr("admin");
        address receiver = makeAddr("receiver");
        OffchainAssetReceiptVault vault = createVault(admin, shareName, shareSymbol);

        AlwaysAuthorize alwaysAuth2 = new AlwaysAuthorize();
        vm.prank(admin);
        vault.setAuthorizer(alwaysAuth2);

        vm.prank(admin);
        uint256 shares = vault.deposit(assets, receiver, 0, "");
        assertGt(shares, 0, "deposit must mint shares");
        assertEq(vault.balanceOf(receiver), shares, "receiver balance");
    }
}
