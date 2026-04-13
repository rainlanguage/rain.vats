// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {InvalidId, ZeroAssetsAmount} from "src/abstract/ReceiptVault.sol";
import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault, DEPOSIT, CERTIFY} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {IReceiptVaultV1} from "src/interface/IReceiptVaultV3.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    CertificationExpired
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";

contract RedepositTest is OffchainAssetReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Checks that balance owner balance changes after withdraw
    function checkBalanceChange(
        OffchainAssetReceiptVault vault,
        address receiver,
        address owner,
        uint256 id,
        uint256 assets,
        bytes memory data
    ) internal {
        uint256 initialBalanceReceiver = vault.balanceOf(receiver);

        // Set up the event expectation for redeposit
        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(owner, receiver, assets, assets, id, data);

        // Redeposit
        vault.redeposit(assets, receiver, id, data);

        uint256 balanceAfterReceiver = vault.balanceOf(receiver);

        assertEq(balanceAfterReceiver, initialBalanceReceiver + assets);
    }

    /// Test redeposit function
    function testReDeposit(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 assets,
        uint256 assetsToRedeposit,
        bytes memory data,
        string memory shareName,
        string memory shareSymbol,
        uint256 minShareRatio,
        uint256 timestamp,
        uint256 blockNumber
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);
        // Bound assets
        assets = bound(assets, 1, type(uint256).max / 2);
        assetsToRedeposit = bound(assetsToRedeposit, 1, type(uint256).max / 2);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        // Prank as Alice to set roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.warp(timestamp);
        // Certify system till the current timestamp
        vault.certify(timestamp, false, data);

        vault.deposit(assets, bob, minShareRatio, data);

        checkBalanceChange(vault, bob, bob, 1, assetsToRedeposit, data);

        vm.stopPrank();
    }

    /// Test redeposit function reverts when assets = 0
    function testReDepositRevertsWithZeroAssets(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 assets,
        bytes memory data,
        string memory shareName,
        string memory shareSymbol,
        uint256 minShareRatio,
        uint256 timestamp,
        uint256 blockNumber
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);
        // Bound assets
        assets = bound(assets, 1, type(uint256).max / 2);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        // Prank as Alice to set roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.warp(timestamp);
        // Certify system till the current timestamp
        vault.certify(timestamp, false, data);

        vault.deposit(assets, bob, minShareRatio, data);

        vm.expectRevert(abi.encodeWithSelector(ZeroAssetsAmount.selector));

        // Redeposit
        vault.redeposit(0, bob, 1, data);

        vm.stopPrank();
    }

    /// Test redeposit to someone else reverts with certification expired
    function testReDepositToSomeoneElseReverts(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 assets,
        bytes memory data,
        string memory shareName,
        string memory shareSymbol,
        uint256 minShareRatio,
        uint256 timestamp,
        uint256 futureTimestamp,
        uint256 blockNumber
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max - 1); // Need to subtract 1 for the next bound
        futureTimestamp = bound(futureTimestamp, timestamp + 1, type(uint32).max);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        // Assume that assets are within a valid range
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, bob);
        vm.stopPrank();

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.warp(timestamp);
        // Certify system till the current timestamp
        vault.certify(timestamp, false, data);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, alice, assets, assets, 1, data);
        vault.deposit(assets, alice, minShareRatio, data);

        vm.warp(futureTimestamp);

        // Expect revert because the certification is expired
        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), alice));

        // Attempt to deposit, should revert
        vault.redeposit(assets, alice, 1, data);

        vm.stopPrank();
    }

    /// Test redeposit to someone else with Depositor role
    function testReDepositToSomeoneElse(
        uint256 aliceSeed,
        uint256 assets,
        uint256 bobSeed,
        uint256 minShareRatio,
        bytes memory data,
        string memory shareName,
        string memory shareSymbol
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Assume that assets are within a valid range
        assets = bound(assets, 1, type(uint256).max / 2);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, bob);
        vm.stopPrank();

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, alice, assets, assets, 1, data);
        vault.deposit(assets, alice, minShareRatio, data);

        checkBalanceChange(vault, alice, bob, 1, assets, data);

        vm.stopPrank();
    }

    /// Test redeposit to someone else While system is certified
    function testReDepositToSomeoneElseWhileCertified(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 assets,
        uint256 assetsToRedeposit,
        bytes memory data,
        string memory shareName,
        string memory shareSymbol,
        uint256 minShareRatio,
        uint256 timestamp,
        uint256 blockNumber
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);
        // Bound assets
        assets = bound(assets, 1, type(uint256).max / 2);
        assetsToRedeposit = bound(assetsToRedeposit, 1, type(uint256).max / 2);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        // Prank as Alice to set roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.warp(timestamp);
        // Certify system till the current timestamp
        vault.certify(timestamp, false, data);

        vault.deposit(assets, alice, minShareRatio, data);

        checkBalanceChange(vault, alice, bob, 1, assets, data);

        vm.stopPrank();
    }

    /// Test redeposit reverts on nonexistent receipt id
    function testReDepositToNonExistentReceipt(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 assets,
        bytes memory data,
        string memory shareName,
        string memory shareSymbol,
        uint256 minShareRatio,
        uint256 timestamp,
        uint256 blockNumber,
        uint256 id
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max);
        id = bound(id, 0, type(uint256).max);
        vm.assume(id != 1); // If id is 1, it will not be an invalid

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        // Assume that assets are within a valid range
        assets = bound(assets, 1, type(uint256).max / 2);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, bob);
        vm.stopPrank();

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.warp(timestamp);
        // Certify system till the current timestamp
        vault.certify(timestamp, false, data);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, alice, assets, assets, 1, data);
        vault.deposit(assets, alice, minShareRatio, data);

        // Attempt to deposit, should revert
        vm.expectRevert(abi.encodeWithSelector(InvalidId.selector, id));
        vault.redeposit(assets, alice, id, data);

        vm.stopPrank();
    }

    /// Test redepositing works after there are several IDs due to deposit
    function testReDepositOverSeveralIds(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 depositAmount,
        uint256 anotherDepositAmount,
        uint256 assetsToRedeposit,
        bytes memory data,
        string memory shareName,
        string memory shareSymbol,
        uint256 minShareRatio,
        uint256 timestamp,
        uint256 blockNumber
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);
        // Bound depositAmounts
        depositAmount = bound(depositAmount, 1, type(uint64).max);
        anotherDepositAmount = bound(anotherDepositAmount, 1, type(uint64).max);
        assetsToRedeposit = bound(assetsToRedeposit, 1, type(uint64).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        // Prank as Alice to set roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.warp(timestamp);
        // Certify system till the current timestamp
        vault.certify(timestamp, false, data);

        vault.deposit(depositAmount, bob, minShareRatio, data);
        vault.deposit(anotherDepositAmount, bob, minShareRatio, data);
        vault.deposit(anotherDepositAmount, bob, minShareRatio, data);

        checkBalanceChange(vault, alice, bob, 1, assetsToRedeposit, data);
        checkBalanceChange(vault, alice, bob, 2, assetsToRedeposit, data);

        vm.stopPrank();
    }

    /// Test redepositing reverts past the top ID
    function testReDepositrevertsPastTopID(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 depositAmount,
        uint256 anotherDepositAmount,
        uint256 assetsToRedeposit,
        bytes memory data,
        string memory shareName,
        string memory shareSymbol,
        uint256 minShareRatio,
        uint256 timestamp,
        uint256 id,
        uint256 blockNumber
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max);
        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        // Performing two deposits so Max id is gonna be 2.
        // Need to test over max id, so id is bounded from 3
        id = bound(id, 3, type(uint256).max);

        // Bound depositAmounts
        depositAmount = bound(depositAmount, 1, type(uint64).max);
        anotherDepositAmount = bound(anotherDepositAmount, 1, type(uint64).max);
        assetsToRedeposit = bound(assetsToRedeposit, 1, type(uint64).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        // Prank as Alice to set roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.warp(timestamp);
        // Certify system
        vault.certify(timestamp, false, data);

        vault.deposit(depositAmount, bob, minShareRatio, data);
        vault.deposit(anotherDepositAmount, bob, minShareRatio, data);

        // Attempt to redeposit, should revert
        vm.expectRevert(abi.encodeWithSelector(InvalidId.selector, id));
        vault.redeposit(assetsToRedeposit, alice, id, data);

        vm.stopPrank();
    }
}
