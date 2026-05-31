// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {AtomicDrainReceiver} from "test/concrete/AtomicDrainReceiver.sol";
import {ReentrantDepositReceiver, IReentrantDepositTarget} from "test/concrete/ReentrantDepositReceiver.sol";
import {IERC20} from "forge-std-1.16.1/src/interfaces/IERC20.sol";
import {IERC1155} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155.sol";
import {IERC1155Errors} from "@openzeppelin-contracts-5.6.1/interfaces/draft-IERC6093.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts-5.6.1/utils/ReentrancyGuard.sol";

/// @title ReceiptSpoofEndToEndTest
/// @notice End-to-end #309 regression through a REAL
/// `ERC20PriceOracleReceiptVault` deposit (not the synthetic test manager the
/// unit tests use). Confirms the spoof drain is neutralized when it fires from a
/// genuine vault receipt mint, and that the vault's shared `nonReentrant` guard
/// forbids re-entering `deposit` from the acceptance callback — the top coverage
/// item from the #316 reentrancy audit. The vault's base authorizer is permissive
/// (it only checks the caller is the receipt), so these flows are stopped by OZ's
/// approval check seeing the true `msg.sender` and by the reentrancy guard — the
/// exact mechanisms the #309 fix relies on, exercised end-to-end.
contract ReceiptSpoofEndToEndTest is ERC20PriceOracleReceiptVaultTest {
    /// The oracle price doubles as the minted receipt id; any non-zero value
    /// works. `1e18` keeps shares == assets (price is 18-decimal fixed point).
    uint256 internal constant PRICE = 1e18;

    /// Mocks the asset pull so deposits settle without a real ERC20.
    function _mockAssetPull() internal {
        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
    }

    /// The #309 atomic drain, replayed through a real vault: a depositor deposits
    /// to a malicious receiver whose acceptance callback tries to drain a victim's
    /// pre-existing receipts. Post-fix the callback runs as the receiver (not the
    /// spoofed victim), so OZ's approval check reverts the drain and the whole
    /// deposit, leaving the victim's holdings intact.
    function testSpoofDrainThroughRealVaultReverts(uint256 assets) external {
        assets = bound(assets, 1, type(uint128).max);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, "Vault", "VLT");
        ReceiptContract receipt = ReceiptContract(address(vault.receipt()));

        setVaultOraclePrice(PRICE);
        _mockAssetPull();

        // The victim holds receipts from a legitimate deposit to themselves.
        address victim = makeAddr("victim");
        address attacker = makeAddr("attacker");
        vm.prank(victim);
        uint256 victimShares = vault.deposit(assets, victim, 0, "");
        assertEq(receipt.balanceOf(victim, PRICE), victimShares, "victim funded");

        // The attacker deposits to a malicious receiver that, in its acceptance
        // callback, tries to move the victim's receipts to the attacker. Post-fix
        // the callback acts as the receiver (unapproved for the victim), so the
        // drain — and the entire attacker deposit — reverts.
        AtomicDrainReceiver drainer =
            new AtomicDrainReceiver(IERC1155(address(receipt)), victim, attacker, PRICE, victimShares);
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, address(drainer), victim)
        );
        vault.deposit(assets, address(drainer), 0, "");

        // Victim keeps everything; the attacker got nothing.
        assertEq(receipt.balanceOf(victim, PRICE), victimShares, "victim's receipts untouched");
        assertEq(receipt.balanceOf(attacker, PRICE), 0, "attacker drained nothing");
    }

    /// #316 row 7 / coverage item 1: re-entering the vault's `deposit` from inside
    /// the acceptance callback reverts on the shared `nonReentrant` guard. This is
    /// the defence-in-depth backstop to the #309 fix — even a callback that did
    /// observe a spoofed caller could not re-enter a value-moving vault flow.
    function testReentrantDepositFromCallbackReverts(uint256 assets) external {
        assets = bound(assets, 1, type(uint128).max);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, "Vault", "VLT");

        setVaultOraclePrice(PRICE);
        _mockAssetPull();

        address depositor = makeAddr("depositor");
        ReentrantDepositReceiver receiver =
            new ReentrantDepositReceiver(IReentrantDepositTarget(address(vault)), assets);

        // The mint to the receiver fires onERC1155Received, which re-enters
        // `deposit`; the vault is mid-`_deposit` (nonReentrant), so the nested
        // call reverts and unwinds the whole outer deposit.
        vm.prank(depositor);
        vm.expectRevert(abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector));
        vault.deposit(assets, address(receiver), 0, "");
    }
}
