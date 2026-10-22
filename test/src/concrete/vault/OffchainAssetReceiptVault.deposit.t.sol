// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {MinShareRatio, ZeroAssetsAmount, ZeroReceiver} from "src/abstract/ReceiptVault.sol";
import {
    OffchainAssetReceiptVault,
    DEPOSIT,
    CERTIFY,
    TRANSFER_SHARES,
    DepositStateChange,
    TransferSharesStateChange,
    TransferReceiptStateChange,
    Unauthorized,
    TRANSFER_RECEIPT
} from "src/abstract/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {IReceiptVaultV1} from "src/interface/IReceiptVaultV3.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    CertificationExpired
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {IReceiptV3} from "src/interface/IReceiptV3.sol";
import {IAuthorizeV1, Unauthorized} from "src/interface/IAuthorizeV1.sol";

contract OffchainAssetReceiptVaultDepositTest is OffchainAssetReceiptVaultTest {
    function checkDeposit(
        OffchainAssetReceiptVault vault,
        address owner,
        address depositor,
        address receiver,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        bytes memory err
    ) internal {
        uint256 expectedShares = assets;
        uint256 nextId = vault.highwaterId() + 1;
        uint256 sharesBefore = vault.balanceOf(receiver);

        vm.startPrank(owner);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, depositor);

        vm.stopPrank();

        vm.startPrank(depositor);

        if (err.length > 0) {
            vm.expectRevert(err);
            expectedShares = 0;
        } else if (assets == 0) {
            vm.expectRevert(abi.encodeWithSelector(ZeroAssetsAmount.selector));
            expectedShares = 0;
        } else {
            vm.expectEmit(false, false, false, true);
            emit IReceiptVaultV1.Deposit(depositor, receiver, assets, expectedShares, nextId, receiptInformation);
            if (receiptInformation.length > 0) {
                vm.expectEmit(false, false, false, true);
                emit IReceiptV3.ReceiptInformation(depositor, nextId, receiptInformation);
            }

            {
                bytes memory depositStateChange = abi.encode(
                    DepositStateChange({
                        owner: depositor,
                        receiver: receiver,
                        id: nextId,
                        assetsDeposited: assets,
                        sharesMinted: expectedShares,
                        data: receiptInformation
                    })
                );
                vm.expectCall(
                    address(vault.authorizer()),
                    abi.encodeWithSelector(IAuthorizeV1.authorize.selector, depositor, DEPOSIT, depositStateChange)
                );
            }

            {
                bytes memory transferSharesStateChange = abi.encode(
                    TransferSharesStateChange({
                        from: address(0),
                        to: receiver,
                        amount: expectedShares,
                        isCertificationExpired: vault.isCertificationExpired()
                    })
                );

                vm.expectCall(
                    address(vault.authorizer()),
                    abi.encodeWithSelector(
                        IAuthorizeV1.authorize.selector, depositor, TRANSFER_SHARES, transferSharesStateChange
                    )
                );
            }

            {
                uint256[] memory ids = new uint256[](1);
                ids[0] = nextId;
                uint256[] memory amounts = new uint256[](1);
                amounts[0] = expectedShares;

                bytes memory transferReceiptStateChange = abi.encode(
                    TransferReceiptStateChange({
                        from: address(0),
                        to: receiver,
                        ids: ids,
                        amounts: amounts,
                        isCertificationExpired: vault.isCertificationExpired()
                    })
                );

                vm.expectCall(
                    address(vault.authorizer()),
                    abi.encodeWithSelector(
                        IAuthorizeV1.authorize.selector, depositor, TRANSFER_RECEIPT, transferReceiptStateChange
                    )
                );
            }
        }

        vault.deposit(assets, receiver, minShareRatio, receiptInformation);

        vm.stopPrank();

        assertEqUint(vault.totalSupply(), vault.totalAssets());

        assertEqUint(vault.balanceOf(receiver), expectedShares + sharesBefore);

        assertEqUint(receiver == address(0) ? 0 : vault.receipt().balanceOf(receiver, nextId), expectedShares);
    }

    /// Test deposit function
    function testDepositBasic(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        string memory shareName,
        string memory shareSymbol
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);
        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        minShareRatio = bound(minShareRatio, 0, 1e18);
        checkDeposit(vault, alice, bob, bob, assets, minShareRatio, receiptInformation, "");
    }

    /// Test multiple deposits increment the ID
    function testMultipleDeposit(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 assets,
        uint256 assetsSecondDeposit,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        string memory shareName,
        string memory shareSymbol
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        // Bound assets
        assets = bound(assets, 1, type(uint256).max / 2);
        assetsSecondDeposit = bound(assetsSecondDeposit, 1, type(uint256).max / 2);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        checkDeposit(vault, alice, bob, bob, assets, minShareRatio, receiptInformation, "");
        checkDeposit(vault, alice, bob, bob, assetsSecondDeposit, minShareRatio, receiptInformation, "");
    }

    /// Test to check deposit reverts with MinShareRatio
    function testDepositMinShareRatio(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory receiptInformation
    ) external {
        minShareRatio = bound(minShareRatio, 1e18 + 1, type(uint256).max);

        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        checkDeposit(
            vault,
            alice,
            bob,
            bob,
            assets,
            minShareRatio,
            receiptInformation,
            abi.encodeWithSelector(MinShareRatio.selector, minShareRatio, 1e18)
        );
    }

    /// Test to check deposit reverts with ZeroAssetsAmount
    function testDepositWithZeroAssets(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        bytes memory receiptInformation,
        uint256 minShareRatio
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        uint256 assets = 0;

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        checkDeposit(
            vault,
            alice,
            bob,
            bob,
            assets,
            minShareRatio,
            receiptInformation,
            abi.encodeWithSelector(ZeroAssetsAmount.selector)
        );
    }

    function testDepositWithZeroReceiver(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory receiptInformation
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        checkDeposit(
            vault,
            alice,
            bob,
            address(0),
            assets,
            minShareRatio,
            receiptInformation,
            abi.encodeWithSelector(ZeroReceiver.selector)
        );
    }

    /// Test deposit to someone else reverts if system not certified
    function testDepositToSomeoneElseNotCertified(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 bobSeed,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        uint256 timestamp
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max);

        // Assume that assets is less uint256 max
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        vm.warp(timestamp);
        checkDeposit(
            vault,
            alice,
            bob,
            alice,
            assets,
            minShareRatio,
            receiptInformation,
            abi.encodeWithSelector(CertificationExpired.selector, address(0), alice)
        );
    }

    /// Test deposit to someone else reverts if system certification expired
    function testDepositToSomeoneElseExpiredCertification(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 bobSeed,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        uint256 timestamp,
        uint256 nextTimestamp,
        uint256 blockNumber
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max - 1); // Need to subtract 1 for the next bound
        nextTimestamp = bound(nextTimestamp, timestamp + 1, type(uint32).max);

        blockNumber = bound(blockNumber, 0, type(uint256).max);
        vm.roll(blockNumber);

        // Assume that assets are within a valid range
        assets = bound(assets, 1, type(uint256).max - 1);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, bob);
        vm.stopPrank();

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        vm.warp(timestamp);
        // Certify system till the current timestamp
        vault.certify(timestamp, false, receiptInformation);

        // Set nextTimestamp as timestamp
        vm.warp(nextTimestamp);

        checkDeposit(
            vault,
            alice,
            bob,
            alice,
            assets,
            minShareRatio,
            receiptInformation,
            abi.encodeWithSelector(CertificationExpired.selector, address(0), alice)
        );
    }

    /// Test deposit to someone else with DEPOSITOR role
    function testDepositToSomeoneElseWithDepositorRole(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 bobSeed,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory receiptInformation
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Assume that assets is less uint256 max
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, bob);

        vm.stopPrank();

        checkDeposit(vault, alice, alice, bob, assets, minShareRatio, receiptInformation, "");
    }

    /// Test deposit without depositor role
    function testDepositWithoutDepositorRole(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        string memory shareName,
        string memory shareSymbol,
        uint256 timestamp
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);
        timestamp = bound(timestamp, 1, type(uint32).max);

        // Assume that assets is less uint256 max
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, bob);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.warp(timestamp);
        vault.certify(timestamp, false, receiptInformation);

        vm.expectRevert(
            abi.encodeWithSelector(
                Unauthorized.selector,
                bob,
                DEPOSIT,
                abi.encode(
                    DepositStateChange({
                        owner: bob,
                        receiver: bob,
                        id: 1,
                        assetsDeposited: assets,
                        sharesMinted: assets,
                        data: receiptInformation
                    })
                )
            )
        );
        uint256 actualShares = vault.deposit(assets, bob, minShareRatio, receiptInformation);
        assertEqUint(actualShares, 0);
    }

    /// Test deposit without depositor role for admin
    function testDepositWithoutDepositorRoleForAdmin(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        string memory shareName,
        string memory shareSymbol,
        uint256 timestamp
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        timestamp = bound(timestamp, 1, type(uint32).max);

        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, bob);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.warp(timestamp);
        vault.certify(timestamp, false, receiptInformation);

        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Unauthorized.selector,
                alice,
                DEPOSIT,
                abi.encode(
                    DepositStateChange({
                        owner: alice,
                        receiver: alice,
                        id: 1,
                        assetsDeposited: assets,
                        sharesMinted: assets,
                        data: receiptInformation
                    })
                )
            )
        );
        vault.deposit(assets, alice, minShareRatio, receiptInformation);
    }
}
