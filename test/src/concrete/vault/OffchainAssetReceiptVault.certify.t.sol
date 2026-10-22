// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    OffchainAssetReceiptVault,
    ZeroCertifyUntil,
    DEPOSIT,
    CERTIFY
} from "src/abstract/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {IReceiptVaultV1} from "src/interface/IReceiptVaultV3.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    CertificationExpired
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";

contract OffchainAssetReceiptVaultCertifyTest is OffchainAssetReceiptVaultTest {
    /// Test certify event
    function testCertify(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 certifyUntil,
        bytes memory data,
        uint256 blockNumber,
        bool forceUntil
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        vm.roll(blockNumber);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        // Grant CERTIFIER role to Bob
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        // Expect the Certify event
        vm.expectEmit(false, false, false, true);
        emit OffchainAssetReceiptVault.Certify(bob, certifyUntil, forceUntil, data);

        // Call the certify function
        vault.certify(certifyUntil, forceUntil, data);

        vm.stopPrank();
    }

    /// Test certify reverts on zero certify until
    function testCertifyRevertOnZeroCertifyUntil(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        bytes memory data,
        uint256 blockNumber,
        bool forceUntil
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        vm.roll(blockNumber);

        uint256 certifyUntil = 0;

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice to grant role
        vm.startPrank(alice);

        // Grant CERTIFIER role to Bob
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        // Expect to revert
        vm.expectRevert(abi.encodeWithSelector(ZeroCertifyUntil.selector));

        // Call the certify function
        vault.certify(certifyUntil, forceUntil, data);

        vm.stopPrank();
    }

    /// Test certify with force until true
    function testCertifyWithForceUntilTrue(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 assets,
        bytes memory data,
        string memory shareName,
        string memory shareSymbol,
        uint256 minShareRatio,
        uint256 timestamp,
        uint256 forceCertifyUntil,
        uint256 blockNumber
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max); // Need to subtract 1 for the next bound
        forceCertifyUntil = bound(forceCertifyUntil, 1, type(uint32).max);

        vm.assume(forceCertifyUntil != timestamp);
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

        vm.expectEmit(false, false, false, true);
        emit OffchainAssetReceiptVault.Certify(bob, timestamp, false, data);

        // Certify system till the current timestamp
        vault.certify(timestamp, false, data);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, alice, assets, assets, 1, data);
        vault.deposit(assets, alice, minShareRatio, data);

        vm.warp(forceCertifyUntil);

        vm.expectEmit(false, false, false, true);
        emit OffchainAssetReceiptVault.Certify(bob, forceCertifyUntil, true, data);

        // Certify system till the current timestamp
        vault.certify(forceCertifyUntil, true, data);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, alice, assets, assets, 2, data);
        vault.deposit(assets, alice, minShareRatio, data);

        vm.stopPrank();
    }

    /// Test certify with force until true revert deposit
    function testCertifyWithForceUntilTrueRevertDeposit(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory data,
        uint256 certifyUntil,
        uint256 forceCertifyUntil,
        uint256 futureTime
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        certifyUntil = bound(certifyUntil, 1, type(uint32).max);
        forceCertifyUntil = bound(forceCertifyUntil, 1, type(uint32).max);

        futureTime = bound(futureTime, forceCertifyUntil + 1, type(uint256).max);
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

        // Certify system till the current timestamp
        vault.certify(certifyUntil, false, data);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, alice, assets, assets, 1, data);
        vault.deposit(assets, alice, minShareRatio, data);

        // Expect the Certify event
        vm.expectEmit(false, false, false, true);
        emit OffchainAssetReceiptVault.Certify(bob, forceCertifyUntil, true, data);

        // Certify with forceUntil true
        vault.certify(forceCertifyUntil, true, data);
        vm.warp(futureTime);

        // Expect revert because the certification is expired
        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), alice));

        // Attempt to deposit, should revert
        vault.deposit(assets, alice, minShareRatio, data);

        vm.stopPrank();
    }

    /// Test to checks vault certifiedUntil is definitely updated and vault gets certified
    function testVaultGetsCertified(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 minShareRatio,
        uint256 assets,
        string memory shareName,
        string memory shareSymbol,
        bytes memory data,
        uint256 certifyUntil,
        uint256 blockNumber,
        bool forceUntil
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);

        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        // Assume that assets is less uint256 max
        assets = bound(assets, 1, type(uint256).max);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        certifyUntil = bound(certifyUntil, 1, type(uint32).max);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);
        // Call the certify function
        vault.certify(certifyUntil, forceUntil, data);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.Deposit(bob, alice, assets, assets, 1, data);
        vault.deposit(assets, alice, minShareRatio, data);

        vm.stopPrank();
    }
}
