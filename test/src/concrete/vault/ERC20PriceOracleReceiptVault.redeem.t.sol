// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {ZeroAssetsAmount, ZeroReceiver, ZeroOwner} from "src/abstract/ReceiptVault.sol";
import {IReceiptVaultV1} from "src/interface/IReceiptVaultV3.sol";
import {SFLR_CONTRACT} from "rain.flare/lib/sflr/LibSceptreStakedFlare.sol";
import {LibERC20PriceOracleReceiptVaultFork} from "../../../lib/LibERC20PriceOracleReceiptVaultFork.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {IERC20Errors} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract ERC20PriceOracleReceiptVaultRedeemTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Checks that balance owner balance changes after withdraw.
    function checkBalanceChange(
        ERC20PriceOracleReceiptVault vault,
        address receiver,
        address owner,
        uint256 id,
        uint256 shares,
        ReceiptContract receipt,
        bytes memory data
    ) internal {
        uint256 initialBalanceOwner = receipt.balanceOf(owner, id);
        uint256 assets = shares.fixedPointDiv(id, Math.Rounding.Floor);

        // Set up the event expectation for WithdrawWithReceipt
        vm.expectEmit(true, true, true, true);
        emit IReceiptVaultV1.Withdraw(owner, receiver, owner, assets, shares, id, data);

        // Call redeem function
        uint256 actualAssets = vault.redeem(shares, receiver, owner, id, data);
        assertEqUint(assets, actualAssets);

        uint256 balanceAfterOwner = receipt.balanceOf(owner, id);
        assertEq(balanceAfterOwner, initialBalanceOwner - shares);
    }

    /// Checks that balance owner balance does not change after redeem revert
    function checkNoBalanceChange(
        ERC20PriceOracleReceiptVault vault,
        address receiver,
        address owner,
        uint256 id,
        uint256 shares,
        ReceiptContract receipt,
        bytes memory data,
        bytes memory expectedRevertData
    ) internal {
        uint256 initialBalanceOwner;
        uint256 balanceAfterOwner;

        if (owner != address(0)) {
            initialBalanceOwner = receipt.balanceOf(owner, id);
        }

        // Check if expectedRevertData is provided
        if (expectedRevertData.length > 0) {
            vm.expectRevert(expectedRevertData);
        } else {
            vm.expectRevert();
        }
        // Call redeem function
        uint256 actualAssets = vault.redeem(shares, receiver, owner, id, data);
        assertEqUint(0, actualAssets);

        if (owner != address(0)) {
            balanceAfterOwner = receipt.balanceOf(owner, id);
        }
        assertEq(balanceAfterOwner, initialBalanceOwner);
    }

    /// Test Redeem function
    function testRedeemBasic(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 shares,
        uint256 oraclePrice
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(alice);
        // Start recording logs
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);
        ReceiptContract receipt = getReceipt();

        assets = bound(assets, 1, type(uint128).max);
        uint256 expectedAssets = assets.fixedPointMul(oraclePrice, Math.Rounding.Floor);
        vm.assume(expectedAssets > 0);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
            abi.encode(true)
        );
        vm.expectCall(address(iAsset), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets));

        uint256 depositShares = vault.deposit(assets, alice, oraclePrice, bytes(""));
        assertEqUint(depositShares, expectedAssets);

        // Bound shares with max avalilable receipt balance
        shares = bound(shares, 1, receipt.balanceOf(alice, oraclePrice));
        vm.assume(shares.fixedPointDiv(oraclePrice, Math.Rounding.Floor) > 0);
        checkBalanceChange(vault, alice, alice, oraclePrice, shares, receipt, bytes(""));
    }

    /// Test Redeem function reverts on zero shares
    function testRedeemRevertsOnZeroShares(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 oraclePrice
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(alice);
        // Start recording logs
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);
        ReceiptContract receipt = getReceipt();

        assets = bound(assets, 1, type(uint128).max);
        uint256 expectedShares = assets.fixedPointMul(oraclePrice, Math.Rounding.Floor);
        vm.assume(expectedShares > 0);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
            abi.encode(true)
        );
        vm.expectCall(address(iAsset), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets));

        uint256 depositShares = vault.deposit(assets, alice, oraclePrice, bytes(""));
        assertEqUint(depositShares, expectedShares);

        checkNoBalanceChange(
            vault, alice, alice, oraclePrice, 0, receipt, bytes(""), abi.encodeWithSelector(ZeroAssetsAmount.selector)
        );
    }

    /// Test Redeem function reverts on zero receiver
    function testRedeemRevertsOnZeroReceiver(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 shares,
        uint256 oraclePrice
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(alice);

        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);
        ReceiptContract receipt = getReceipt();

        assets = bound(assets, 1, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
            abi.encode(true)
        );
        vm.expectCall(address(iAsset), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets));

        vault.deposit(assets, alice, oraclePrice, bytes(""));

        shares = bound(shares, 1, receipt.balanceOf(alice, oraclePrice));
        vm.assume(shares.fixedPointDiv(oraclePrice, Math.Rounding.Floor) > 0);

        checkNoBalanceChange(
            vault,
            address(0),
            alice,
            oraclePrice,
            shares,
            receipt,
            bytes(""),
            abi.encodeWithSelector(ZeroReceiver.selector)
        );
    }

    /// Test Redeem function reverts on zero owner
    function testRedeemRevertsOnZeroOwner(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 shares,
        uint256 oraclePrice
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(alice);
        // Start recording logs
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);
        ReceiptContract receipt = getReceipt();

        assets = bound(assets, 1, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
            abi.encode(true)
        );

        vault.deposit(assets, alice, oraclePrice, bytes(""));

        shares = bound(shares, 1, receipt.balanceOf(alice, oraclePrice));
        vm.assume(shares.fixedPointDiv(oraclePrice, Math.Rounding.Floor) > 0);

        checkNoBalanceChange(
            vault,
            alice,
            address(0),
            oraclePrice,
            shares,
            receipt,
            bytes(""),
            abi.encodeWithSelector(ZeroOwner.selector)
        );
    }

    /// Test Redeem function with more than balance
    function testRedeemMoreThanBalance(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 sharesToRedeem,
        uint256 oraclePrice
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(alice);
        // Start recording logs
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);
        ReceiptContract receipt = getReceipt();

        assets = bound(assets, 1, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
            abi.encode(true)
        );

        vault.deposit(assets, alice, oraclePrice, bytes(""));
        uint256 availableReceiptBalance = receipt.balanceOf(alice, oraclePrice);

        // Make sure sharesToRedeem is more than available balance
        sharesToRedeem = bound(sharesToRedeem, availableReceiptBalance + 1, type(uint256).max);
        checkNoBalanceChange(vault, alice, alice, oraclePrice, sharesToRedeem, receipt, bytes(""), bytes(""));
    }

    /// forge-config: default.fuzz.runs = 1
    function testRedeemFlareFork(uint256 deposit) public {
        deposit = bound(deposit, 1, type(uint128).max);
        (ERC20PriceOracleReceiptVault vault, address alice) = LibERC20PriceOracleReceiptVaultFork.setup(vm, deposit);

        deal(address(SFLR_CONTRACT), alice, deposit);

        vm.startPrank(alice);
        uint256 rate = LibERC20PriceOracleReceiptVaultFork.getRate();
        vm.assume(vault.previewDeposit(deposit, 0) > 0);
        vault.deposit(deposit, alice, 0, hex"00");

        uint256 shareBalance = vault.balanceOf(alice);
        uint256 shares = shareBalance.fixedPointMul(rate, Math.Rounding.Ceil);

        // Call redeem function
        vault.redeem(shares, alice, alice, rate, hex"00");

        uint256 shareBalanceAft = vault.balanceOf(alice);
        assertEqUint(shareBalanceAft, shareBalance - shares);
        vm.stopPrank();
    }

    /// Test redeem with erc20 approval
    function testRedeemWithERC20Approval(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 amount,
        uint256 oraclePrice,
        uint256 redeemSharesAmount
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        vm.assume(alice != bob);
        amount = bound(amount, 1, type(uint128).max);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, "Test Token", "TST");
        ReceiptContract receipt = getReceipt();

        vm.startPrank(alice);
        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, amount),
            abi.encode(true)
        );

        uint256 expectedShares = amount.fixedPointMul(oraclePrice, Math.Rounding.Floor);
        vm.assume(expectedShares > 0);

        uint256 totalShares = vault.deposit(amount, alice, oraclePrice, bytes(""));
        assertEqUint(totalShares, expectedShares);
        redeemSharesAmount = bound(redeemSharesAmount, 1, totalShares);

        uint256 aliceBalanceBeforeTransfer = vault.balanceOf(alice);
        assertEqUint(aliceBalanceBeforeTransfer, totalShares);

        uint256 assetsAmount = vault.previewRedeem(redeemSharesAmount, oraclePrice);
        vm.assume(assetsAmount > 0);
        vm.stopPrank();

        // Bob has no allowance so he cannot withdraw.
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, 0, redeemSharesAmount)
        );
        vault.redeem(redeemSharesAmount, bob, alice, oraclePrice, bytes(""));
        vm.stopPrank();

        // Alice approves Bob to withdraw her shares.
        vm.startPrank(alice);
        vault.approve(bob, expectedShares);
        vm.stopPrank();

        // Check allowance before withdrawal
        assertEq(vault.allowance(alice, bob), expectedShares);

        // Bob still cannot withdraw because he has not been assigned as a
        // reeipt operator.
        vm.startPrank(bob);
        vm.expectRevert("ERC1155: caller is not token owner or approved");
        vault.redeem(redeemSharesAmount, bob, alice, oraclePrice, bytes(""));
        vm.stopPrank();

        // Alice makes Bob an operator.
        vm.startPrank(alice);
        receipt.setApprovalForAll(bob, true);
        vm.stopPrank();

        // Bob can now withdraw.
        vm.startPrank(bob);
        vault.redeem(redeemSharesAmount, bob, alice, oraclePrice, bytes(""));
        vm.stopPrank();
    }
}
