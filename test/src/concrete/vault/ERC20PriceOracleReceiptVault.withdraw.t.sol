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
import {IERC1155Errors} from "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import {IERC20Errors} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract ERC20PriceOracleReceiptVaultWithdrawTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Checks that balance owner balance changes after wirthdraw
    function checkBalanceChange(
        ERC20PriceOracleReceiptVault vault,
        address receiver,
        address owner,
        uint256 id,
        uint256 assets,
        ReceiptContract receipt,
        bytes memory data
    ) internal {
        uint256 initialBalanceOwner = receipt.balanceOf(owner, id);
        uint256 shares = assets.fixedPointMul(id, Math.Rounding.Ceil);

        vm.expectEmit(true, true, true, true);
        emit IReceiptVaultV1.Withdraw(owner, receiver, owner, assets, shares, id, data);

        // Call withdraw function
        vault.withdraw(assets, receiver, owner, id, data);

        uint256 balanceAfterOwner = receipt.balanceOf(owner, id);
        assertEq(balanceAfterOwner, initialBalanceOwner - shares);
    }

    /// Checks that balance owner balance does not change after wirthdraw revert
    function checkNoBalanceChange(
        ERC20PriceOracleReceiptVault vault,
        address receiver,
        address owner,
        uint256 id,
        uint256 assets,
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
        // Call withdraw function
        vault.withdraw(assets, receiver, owner, id, data);

        if (owner != address(0)) {
            balanceAfterOwner = receipt.balanceOf(owner, id);
        }
        assertEq(balanceAfterOwner, initialBalanceOwner);
    }

    /// Test Withdraw function
    function testWithdrawBasic(
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

        assets = bound(assets, 2, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
            abi.encode(true)
        );
        vm.expectCall(address(iAsset), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets));

        vault.deposit(assets, alice, oraclePrice, bytes(""));
        uint256 withdrawAssets =
            assets.fixedPointMul(oraclePrice, Math.Rounding.Floor).fixedPointDiv(oraclePrice, Math.Rounding.Floor);
        checkBalanceChange(vault, alice, alice, oraclePrice, withdrawAssets, receipt, bytes(""));
    }

    /// Test Withdraw function reverts on zero assets
    function testWithdrawRevertsOnZeroAssets(
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
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
            abi.encode(true)
        );
        vm.expectCall(address(iAsset), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets));

        vault.deposit(assets, alice, oraclePrice, bytes(""));

        checkNoBalanceChange(
            vault, alice, alice, oraclePrice, 0, receipt, bytes(""), abi.encodeWithSelector(ZeroAssetsAmount.selector)
        );
    }

    /// Test Withdraw function reverts on zero receiver
    function testWithdrawRevertsOnZeroReceiver(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 oraclePrice
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        oraclePrice = bound(oraclePrice, 0.001e18, 100e18);
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
        vm.expectCall(address(iAsset), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets));

        vault.deposit(assets, alice, oraclePrice, bytes(""));
        uint256 availableReceiptBalance = receipt.balanceOf(alice, oraclePrice);

        checkNoBalanceChange(
            vault,
            address(0),
            alice,
            oraclePrice,
            availableReceiptBalance,
            receipt,
            bytes(""),
            abi.encodeWithSelector(ZeroReceiver.selector)
        );
    }

    /// Test Withdraw function reverts on zero owner
    function testWithdrawRevertsOnZeroOwner(
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
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
            abi.encode(true)
        );
        vm.expectCall(address(iAsset), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets));

        vault.deposit(assets, alice, oraclePrice, bytes(""));
        uint256 availableReceiptBalance = receipt.balanceOf(alice, oraclePrice);

        checkNoBalanceChange(
            vault,
            alice,
            address(0),
            oraclePrice,
            availableReceiptBalance,
            receipt,
            bytes(""),
            abi.encodeWithSelector(ZeroOwner.selector)
        );
    }

    /// Test alice attempting to burn bob's ID when the price is different.
    function testWithdrawAliceBurnBob(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 alicePrice,
        uint256 bobPrice,
        uint256 aliceDeposit,
        uint256 bobDeposit
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        alicePrice = bound(alicePrice, 1e18, 100e18);
        bobPrice = bound(bobPrice, 1e18, 100e18);
        aliceDeposit = bound(aliceDeposit, 100e18, type(uint128).max);
        bobDeposit = bound(bobDeposit, 100e18, type(uint128).max);

        vm.assume(alicePrice != bobPrice);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, "Alice", "Alice");

        // Alice deposits so that she receives ERC20 shares under her receipt.
        setVaultOraclePrice(alicePrice);

        vm.startPrank(alice);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, aliceDeposit),
            abi.encode(true)
        );
        vm.expectCall(
            address(iAsset), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, aliceDeposit)
        );

        vault.deposit(aliceDeposit, alice, alicePrice, bytes(""));
        vm.stopPrank();

        // Bob deposits so that he receives ERC20 shares under his receipt.
        setVaultOraclePrice(bobPrice);

        vm.startPrank(bob);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, bob, vault, bobDeposit),
            abi.encode(true)
        );
        vm.expectCall(address(iAsset), abi.encodeWithSelector(IERC20.transferFrom.selector, bob, vault, bobDeposit));

        uint256 bobExpectedSharesAfterActions;
        {
            uint256 bobSharesDeposit0 = vault.deposit(bobDeposit, bob, bobPrice, bytes(""));
            vm.stopPrank();

            assertEqUint(vault.balanceOf(bob), bobSharesDeposit0);

            {
                vm.startPrank(alice);

                // Alice attempts to burn Bob's receipt by ID, using herself as owner.
                vm.expectRevert(
                    abi.encodeWithSelector(
                        IERC1155Errors.ERC1155InsufficientBalance.selector, alice, 0, bobPrice, bobPrice
                    )
                );
                uint256 aliceSharesWithdraw0 = vault.withdraw(1e18, alice, alice, bobPrice, bytes(""));
                assertEqUint(aliceSharesWithdraw0, 0);

                // Alice attempts to burn Bob's receipt by ID, using Bob as owner.
                vm.expectRevert(
                    abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, alice, 0, bobPrice)
                );
                uint256 aliceSharesWithdraw1 = vault.withdraw(1e18, alice, bob, bobPrice, bytes(""));
                assertEqUint(aliceSharesWithdraw1, 0);

                vm.stopPrank();
            }

            // Bob can withdraw his own receipt.
            vm.startPrank(bob);
            uint256 bobSharesWithdraw0 = vault.withdraw(1e18, bob, bob, bobPrice, bytes(""));
            vm.stopPrank();

            assertTrue(bobSharesWithdraw0 > 0);
            assertEqUint(vault.balanceOf(bob), bobSharesDeposit0 - bobSharesWithdraw0);

            // If Bob deposits under the same price as Alice, Bob cannot burn Alice's
            // receipt.
            setVaultOraclePrice(alicePrice);

            vm.startPrank(bob);
            vm.mockCall(
                address(iAsset),
                abi.encodeWithSelector(IERC20.transferFrom.selector, bob, vault, bobDeposit),
                abi.encode(true)
            );
            vm.expectCall(
                address(iAsset), abi.encodeWithSelector(IERC20.transferFrom.selector, bob, vault, bobDeposit)
            );

            uint256 bobSharesDeposit1 = vault.deposit(bobDeposit, bob, alicePrice, bytes(""));
            vm.stopPrank();

            bobExpectedSharesAfterActions = bobSharesDeposit0 + bobSharesDeposit1 - bobSharesWithdraw0;
            assertEqUint(vault.balanceOf(bob), bobExpectedSharesAfterActions);
        }

        vm.startPrank(bob);
        // Bob cannot burn Alice's receipt.
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, 0, alicePrice));
        vault.withdraw(1e18, bob, alice, alicePrice, bytes(""));

        uint256 maxWithdrawBob = vault.maxWithdraw(bob, alicePrice);

        // Bob can withdraw his own receipt from alice's price.
        uint256 bobAliceWithdrawShares = vault.withdraw(maxWithdrawBob, bob, bob, alicePrice, bytes(""));

        // Bob's balance should be only from his other deposit.

        assertEqUint(vault.balanceOf(bob), bobExpectedSharesAfterActions - bobAliceWithdrawShares);
        vm.stopPrank();

        // Ensure that bob has enough shares to test the receipt withdrawing.
        // If he doesn't then we'd just run into a share balance before we can
        // test the receipt balance below.
        vm.startPrank(alice);
        vm.assume(vault.previewWithdraw(1e18, alicePrice) <= vault.balanceOf(bob));
        vm.stopPrank();

        vm.startPrank(bob);

        // Bob cannot withdraw any more under alice price.
        {
            uint256 bobBalance = vault.receipt().balanceOf(bob, alicePrice);
            bytes memory err = abi.encodeWithSelector(
                IERC1155Errors.ERC1155InsufficientBalance.selector, bob, bobBalance, alicePrice, alicePrice
            );
            vm.expectRevert(err);
        }

        vault.withdraw(1e18, bob, bob, alicePrice, bytes(""));

        vm.stopPrank();
        // Alice can withdraw her own receipt.
        vm.startPrank(alice);

        uint256 maxWithdrawAlice = vault.maxWithdraw(alice, alicePrice);
        vault.withdraw(maxWithdrawAlice, alice, alice, alicePrice, bytes(""));
        vm.stopPrank();
    }

    /// Test Withdraw function with more than assets deposied
    function testWithdrawMoreThanAssets(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 assetsToWithdraw,
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

        assets = bound(assets, 1, type(uint128).max - 1);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets),
            abi.encode(true)
        );
        vm.expectCall(address(iAsset), abi.encodeWithSelector(IERC20.transferFrom.selector, alice, vault, assets));

        vault.deposit(assets, alice, oraclePrice, bytes(""));

        // Make sure assetsToWithdraw is more than assets
        assetsToWithdraw = bound(assetsToWithdraw, assets + 1, type(uint128).max);
        checkNoBalanceChange(vault, alice, alice, oraclePrice, assetsToWithdraw, receipt, bytes(""), bytes(""));
    }

    /// forge-config: default.fuzz.runs = 1
    function testWithdrawFlareFork(uint256 deposit) public {
        deposit = bound(deposit, 1, type(uint128).max);
        (ERC20PriceOracleReceiptVault vault, address alice) = LibERC20PriceOracleReceiptVaultFork.setup(vm, deposit);

        deal(address(SFLR_CONTRACT), alice, deposit);

        vm.startPrank(alice);
        vm.assume(vault.previewDeposit(deposit, 0) > 0);
        vault.deposit(deposit, alice, 0, hex"00");

        uint256 shareBalance = vault.balanceOf(alice);
        uint256 rate = LibERC20PriceOracleReceiptVaultFork.getRate();

        // Call withdraw function
        vault.withdraw(shareBalance, alice, alice, rate, hex"00");

        uint256 shares = shareBalance.fixedPointMul(rate, Math.Rounding.Ceil);
        uint256 shareBalanceAft = vault.balanceOf(alice);

        assertEqUint(shareBalanceAft, shareBalance - shares);

        vm.stopPrank();
    }

    /// Test oracle vault for multiple prices and historical redemptions.
    function testMultiplePricesAndHistoricalRedemptionsAndMint(
        uint256 aliceSeed,
        uint256 priceOne,
        uint256 priceTwo,
        uint256 priceThree,
        uint256 aliceDeposit
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        priceOne = bound(priceOne, 1e18, 100e18);
        priceTwo = bound(priceTwo, 1e18, 100e18);
        priceThree = bound(priceThree, 1e18, 100e18);
        vm.assume(priceTwo != priceOne && priceTwo != priceThree);
        vm.assume(priceOne != priceThree);

        aliceDeposit = bound(aliceDeposit, 100e18, type(uint128).max);

        // Start recording logs
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, "Alice", "Alice");
        ReceiptContract receipt = getReceipt();

        // Set initial oracle price and deposit first half
        setVaultOraclePrice(priceOne);
        vm.startPrank(alice);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), aliceDeposit / 2),
            abi.encode(true)
        );
        vm.expectCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), aliceDeposit / 2)
        );

        vault.deposit(aliceDeposit / 2, alice, priceOne, bytes(""));
        vm.stopPrank();

        // Assert receipt balance and vault state after first deposit
        uint256 expectedSharesOne = (aliceDeposit / 2).fixedPointMul(priceOne, Math.Rounding.Floor);
        assertEq(vault.balanceOf(alice), expectedSharesOne);
        assertEq(receipt.balanceOf(alice, priceOne), expectedSharesOne);

        // Set new oracle price and deposit second half
        setVaultOraclePrice(priceTwo);
        vm.startPrank(alice);
        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), aliceDeposit / 2),
            abi.encode(true)
        );
        vm.expectCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), aliceDeposit / 2)
        );

        vault.deposit(aliceDeposit / 2, alice, priceTwo, bytes(""));
        vm.stopPrank();

        uint256 expectedSharesTwo = (aliceDeposit / 2).fixedPointMul(priceTwo, Math.Rounding.Floor);
        assertEq(vault.balanceOf(alice), expectedSharesOne + expectedSharesTwo);
        assertEq(receipt.balanceOf(alice, priceOne), expectedSharesOne);
        assertEq(receipt.balanceOf(alice, priceTwo), expectedSharesTwo);

        // Mint additional shares at priceTwo
        uint256 assetsRequired = aliceDeposit.fixedPointDiv(priceTwo, Math.Rounding.Ceil);
        vm.startPrank(alice);
        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), assetsRequired),
            abi.encode(true)
        );

        vault.mint(aliceDeposit, alice, priceTwo, bytes(""));
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), expectedSharesOne + expectedSharesTwo + aliceDeposit);
        assertEq(receipt.balanceOf(alice, priceOne), expectedSharesOne);
        assertEq(receipt.balanceOf(alice, priceTwo), expectedSharesTwo + aliceDeposit);

        // Set new oracle price without minting
        setVaultOraclePrice(priceOne);
        assertEq(vault.balanceOf(alice), expectedSharesOne + expectedSharesTwo + aliceDeposit);

        // Ensure burns cannot occur at the new oracle price
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, alice, 0, priceThree, priceThree)
        );
        vault.withdraw(1e18, alice, alice, priceThree, bytes(""));

        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, alice, 0, 1e18, priceThree)
        );
        vault.redeem(1e18, alice, alice, priceThree, bytes(""));
        vm.stopPrank();

        setVaultOraclePrice(priceThree);

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, alice, 0, priceThree, priceThree)
        );
        vault.withdraw(1e18, alice, alice, priceThree, bytes(""));

        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, alice, 0, 1e18, priceThree)
        );
        vault.redeem(1e18, alice, alice, priceThree, bytes(""));
        vm.stopPrank();

        // Ensure burns can occur at the previous oracle price
        vm.startPrank(alice);
        vault.withdraw(1e18, alice, alice, priceOne, bytes(""));
        vault.redeem(1e18, alice, alice, priceOne, bytes(""));
        vault.withdraw(1e18, alice, alice, priceTwo, bytes(""));
        vault.redeem(1e18, alice, alice, priceTwo, bytes(""));
        vm.stopPrank();
    }
}
