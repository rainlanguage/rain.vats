// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {
    OffchainAssetReceiptVault,
    CONFISCATE_RECEIPT,
    CONFISCATE_SHARES,
    CERTIFY,
    CertifyStateChange,
    DepositStateChange,
    ConfiscateSharesStateChange,
    ConfiscateReceiptStateChange
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    Unauthorized,
    CERTIFY_ADMIN,
    CONFISCATE_RECEIPT_ADMIN,
    CONFISCATE_SHARES_ADMIN,
    DEPOSIT_ADMIN,
    WITHDRAW_ADMIN,
    DEPOSIT,
    WITHDRAW,
    CERTIFY,
    CONFISCATE_RECEIPT,
    CONFISCATE_SHARES
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";

contract RolesTest is OffchainAssetReceiptVaultTest {
    /// Test to checks Admin roles granted
    function testGrantAdminRoles(uint256 aliceSeed, string memory shareName, string memory shareSymbol) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        assertTrue(OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).hasRole(DEPOSIT_ADMIN, alice));
        assertTrue(OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).hasRole(WITHDRAW_ADMIN, alice));
        assertTrue(OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).hasRole(CERTIFY_ADMIN, alice));
        assertTrue(
            OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).hasRole(CONFISCATE_RECEIPT_ADMIN, alice)
        );
        assertTrue(
            OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).hasRole(CONFISCATE_SHARES_ADMIN, alice)
        );

        assertTrue(!OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).hasRole(DEPOSIT, alice));
        assertTrue(!OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).hasRole(WITHDRAW, alice));
        assertTrue(!OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).hasRole(CERTIFY, alice));
        assertTrue(
            !OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).hasRole(CONFISCATE_RECEIPT, alice)
        );
        assertTrue(
            !OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).hasRole(CONFISCATE_SHARES, alice)
        );
    }

    /// Test to checks deposit without depositor role
    function testDepositWithoutDepositorRole(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 aliceAssets,
        bytes memory receiptInformation
    ) external {
        vm.assume(aliceAssets > 0);

        // ShareRatio 1
        uint256 shareRatio = 1e18;
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Certify the vault so we see the role check.
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, alice);
        vault.certify(block.timestamp, false, "");

        vm.expectRevert(
            abi.encodeWithSelector(
                Unauthorized.selector,
                alice,
                DEPOSIT,
                abi.encode(
                    DepositStateChange({
                        owner: alice,
                        receiver: bob,
                        id: 1,
                        assetsDeposited: aliceAssets,
                        sharesMinted: aliceAssets,
                        data: receiptInformation
                    })
                )
            )
        );
        vault.deposit(aliceAssets, bob, shareRatio, receiptInformation);
        vm.stopPrank();
    }

    /// Test to checks Certify without role
    function testCertifyWithoutRole(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 certifyUntil,
        bytes memory data
    ) external {
        vm.assume(certifyUntil > 0);
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        bool forceUntil = false;

        vm.expectRevert(
            abi.encodeWithSelector(
                Unauthorized.selector,
                alice,
                CERTIFY,
                abi.encode(
                    CertifyStateChange({
                        oldCertifiedUntil: 0,
                        newCertifiedUntil: certifyUntil,
                        userCertifyUntil: certifyUntil,
                        forceUntil: forceUntil,
                        data: data
                    })
                )
            )
        );

        // Call the certify function
        vault.certify(certifyUntil, forceUntil, data);

        vm.stopPrank();
    }

    /// Test to checks confiscate receipt without role
    function testConfiscateReceiptWithoutRole(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 id,
        uint256 targetAmount,
        bytes memory data
    ) external {
        vm.assume(targetAmount > 0);

        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                Unauthorized.selector,
                alice,
                CONFISCATE_RECEIPT,
                abi.encode(
                    ConfiscateReceiptStateChange({
                        confiscatee: alice, id: id, targetAmount: targetAmount, actualAmount: 0, data: data
                    })
                )
            )
        );

        // Call the confiscateReceipt function
        vault.confiscateReceipt(alice, id, targetAmount, data);

        vm.stopPrank();
    }

    /// Test to checks confiscate shares without role
    function testConfiscateSharesWithoutRole(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 targetAmount,
        bytes memory data
    ) external {
        vm.assume(targetAmount > 0);

        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                Unauthorized.selector,
                alice,
                CONFISCATE_SHARES,
                abi.encode(
                    ConfiscateSharesStateChange({
                        confiscatee: alice, targetAmount: targetAmount, actualAmount: 0, data: data
                    })
                )
            )
        );

        // Call the confiscateShares function
        vault.confiscateShares(alice, targetAmount, data);

        vm.stopPrank();
    }
}
