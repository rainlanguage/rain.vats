// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVault, DEPOSIT, CERTIFY} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {OffchainAssetReceiptVaultAuthorizerV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract OffchainAssetReceiptVaultERC20StandardTest is OffchainAssetReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;
    using SafeERC20 for IERC20;

    /// Test ERC20 name symbol and decimals
    function testERC20NameSymbolDecimals(uint256 aliceSeed, string memory shareName, string memory shareSymbol)
        external
    {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        vm.startPrank(alice);

        assert(address(vault) != address(0));
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(shareName)));
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(shareSymbol)));
        assertEq(vault.decimals(), 18);
    }

    /// Test ERC20 totalSupply and balanceOf
    function testERC20TotalSupplyAndBalanceOf(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 minShareRatio,
        uint256 timestamp,
        bytes memory receiptInformation
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);

        assets = bound(assets, 1, type(uint128).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, alice);

        timestamp = bound(timestamp, 1, type(uint32).max);
        vm.warp(timestamp);
        vault.certify(timestamp, false, receiptInformation);

        uint256 expectedShares = assets;
        vault.deposit(assets, alice, minShareRatio, bytes(""));
        // Assert that the total supply is equal to expectedShares
        assertEqUint(vault.totalSupply(), expectedShares);
        // Check alice balance
        assertEqUint(vault.balanceOf(alice), expectedShares);
    }

    // Test ERC20 transfer
    function testERC20Transfer(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 amount,
        uint256 minShareRatio,
        uint256 timestamp,
        bytes memory receiptInformation
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minShareRatio = bound(minShareRatio, 0, 1e18);
        vm.assume(alice != bob);
        amount = bound(amount, 1, type(uint128).max);

        // Setup vault and deposit initial balance
        OffchainAssetReceiptVault vault = createVault(alice, "Test Token", "TST");

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, alice);

        timestamp = bound(timestamp, 1, type(uint32).max);
        vm.warp(timestamp);
        vault.certify(timestamp, false, receiptInformation);

        // Mock balance and allowance for deposit
        uint256 bobInitialBalance = vault.balanceOf(bob);

        uint256 expectedShares = amount;
        vault.deposit(amount, alice, minShareRatio, bytes(""));

        assertTrue(vault.transfer(bob, expectedShares));

        // Check balances
        assertEqUint(bobInitialBalance, 0);
        assertEqUint(vault.balanceOf(bob), expectedShares);
    }

    // Test ERC20 allowance and approve
    function testERC20AllowanceAndApprove(uint256 aliceSeed, uint256 bobSeed, uint256 amount) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        vm.assume(alice != bob);

        amount = bound(amount, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, "Test Token", "TST");

        vm.startPrank(alice);
        // Set an allowance for Bob
        vault.approve(bob, amount);

        // Check allowance
        assertEq(vault.allowance(alice, bob), amount);
    }

    // Test ERC20 transferFrom()
    function testERC20TransferFrom(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 amount,
        uint256 transferFromAmount,
        uint256 minSharesRatio,
        uint256 timestamp,
        bytes memory receiptInformation
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        minSharesRatio = bound(minSharesRatio, 0, 1e18);
        vm.assume(alice != bob);
        amount = bound(amount, 1, type(uint128).max);
        transferFromAmount = bound(transferFromAmount, 1, type(uint128).max);

        OffchainAssetReceiptVault vault = createVault(alice, "Test Token", "TST");

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(CERTIFY, alice);

        timestamp = bound(timestamp, 1, type(uint32).max);
        vm.warp(timestamp);
        vault.certify(timestamp, false, receiptInformation);

        uint256 expectedShares = amount;
        vm.assume(transferFromAmount < expectedShares);

        vault.deposit(amount, alice, minSharesRatio, bytes(""));

        uint256 aliceBalanceBeforeTransfer = vault.balanceOf(alice);

        vault.approve(bob, expectedShares);

        vm.stopPrank();
        vm.startPrank(bob);

        // Bob transfers from Alice's account to his own
        assertTrue(vault.transferFrom(alice, bob, transferFromAmount));

        assertEqUint(vault.balanceOf(alice), aliceBalanceBeforeTransfer - transferFromAmount);
        assertEqUint(vault.balanceOf(bob), transferFromAmount);
        vm.stopPrank();
    }
}
