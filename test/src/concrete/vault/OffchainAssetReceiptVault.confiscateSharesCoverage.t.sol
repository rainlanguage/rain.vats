// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    OffchainAssetReceiptVault,
    CONFISCATE_SHARES,
    DEPOSIT,
    CERTIFY,
    ZeroConfiscateAmount
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {OffchainAssetReceiptVaultAuthorizerV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {Unauthorized} from "src/interface/IAuthorizeV1.sol";

contract ConfiscateSharesCoverageTest is OffchainAssetReceiptVaultTest {
    /// Zero target amount reverts with ZeroConfiscateAmount.
    function testConfiscateSharesZeroTargetReverts(uint256 aliceSeed, uint256 bobSeed) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        OffchainAssetReceiptVault vault = createVault(alice, "foo", "bar");

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CONFISCATE_SHARES, bob);
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ZeroConfiscateAmount.selector));
        vault.confiscateShares(alice, 0, "");
    }

    /// Partial confiscation: target > balance caps at balance.
    function testConfiscateSharesPartialCapsAtBalance(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 depositAmount,
        uint256 targetAmount
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        depositAmount = bound(depositAmount, 1, 1e27);
        targetAmount = bound(targetAmount, depositAmount + 1, type(uint128).max);

        OffchainAssetReceiptVault vault = createVault(alice, "foo", "bar");

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CONFISCATE_SHARES, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, alice);
        vault.certify(block.timestamp + 1, false, "");
        vault.deposit(depositAmount, alice, 0, "");
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), depositAmount);

        vm.prank(bob);
        uint256 confiscated = vault.confiscateShares(alice, targetAmount, "over-confiscation");

        assertEq(confiscated, depositAmount, "should cap at balance");
        assertEq(vault.balanceOf(alice), 0, "alice should have nothing left");
        assertEq(vault.balanceOf(bob), depositAmount, "bob gets the confiscated amount");
    }

    /// Unauthorized confiscator reverts.
    function testConfiscateSharesUnauthorizedReverts(uint256 aliceSeed, uint256 bobSeed) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        OffchainAssetReceiptVault vault = createVault(alice, "foo", "bar");

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, alice);
        vault.certify(block.timestamp + 1, false, "");
        vault.deposit(100, alice, 0, "");
        vm.stopPrank();

        vm.prank(bob);
        vm.expectRevert();
        vault.confiscateShares(alice, 50, "unauthorized");
    }

    /// Confiscation works even when vault is frozen (certification expired).
    function testConfiscateSharesBypassesFreeze(uint256 aliceSeed, uint256 bobSeed, uint256 depositAmount) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        depositAmount = bound(depositAmount, 1, 1e27);

        OffchainAssetReceiptVault vault = createVault(alice, "foo", "bar");

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CONFISCATE_SHARES, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, alice);
        vault.certify(block.timestamp + 1, false, "");
        vault.deposit(depositAmount, alice, 0, "");
        vm.stopPrank();

        // Warp past certification — vault is now frozen.
        vm.warp(block.timestamp + 2);

        // Normal transfer should fail while frozen.
        vm.prank(alice);
        vm.expectRevert();
        vault.transfer(bob, 1);

        // Confiscation should still work.
        vm.prank(bob);
        uint256 confiscated = vault.confiscateShares(alice, depositAmount, "frozen confiscation");

        assertEq(confiscated, depositAmount, "confiscation should succeed during freeze");
        assertEq(vault.balanceOf(bob), depositAmount, "bob gets confiscated shares");
    }
}
