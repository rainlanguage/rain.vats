// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ReentrantDepositReceiver, IReentrantDepositTarget} from "test/concrete/ReentrantDepositReceiver.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts-5.6.1/utils/ReentrancyGuard.sol";
import {IERC20} from "forge-std-1.16.1/src/interfaces/IERC20.sol";
import {IPriceOracleV2} from "src/interface/IPriceOracleV2.sol";

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
}
