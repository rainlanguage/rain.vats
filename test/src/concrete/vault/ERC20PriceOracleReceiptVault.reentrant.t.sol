// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ReentrantDepositReceiver, IReentrantDepositTarget} from "test/concrete/ReentrantDepositReceiver.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts-5.6.1/utils/ReentrancyGuard.sol";
import {IERC20} from "forge-std-1.16.1/src/interfaces/IERC20.sol";
import {IPriceOracleV2} from "src/interface/IPriceOracleV2.sol";
import {ReentrantAsset, IReentrantAssetVault} from "test/concrete/ReentrantAsset.sol";
import {ReentrantOracle, IReentrantOracleVault} from "test/concrete/ReentrantOracle.sol";
import {
    ERC20PriceOracleReceiptVaultConfigV2,
    ReceiptVaultConfigV2
} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";

/// @notice Regression tests for reentrancy protection in ERC20PriceOracleReceiptVault.
/// Covers the ERC1155 acceptance-callback surface documented in issue #316 (rows
/// 1/2/7 of the master reentrancy call-site table).
///
/// Both `_deposit` and `_withdraw` carry `nonReentrant`. Any attempt to
/// re-enter the vault through the ERC1155 receipt-mint callback (row 7) or the
/// arbitrary-ERC20 transfer hooks (_beforeDeposit / _afterWithdraw, rows 8/9)
/// therefore reverts with `ReentrancyGuardReentrantCall`.
contract ERC20PriceOracleReceiptVaultReentrantTest is ERC20PriceOracleReceiptVaultTest {
    /// A `receiver` that re-enters `vault.deposit` from inside
    /// `onERC1155Received` cannot bypass the `nonReentrant` guard: the nested
    /// deposit is rejected and the entire outer transaction reverts.
    function testDepositReentrancyGuardFires(
        uint256 assets,
        uint256 oraclePrice,
        string memory shareName,
        string memory shareSymbol
    ) external {
        assets = bound(assets, 1, type(uint128).max);
        // oraclePrice is the share ratio (shares = assets * price / 1e18); bound
        // to ≥ 1e18 so that even assets=1 mints at least 1 share and avoids
        // the ZeroSharesAmount revert that would mask the reentrancy result.
        oraclePrice = bound(oraclePrice, 1e18, type(uint128).max);

        setVaultOraclePrice(oraclePrice);
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);

        address depositor = makeAddr("depositor");

        // Mock the outer deposit's ERC20 asset transfer so it does not revert
        // on the asset pull.  The inner (reentrant) deposit's transfer is never
        // reached because the nonReentrant guard fires first.
        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, address(vault), assets),
            abi.encode(true)
        );

        // The receiver re-enters vault.deposit from onERC1155Received.
        ReentrantDepositReceiver reentrant =
            new ReentrantDepositReceiver(IReentrantDepositTarget(address(vault)), assets);

        vm.prank(depositor);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vault.deposit(assets, address(reentrant), 0, "");
    }

    /// Positive control: without a reentrant receiver the same deposit succeeds,
    /// confirming the revert above is solely the reentrancy guard.
    function testDepositSucceedsWithNonReentrantReceiver(
        uint256 assets,
        uint256 oraclePrice,
        string memory shareName,
        string memory shareSymbol
    ) external {
        assets = bound(assets, 1, type(uint128).max);
        // oraclePrice is the share ratio (shares = assets * price / 1e18); bound
        // to ≥ 1e18 so that even assets=1 mints at least 1 share and avoids
        // the ZeroSharesAmount revert that would mask the reentrancy result.
        oraclePrice = bound(oraclePrice, 1e18, type(uint128).max);

        setVaultOraclePrice(oraclePrice);
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);

        address depositor = makeAddr("depositor");
        address receiver = makeAddr("receiver");

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, depositor, address(vault), assets),
            abi.encode(true)
        );

        vm.prank(depositor);
        uint256 shares = vault.deposit(assets, receiver, 0, "");
        assertGt(shares, 0, "deposit must mint shares");
        assertEq(vault.balanceOf(receiver), shares, "receiver balance");
    }

    /// Deploy a vault bound to a specific (real) ERC20 asset instead of the
    /// abstract test's mocked asset address.
    function createVaultWithAsset(IPriceOracleV2 priceOracle, address vaultAsset, string memory name, string memory sym)
        internal
        returns (ERC20PriceOracleReceiptVault)
    {
        return iDeployer.newERC20PriceOracleReceiptVault(
            ERC20PriceOracleReceiptVaultConfigV2({
                receiptVaultConfig: ReceiptVaultConfigV2({asset: vaultAsset, name: name, symbol: sym, receipt: address(0)}),
                priceOracle: priceOracle
            })
        );
    }

    /// Row 8: the asset ERC20 is a REAL reentrant dependency. Its
    /// `_beforeDeposit` `transferFrom` pull re-enters `vault.deposit`, which hits
    /// the `nonReentrant` guard held by `_deposit`. SafeERC20 bubbles the revert,
    /// so the outer deposit reverts with `ReentrancyGuardReentrantCall`.
    function testDepositAssetTransferFromReentrancyGuardFires(
        uint256 assets,
        string memory shareName,
        string memory shareSymbol
    ) external {
        assets = bound(assets, 1, type(uint128).max);
        // Price 1e18 => shares == assets (nonzero) and receipt id == 1e18.
        setVaultOraclePrice(1e18);

        ReentrantAsset asset = new ReentrantAsset();
        ERC20PriceOracleReceiptVault vault =
            createVaultWithAsset(iVaultOracle, address(asset), shareName, shareSymbol);

        address depositor = makeAddr("depositor");
        asset.mint(depositor, assets);
        vm.prank(depositor);
        asset.approve(address(vault), assets);

        // Arm the deposit-side transferFrom re-entry.
        asset.setVault(IReentrantAssetVault(address(vault)));
        asset.armTransferFrom();

        vm.prank(depositor);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vault.deposit(assets, depositor, 0, "");
    }

    /// Row 9: the asset ERC20's `_afterWithdraw` `transfer` push is a REAL
    /// reentrant dependency. A prior deposit succeeds normally (hook unarmed);
    /// once armed, the withdraw-time push re-enters `vault.deposit` and hits the
    /// shared `nonReentrant` guard held by `_withdraw`, so the outer withdraw
    /// reverts with `ReentrancyGuardReentrantCall`.
    function testWithdrawAssetTransferReentrancyGuardFires(
        uint256 assets,
        string memory shareName,
        string memory shareSymbol
    ) external {
        assets = bound(assets, 1, type(uint128).max);
        // Price 1e18 => shares == assets, receipt id == 1e18, withdraw amount ==
        // assets, all exact (no rounding to zero that could mask the result).
        setVaultOraclePrice(1e18);

        ReentrantAsset asset = new ReentrantAsset();
        ERC20PriceOracleReceiptVault vault =
            createVaultWithAsset(iVaultOracle, address(asset), shareName, shareSymbol);

        address alice = makeAddr("alice");
        asset.mint(alice, assets);
        vm.prank(alice);
        asset.approve(address(vault), assets);

        // Normal deposit while the hook is unarmed: succeeds, funds the vault,
        // and gives alice shares + receipt at id 1e18.
        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice, 0, "");
        assertEq(shares, assets, "1:1 shares at price 1e18");

        // Arm the withdraw-side transfer re-entry.
        asset.setVault(IReentrantAssetVault(address(vault)));
        asset.armTransfer();

        vm.prank(alice);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vault.withdraw(assets, alice, alice, 1e18, "");
    }

    /// Row 20: the price oracle is a REAL reentrant dependency read PRE-guard in
    /// `_nextId`. It re-enters `vault.deposit` from inside `price()`. Because the
    /// read precedes the guard, the nested deposit SUCCEEDS as an independent
    /// deposit that locks its OWN fresh price. Distinct outer/inner prices yield
    /// distinct receipt ids — proving each deposit consumes a fresh price with no
    /// staleness window (and that a re-entrant oracle cannot corrupt the outer
    /// deposit's price).
    function testDepositOracleReentryIsBenignWithFreshPrice(
        uint256 outerAssets,
        uint256 innerAssets,
        string memory shareName,
        string memory shareSymbol
    ) external {
        outerAssets = bound(outerAssets, 1, type(uint64).max);
        innerAssets = bound(innerAssets, 1, type(uint64).max);

        uint256 priceOuter = 3e18;
        uint256 priceInner = 2e18;

        ReentrantOracle oracle = new ReentrantOracle(priceOuter, priceInner);
        ERC20PriceOracleReceiptVault vault =
            createVault(IPriceOracleV2(payable(address(oracle))), shareName, shareSymbol);

        // The asset is incidental here (the oracle is the reentrant dependency);
        // let both the outer and nested asset pulls succeed.
        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));

        address depositor = makeAddr("depositor");
        address innerReceiver = makeAddr("innerReceiver");
        oracle.configure(IReentrantOracleVault(address(vault)), innerAssets, innerReceiver);

        vm.prank(depositor);
        vault.deposit(outerAssets, depositor, 0, "");

        uint256 outerShares = outerAssets * priceOuter / 1e18;
        uint256 innerShares = innerAssets * priceInner / 1e18;

        // Both deposits landed, each under its own fresh price/id.
        assertTrue(priceOuter != priceInner, "outer and inner prices must differ");
        assertEq(vault.balanceOf(depositor), outerShares, "outer shares minted");
        assertEq(vault.balanceOf(innerReceiver), innerShares, "inner (re-entrant) shares minted");
        assertEq(
            vault.receipt().balanceOf(depositor, priceOuter), outerShares, "outer receipt under fresh outer price id"
        );
        assertEq(
            vault.receipt().balanceOf(innerReceiver, priceInner),
            innerShares,
            "inner receipt under fresh inner price id"
        );
    }
}
