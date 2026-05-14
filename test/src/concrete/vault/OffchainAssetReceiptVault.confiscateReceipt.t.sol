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
import {Math} from "@openzeppelin-contracts-5.6.1/utils/math/Math.sol";

contract ConfiscateReceiptTest is OffchainAssetReceiptVaultTest {
    using Math for uint256;

    /// Checks that confiscateReceipt balances don't change or do change as expected
    function checkConfiscateReceipt(
        OffchainAssetReceiptVault vault,
        ReceiptContract receipt,
        address alice,
        address bob,
        uint256 id,
        uint256 targetAmount,
        bytes memory data
    ) internal {
        uint256 initialBalanceAlice = receipt.balanceOf(alice, id);
        uint256 initialBalanceBob = receipt.balanceOf(bob, id);
        bool expectNoChange = initialBalanceAlice == 0;
        uint256 expectedChange = targetAmount.min(initialBalanceAlice);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        if (!expectNoChange) {
            vm.expectEmit(false, false, false, true);
            emit OffchainAssetReceiptVault.ConfiscateReceipt(bob, alice, id, targetAmount, expectedChange, data);
        }

        vault.confiscateReceipt(alice, id, targetAmount, data);

        uint256 balanceAfterAlice = receipt.balanceOf(alice, id);
        uint256 balanceAfterBob = receipt.balanceOf(bob, id);

        bool balancesChanged = initialBalanceAlice == balanceAfterAlice && initialBalanceBob == balanceAfterBob;
        if (!expectNoChange) {
            balancesChanged = balanceAfterAlice == initialBalanceAlice - expectedChange
                && balanceAfterBob == initialBalanceBob + expectedChange;
        }

        assertTrue(balancesChanged, expectNoChange ? "Balances should not change" : "Balances should change");

        vm.stopPrank();
    }

    /// Test to checks ConfiscateReceipt does not change balances on zero balance
    function testConfiscateReceiptOnZeroBalance(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        bytes memory data,
        uint256 id,
        uint256 targetAmount
    ) external {
        vm.assume(targetAmount > 0);

        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        id = bound(id, 0, type(uint256).max);

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        ReceiptContract receipt = getReceipt(logs);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CONFISCATE_RECEIPT, bob);

        checkConfiscateReceipt(vault, receipt, alice, bob, id, targetAmount, data);
    }

    /// Test to checks ConfiscateReceipt
    function testConfiscateReceiptBasic(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 assets,
        string memory shareName,
        string memory shareSymbol,
        bytes memory data,
        uint256 certifyUntil,
        uint256 blockNumber,
        bool forceUntil,
        uint256 targetAmount
    ) external {
        vm.assume(targetAmount > 0);

        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        // Assume that assets is less than uint256 max
        assets = bound(assets, 1, type(uint256).max);

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Prank as Alice to set roles
        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CONFISCATE_RECEIPT, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, bob);

        // Prank as Bob for transactions
        vm.startPrank(bob);

        // Call the certify function
        vault.certify(certifyUntil, forceUntil, data);

        vault.deposit(assets, alice, 0, data);

        checkConfiscateReceipt(vault, getReceipt(logs), alice, bob, 1, targetAmount, data);
        vm.stopPrank();
    }
}
