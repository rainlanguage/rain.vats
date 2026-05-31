// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    OffchainAssetReceiptVault,
    CONFISCATE_RECEIPT,
    DEPOSIT,
    CERTIFY
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {OffchainAssetReceiptVaultAuthorizerV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {CertificationExpired} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";

/// @title ConfiscateReceiptCertExpiredTest
/// @notice End-to-end regression for the #309 fix's most safety-critical
/// PRESERVED behavior: confiscation must keep working while the system's
/// certification is EXPIRED. During expiry the authorizer only permits a receipt
/// transfer if `hasRole(CONFISCATE_RECEIPT, operator)`, where `operator` is the
/// identity the receipt forwards from `managerTransferFrom`. The fix forwards the
/// explicit confiscator (`_msgSender()` of `confiscateReceipt`) as that operator;
/// a naive fix that forwarded the vault (the receipt's `msg.sender`) instead
/// would fail the role check and revert `CertificationExpired`, breaking legal
/// confiscation during a freeze. These tests pin that down through the real
/// `OffchainAssetReceiptVault`. The existing `confiscateReceipt` suite only ever
/// runs while certified (default timestamp), so this path was uncovered.
contract ConfiscateReceiptCertExpiredTest is OffchainAssetReceiptVaultTest {
    /// Funds `confiscatee` with a receipt while certified, then expires the
    /// certification. Returns the deployed vault and its receipt. `confiscator`
    /// holds CONFISCATE_RECEIPT; `agent` (the caller) holds DEPOSIT + CERTIFY.
    function _setupExpired(address admin, address agent, address confiscator, uint256 assets)
        internal
        returns (OffchainAssetReceiptVault vault, ReceiptContract receipt)
    {
        vm.warp(1000);

        vm.recordLogs();
        vault = createVault(admin, "Offchain", "OFF");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        receipt = getReceipt(logs);

        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer()));
        vm.startPrank(admin);
        authorizer.grantRole(CONFISCATE_RECEIPT, confiscator);
        authorizer.grantRole(DEPOSIT, agent);
        authorizer.grantRole(CERTIFY, agent);
        vm.stopPrank();

        // Certify into the future, deposit while certified (mints receipt id 1 to
        // the confiscatee), then warp past the certification so the system is
        // frozen for ordinary transfers.
        vm.startPrank(agent);
        vault.certify(2000, false, "");
        vault.deposit(assets, admin, 0, "");
        vm.stopPrank();

        vm.warp(3000);
        assertTrue(vault.isCertificationExpired(), "system should be frozen");
    }

    /// A confiscator CAN confiscate a receipt during certification expiry: the
    /// receipt forwards the confiscator as the authorization operator, so the
    /// CONFISCATE_RECEIPT bypass applies and the receipt moves to the confiscator.
    function testConfiscateReceiptDuringCertExpirySucceeds(uint256 aliceSeed, uint256 bobSeed, uint256 assets)
        external
    {
        assets = bound(assets, 1, type(uint128).max);
        (address admin, address confiscator) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        // The admin is the confiscatee here (receipts were minted to it); the
        // agent role-holder is also the admin for deposit/certify simplicity.
        (OffchainAssetReceiptVault vault, ReceiptContract receipt) = _setupExpired(admin, admin, confiscator, assets);

        uint256 id = 1;
        uint256 confiscateeBefore = receipt.balanceOf(admin, id);
        assertEq(confiscateeBefore, assets, "confiscatee funded while certified");

        // Confiscation while frozen succeeds — the operator is the confiscator.
        vm.prank(confiscator);
        uint256 actual = vault.confiscateReceipt(admin, id, assets, "");

        assertEq(actual, assets, "full balance confiscated");
        assertEq(receipt.balanceOf(admin, id), 0, "confiscatee drained");
        assertEq(receipt.balanceOf(confiscator, id), assets, "confiscator received the receipt");
    }

    /// A caller WITHOUT the CONFISCATE_RECEIPT role cannot confiscate during
    /// expiry: the receipt forwards that caller as the operator, the bypass does
    /// not apply, and the transfer reverts `CertificationExpired`. This confirms
    /// the bypass is keyed on the forwarded operator identity, not granted
    /// blanket by the fix.
    function testNonConfiscatorCannotConfiscateDuringCertExpiry(uint256 aliceSeed, uint256 bobSeed, uint256 assets)
        external
    {
        assets = bound(assets, 1, type(uint128).max);
        (address admin, address confiscator) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        (OffchainAssetReceiptVault vault,) = _setupExpired(admin, admin, confiscator, assets);

        // `admin` holds DEPOSIT/CERTIFY but NOT CONFISCATE_RECEIPT, so its
        // confiscation attempt during expiry is rejected by the transfer authz.
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, admin, admin));
        vault.confiscateReceipt(admin, 1, assets, "");
    }
}
