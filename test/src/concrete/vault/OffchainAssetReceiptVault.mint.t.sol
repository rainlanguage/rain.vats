// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {MinShareRatio, ZeroAssetsAmount, ZeroReceiver} from "src/abstract/ReceiptVault.sol";
import {
    OffchainAssetReceiptVault,
    TransferSharesStateChange,
    DEPOSIT,
    CERTIFY,
    TRANSFER_SHARES,
    TRANSFER_RECEIPT,
    DepositStateChange,
    TransferReceiptStateChange,
    Unauthorized
} from "src/abstract/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {IReceiptVaultV1} from "src/interface/IReceiptVaultV3.sol";
import {IReceiptV3} from "src/interface/IReceiptV3.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    CertificationExpired
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {IAuthorizeV1, Unauthorized} from "src/interface/IAuthorizeV1.sol";

contract OffchainAssetReceiptVaultDepositTest is OffchainAssetReceiptVaultTest {
    function checkMint(
        OffchainAssetReceiptVault vault,
        address minter,
        address receiver,
        uint256 shares,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        bytes memory err
    ) internal {
        uint256 expectedAssets = shares;
        uint256 expectedId = vault.highwaterId() + 1;

        // Prank as Alice to grant role
        vm.startPrank(vault.owner());

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, minter);

        vm.stopPrank();

        // Prank as Bob for transaction
        vm.startPrank(minter);

        if (err.length > 0) {
            vm.expectRevert(err);
            expectedAssets = 0;
        } else {
            vm.expectEmit(false, false, false, true);
            emit IReceiptVaultV1.Deposit(minter, receiver, expectedAssets, shares, expectedId, receiptInformation);
            if (receiptInformation.length > 0) {
                vm.expectEmit(false, false, false, true);
                emit IReceiptV3.ReceiptInformation(minter, expectedId, receiptInformation);
            }
            vm.expectCall(
                address(vault.authorizer()),
                abi.encodeWithSelector(
                    IAuthorizeV1.authorize.selector,
                    minter,
                    DEPOSIT,
                    abi.encode(
                        DepositStateChange({
                            owner: minter,
                            receiver: receiver,
                            id: expectedId,
                            assetsDeposited: shares,
                            sharesMinted: shares,
                            data: receiptInformation
                        })
                    )
                )
            );

            bytes memory transferSharesStateChange = abi.encode(
                TransferSharesStateChange({
                    from: address(0),
                    to: receiver,
                    amount: shares,
                    isCertificationExpired: vault.isCertificationExpired()
                })
            );

            vm.expectCall(
                address(vault.authorizer()),
                abi.encodeWithSelector(
                    IAuthorizeV1.authorize.selector, minter, TRANSFER_SHARES, transferSharesStateChange
                )
            );

            uint256[] memory ids = new uint256[](1);
            ids[0] = expectedId;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = shares;

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
                    IAuthorizeV1.authorize.selector, minter, TRANSFER_RECEIPT, transferReceiptStateChange
                )
            );
        }

        uint256 actualAssets = vault.mint(shares, receiver, minShareRatio, receiptInformation);

        // Assert that the total supply and total assets are equal after the mint
        assertEqUint(vault.totalSupply(), vault.totalAssets());

        assertEqUint(actualAssets, expectedAssets);

        vm.stopPrank();
    }

    /// Test mint function
    function testMintBasic(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 shares,
        bytes memory receiptInformation,
        uint256 minShareRatio
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);

        shares = bound(shares, 1, type(uint256).max);

        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        checkMint(vault, bob, bob, shares, minShareRatio, receiptInformation, "");
    }

    /// Test multiple mint increments the ID
    function testMultipleMints(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 shares,
        uint256 sharesSecondMint,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        string memory shareName,
        string memory shareSymbol
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        // Bound shares
        shares = bound(shares, 1, type(uint256).max / 2);
        sharesSecondMint = bound(sharesSecondMint, 1, type(uint256).max / 2);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        checkMint(vault, bob, bob, shares, minShareRatio, receiptInformation, "");
        checkMint(vault, bob, bob, sharesSecondMint, minShareRatio, receiptInformation, "");
    }

    /// Test to check mint reverts with MinShareRatio
    function testMintWithMinShareRatio(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 shares,
        uint256 minShareRatio,
        bytes memory receiptInformation
    ) external {
        minShareRatio = bound(minShareRatio, 1e18 + 1, type(uint256).max);
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        shares = bound(shares, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        checkMint(
            vault,
            bob,
            bob,
            shares,
            minShareRatio,
            receiptInformation,
            abi.encodeWithSelector(MinShareRatio.selector, minShareRatio, 1e18)
        );
    }

    /// Test to check mint reverts with ZeroAssetsAmount
    function testZeroAssetsAmount(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        bytes memory receiptInformation,
        uint256 minShareRatio
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        checkMint(
            vault, bob, bob, 0, minShareRatio, receiptInformation, abi.encodeWithSelector(ZeroAssetsAmount.selector)
        );
    }

    function testZeroReceiver(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 shares,
        uint256 minShareRatio,
        bytes memory receiptInformation
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);

        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        shares = bound(shares, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        checkMint(
            vault,
            bob,
            address(0),
            shares,
            minShareRatio,
            receiptInformation,
            abi.encodeWithSelector(ZeroReceiver.selector)
        );
    }

    /// Test mint to someone else reverts if system not certified
    function testMintToSomeoneElseNotCertified(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 bobSeed,
        uint256 shares,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        uint256 timestamp
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max);

        // Assume that shares is less uint256 max
        shares = bound(shares, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        vm.warp(timestamp);

        checkMint(
            vault,
            bob,
            alice,
            shares,
            minShareRatio,
            receiptInformation,
            abi.encodeWithSelector(CertificationExpired.selector, address(0), alice)
        );
    }

    /// Test mint to someone else reverts if system certification expired
    function testMintToSomeoneElseExpiredCertification(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 bobSeed,
        uint256 shares,
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

        // Assume that shares are within a valid range
        shares = bound(shares, 1, type(uint256).max - 1);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, alice);

        vm.warp(timestamp);
        vault.certify(timestamp, false, receiptInformation);

        vm.warp(nextTimestamp);
        vm.stopPrank();

        checkMint(
            vault,
            bob,
            alice,
            shares,
            minShareRatio,
            receiptInformation,
            abi.encodeWithSelector(CertificationExpired.selector, address(0), alice)
        );
    }

    /// Test mint to someone else with DEPOSITOR role
    function testMintToSomeoneElseWithDepositorRole(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 bobSeed,
        uint256 shares,
        uint256 minShareRatio,
        bytes memory receiptInformation
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Assume that shares is less uint256 max
        shares = bound(shares, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);
        vm.stopPrank();

        checkMint(vault, bob, alice, shares, minShareRatio, receiptInformation, "");
    }

    /// Test mint without depositor role
    function testMintWithoutDepositorRole(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 shares,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        string memory shareName,
        string memory shareSymbol,
        uint256 timestamp
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);
        timestamp = bound(timestamp, 1, type(uint32).max);
        shares = bound(shares, 1, type(uint256).max);

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
                        assetsDeposited: shares,
                        sharesMinted: shares,
                        data: receiptInformation
                    })
                )
            )
        );
        uint256 actualAssets = vault.mint(shares, bob, minShareRatio, receiptInformation);
        assertEqUint(actualAssets, 0);
    }

    /// Test mint without depositor role for admin
    function testMintWithoutDepositorRoleForAdmin(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 shares,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        string memory shareName,
        string memory shareSymbol,
        uint256 timestamp
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        timestamp = bound(timestamp, 1, type(uint32).max);
        shares = bound(shares, 1, type(uint256).max);

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
                        assetsDeposited: shares,
                        sharesMinted: shares,
                        data: receiptInformation
                    })
                )
            )
        );
        vault.mint(shares, alice, minShareRatio, receiptInformation);

        vm.stopPrank();
    }
}
