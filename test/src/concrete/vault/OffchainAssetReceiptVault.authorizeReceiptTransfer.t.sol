// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault, CONFISCATE_RECEIPT, CERTIFY} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    CertificationExpired
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {UnmanagedReceiptTransfer} from "src/interface/IReceiptManagerV2.sol";

contract OffchainAssetReceiptVaultAuthorizeReceiptTransferTest is OffchainAssetReceiptVaultTest {
    /// Test AuthorizeReceiptTransfer reverts if the caller is not the managed
    /// receipt.
    function testAuthorizeReceiptTransferNotManaged(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 timestamp,
        string memory shareName,
        string memory shareSymbol,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        // Bound timestamp from 1 to avoid potential issues with timestamp 0.
        timestamp = bound(timestamp, 1, type(uint32).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Warp the block timestamp to a non-zero value.
        vm.warp(timestamp);

        // Prank as receipt for the authorization.
        vm.startPrank(address(vault.receipt()));

        // The certification is expired.
        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, bob, alice));
        vault.authorizeReceiptTransfer3(bob, bob, alice, ids, amounts);

        vm.stopPrank();

        // Certify the vault so the authorization can be successful.
        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, alice);
        vault.certify(timestamp, false, "");
        vm.stopPrank();

        // Attempt to authorize receipt transfer, should NOT revert.
        vm.startPrank(address(vault.receipt()));
        vault.authorizeReceiptTransfer3(bob, bob, alice, ids, amounts);
        vm.stopPrank();

        // Attempt to authorize receipt transfer as anyone else, should revert.
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(UnmanagedReceiptTransfer.selector));
        vault.authorizeReceiptTransfer3(bob, bob, alice, ids, amounts);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(UnmanagedReceiptTransfer.selector));
        vault.authorizeReceiptTransfer3(bob, bob, alice, ids, amounts);
    }

    /// Test AuthorizeReceiptTransfer reverts if system certification is expired
    function testAuthorizeReceiptTransferRevertExpiredCertification(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 timestamp,
        uint256 nextTimestamp,
        uint256 blockNumber,
        bytes memory data,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        // Bound timestamp from 1 to avoid potential issues with timestamp 0.
        timestamp = bound(timestamp, 1, type(uint32).max - 1); // Need to subtract 1 for the next bound
        nextTimestamp = bound(nextTimestamp, timestamp + 1, type(uint32).max);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.warp(timestamp);

        // Expect the Certify event
        vm.expectEmit(false, false, false, true);
        emit OffchainAssetReceiptVault.Certify(bob, timestamp, false, data);

        vault.certify(timestamp, false, data);

        vm.startPrank(address(vault.receipt()));
        vault.authorizeReceiptTransfer3(bob, bob, alice, ids, amounts);

        // Set nextTimestamp as timestamp
        vm.warp(nextTimestamp);

        vm.startPrank(address(vault.receipt()));

        // Attempt to authorize receipt transfer, should revert
        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, bob, alice));
        vault.authorizeReceiptTransfer3(bob, bob, alice, ids, amounts);

        vm.stopPrank();
    }

    /// Test AuthorizeReceiptTransfer does not revert without certification if
    /// it is a confiscation.
    function testAuthorizeReceiptTransferForConfiscator(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 carolSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        (address alice, address bob, address carol) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed, carolSeed);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CONFISCATE_RECEIPT, bob);

        vm.startPrank(address(vault.receipt()));

        // Attempt to authorize receipt transfer, should revert for alice as
        // operator.
        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, alice, carol));
        vault.authorizeReceiptTransfer3(alice, alice, carol, ids, amounts);

        // Attempt to authorize receipt transfer, should NOT revert for bob as
        // operator.
        vault.authorizeReceiptTransfer3(bob, alice, carol, ids, amounts);

        vm.startPrank(alice);
        // Grant confiscate role to alice.
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CONFISCATE_RECEIPT, alice);

        vm.startPrank(address(vault.receipt()));

        // Attempt to authorize receipt transfer, should NOT revert for alice as
        // operator.
        vault.authorizeReceiptTransfer3(alice, alice, carol, ids, amounts);

        // From confiscator to non confiscator is allowed.
        vault.authorizeReceiptTransfer3(alice, bob, carol, ids, amounts);
        // From confiscator to confiscator is allowed.
        vault.authorizeReceiptTransfer3(alice, bob, alice, ids, amounts);
        vault.authorizeReceiptTransfer3(alice, bob, bob, ids, amounts);
        // From non confiscator to confiscator is allowed.
        vault.authorizeReceiptTransfer3(alice, carol, bob, ids, amounts);
    }

    /// Test AuthorizeReceiptTransfer does not revert without certification if To has a confiscator role
    function testAuthorizeReceiptTransferForConfiscatorTo(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CONFISCATE_RECEIPT, alice);

        vm.startPrank(address(vault.receipt()));

        // To the confiscator is allowed.
        vault.authorizeReceiptTransfer3(alice, bob, alice, ids, amounts);
        vault.authorizeReceiptTransfer3(alice, alice, alice, ids, amounts);

        // From the confiscator is allowed.
        vault.authorizeReceiptTransfer3(alice, alice, bob, ids, amounts);
        vault.authorizeReceiptTransfer3(alice, bob, bob, ids, amounts);
    }
}
