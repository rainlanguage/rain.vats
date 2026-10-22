// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVault, DEPOSIT, WITHDRAW} from "src/abstract/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {OffchainAssetReceiptVaultAuthorizerV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {IReceiptVaultV1} from "src/interface/IReceiptVaultV3.sol";

contract MulticallTest is OffchainAssetReceiptVaultTest {
    /// Test Mint multicall
    function testMintMulticall(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 firstMintAmount,
        uint256 secondMintAmount,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        string memory shareName,
        string memory shareSymbol
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Assume that firstMintAmount is not 0
        // Bound with uint64 max so next deposits doesnot cause overflow
        firstMintAmount = bound(firstMintAmount, 1, type(uint64).max);
        secondMintAmount = bound(secondMintAmount, 1, type(uint64).max);
        vm.assume(firstMintAmount != secondMintAmount);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        // Prank as Alice to grant roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        uint256 initialBalanceOwner = vault.balanceOf(bob);
        bytes[] memory data = new bytes[](2);

        data[0] = abi.encodeWithSelector(
            IReceiptVaultV1.mint.selector, firstMintAmount, bob, minShareRatio, receiptInformation
        );
        data[1] = abi.encodeWithSelector(
            IReceiptVaultV1.mint.selector, secondMintAmount, bob, minShareRatio, receiptInformation
        );

        uint256 totalMint = firstMintAmount + secondMintAmount;
        // Call multicall on redeem function
        vault.multicall(data);

        uint256 balanceAfterOwner = vault.balanceOf(bob);
        assertEq(balanceAfterOwner, initialBalanceOwner + totalMint);
        // Stop the prank
        vm.stopPrank();
    }

    /// Test Redeem multicall
    function testDepositMulticall(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 firstDepositAmount,
        uint256 secondDepositAmount,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        string memory shareName,
        string memory shareSymbol
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Assume that firstDepositAmount is not 0
        // Bound with uint64 max so next deposits doesnot cause overflow
        firstDepositAmount = bound(firstDepositAmount, 1, type(uint64).max);
        secondDepositAmount = bound(secondDepositAmount, 1, type(uint64).max);
        vm.assume(firstDepositAmount != secondDepositAmount);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        // Prank as Alice to grant roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        uint256 initialBalanceOwner = vault.balanceOf(bob);
        bytes[] memory data = new bytes[](2);

        data[0] = abi.encodeWithSelector(
            IReceiptVaultV1.deposit.selector, firstDepositAmount, bob, minShareRatio, receiptInformation
        );
        data[1] = abi.encodeWithSelector(
            IReceiptVaultV1.deposit.selector, secondDepositAmount, bob, minShareRatio, receiptInformation
        );

        uint256 totalMint = firstDepositAmount + secondDepositAmount;
        // Call multicall on redeem function
        vault.multicall(data);

        uint256 balanceAfterOwner = vault.balanceOf(bob);
        assertEq(balanceAfterOwner, initialBalanceOwner + totalMint);
        // Stop the prank
        vm.stopPrank();
    }

    /// Test Redeem multicall
    function testRedeemMulticall(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 firstDepositAmount,
        uint256 secondDepositAmount,
        uint256 firstRedeemAmount,
        uint256 secondRedeemAmount,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        string memory shareName,
        string memory shareSymbol
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Assume that firstDepositAmount is not 0
        // Bound with uint64 max so next deposits doesnot cause overflow
        firstDepositAmount = bound(firstDepositAmount, 1, type(uint64).max);
        secondDepositAmount = bound(secondDepositAmount, 1, type(uint64).max);
        vm.assume(firstDepositAmount != secondDepositAmount);

        firstRedeemAmount = bound(firstRedeemAmount, 1, firstDepositAmount);
        secondRedeemAmount = bound(secondRedeemAmount, 1, secondDepositAmount);

        vm.assume(firstRedeemAmount != secondRedeemAmount);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        // Prank as Alice to grant roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(WITHDRAW, bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        // Call the deposit function
        vault.deposit(firstDepositAmount, bob, minShareRatio, receiptInformation);

        // Call another deposit deposit function
        vault.deposit(secondDepositAmount, bob, minShareRatio, receiptInformation);

        uint256 initialBalanceOwner = vault.balanceOf(bob);

        bytes[] memory data = new bytes[](2);

        data[0] = abi.encodeWithSelector(IReceiptVaultV1.redeem.selector, firstDepositAmount, bob, bob, 1, "");
        data[1] = abi.encodeWithSelector(IReceiptVaultV1.redeem.selector, secondDepositAmount, bob, bob, 2, "");

        uint256 totalRedeemed = firstDepositAmount + secondDepositAmount;
        // Call multicall on redeem function
        vault.multicall(data);

        uint256 balanceAfterOwner = vault.balanceOf(bob);
        assertEq(balanceAfterOwner, initialBalanceOwner - totalRedeemed);
        // Stop the prank
        vm.stopPrank();
    }

    /// Test Withdraw multicall
    function testWithdrawMulticall(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 firstDepositAmount,
        uint256 secondDepositAmount,
        uint256 firstRedeemAmount,
        uint256 secondRedeemAmount,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        string memory shareName,
        string memory shareSymbol
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        // Assume that firstDepositAmount is not 0
        // Bound with uint64 max so next deposits doesnot cause overflow
        firstDepositAmount = bound(firstDepositAmount, 1, type(uint64).max);
        secondDepositAmount = bound(secondDepositAmount, 1, type(uint64).max);
        vm.assume(firstDepositAmount != secondDepositAmount);

        firstRedeemAmount = bound(firstRedeemAmount, 1, firstDepositAmount);
        secondRedeemAmount = bound(secondRedeemAmount, 1, secondDepositAmount);

        vm.assume(firstRedeemAmount != secondRedeemAmount);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        // Prank as Alice to grant roles
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, bob);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(WITHDRAW, bob);

        // Prank Bob for the transaction
        vm.startPrank(bob);

        // Call the deposit function
        vault.deposit(firstDepositAmount, bob, minShareRatio, receiptInformation);

        // Call another deposit deposit function
        vault.deposit(secondDepositAmount, bob, minShareRatio, receiptInformation);

        uint256 initialBalanceOwner = vault.balanceOf(bob);

        bytes[] memory data = new bytes[](2);

        data[0] = abi.encodeWithSelector(IReceiptVaultV1.withdraw.selector, firstDepositAmount, bob, bob, 1, "");
        data[1] = abi.encodeWithSelector(IReceiptVaultV1.withdraw.selector, secondDepositAmount, bob, bob, 2, "");

        uint256 totalRedeemed = firstDepositAmount + secondDepositAmount;
        // Call multicall on redeem function
        vault.multicall(data);

        uint256 balanceAfterOwner = vault.balanceOf(bob);
        assertEq(balanceAfterOwner, initialBalanceOwner - totalRedeemed);
        // Stop the prank
        vm.stopPrank();
    }
}
