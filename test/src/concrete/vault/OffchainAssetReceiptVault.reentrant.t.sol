// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {
    OffchainAssetReceiptVault,
    DEPOSIT,
    TRANSFER_RECEIPT,
    CONFISCATE_RECEIPT
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {AlwaysAuthorize} from "test/concrete/AlwaysAuthorize.sol";
import {ReentrantDepositReceiver, IReentrantDepositTarget} from "test/concrete/ReentrantDepositReceiver.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts-5.6.1/utils/ReentrancyGuard.sol";
import {ReentrantAuthorizer, IReentrantAuthorizerVault} from "test/concrete/ReentrantAuthorizer.sol";
import {
    ReentrantShareTransferAuthorizer,
    IReentrantShareVault
} from "test/concrete/ReentrantShareTransferAuthorizer.sol";
import {CertifyObserverAuthorizer, ICertifiableObserverVault} from "test/concrete/CertifyObserverAuthorizer.sol";
import {ReentrantConfiscator, IReentrantConfiscateVault} from "test/concrete/ReentrantConfiscator.sol";
import {EthRefundReenterDepositor, IEthRefundReenterVault} from "test/concrete/EthRefundReenterDepositor.sol";
import {OffchainAssetReceiptVaultAuthorizerV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {IERC20Errors} from "@openzeppelin-contracts-upgradeable-5.6.1/token/ERC20/ERC20Upgradeable.sol";

/// @notice Regression tests for reentrancy protection in OffchainAssetReceiptVault.
/// Covers the ERC1155 acceptance-callback surface documented in issue #316 (rows
/// 1/2/7 of the master reentrancy call-site table).
///
/// The vault's `_deposit` and `_withdraw` carry `nonReentrant` from
/// ReentrancyGuard. Any vault entrypoint that re-enters through the ERC1155
/// acceptance callback fired by `receipt().managerMint` therefore reverts with
/// `ReentrancyGuardReentrantCall` before any state is modified.
contract OffchainAssetReceiptVaultReentrantTest is OffchainAssetReceiptVaultTest {
    /// A malicious `receiver` that re-enters `vault.deposit` from within
    /// `onERC1155Received` cannot bypass the `nonReentrant` guard: the nested
    /// deposit reverts and the entire outer transaction reverts too.
    function testDepositReentrancyGuardFires(uint256 assets, string memory shareName, string memory shareSymbol)
        external
    {
        assets = bound(assets, 1, type(uint128).max);
        address admin = makeAddr("admin");
        OffchainAssetReceiptVault vault = createVault(admin, shareName, shareSymbol);

        // Use an always-pass authorizer so authorization is never the revert
        // cause — the nonReentrant guard is what we want to observe.
        AlwaysAuthorize alwaysAuth = new AlwaysAuthorize();
        vm.prank(admin);
        vault.setAuthorizer(alwaysAuth);

        // The receiver re-enters vault.deposit from onERC1155Received.
        ReentrantDepositReceiver reentrant =
            new ReentrantDepositReceiver(IReentrantDepositTarget(address(vault)), assets);

        // The nested deposit fires inside managerMint → onERC1155Received,
        // hits the locked nonReentrant guard, and the revert propagates to
        // the outer deposit — which therefore reverts with the same error.
        vm.prank(admin);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vault.deposit(assets, address(reentrant), 0, "");
    }

    /// Positive control: without a reentrant receiver the same deposit (under
    /// AlwaysAuthorize) succeeds — confirming the revert above is solely the
    /// reentrancy guard, not a setup issue.
    function testDepositSucceedsWithNonReentrantReceiver(
        uint256 assets,
        string memory shareName,
        string memory shareSymbol
    ) external {
        assets = bound(assets, 1, type(uint128).max);
        address admin = makeAddr("admin");
        address receiver = makeAddr("receiver");
        OffchainAssetReceiptVault vault = createVault(admin, shareName, shareSymbol);

        AlwaysAuthorize alwaysAuth2 = new AlwaysAuthorize();
        vm.prank(admin);
        vault.setAuthorizer(alwaysAuth2);

        vm.prank(admin);
        uint256 shares = vault.deposit(assets, receiver, 0, "");
        assertGt(shares, 0, "deposit must mint shares");
        assertEq(vault.balanceOf(receiver), shares, "receiver balance");
    }

    /// Row 13: a swapped, REAL reentrant authorizer re-enters `vault.deposit`
    /// from inside the `_afterDeposit` `authorize(DEPOSIT)` call — which runs
    /// while the `_deposit` `nonReentrant` guard is held. The nested deposit
    /// reverts with `ReentrancyGuardReentrantCall`, reverting the whole deposit.
    function testDepositSwappedAuthorizerAfterDepositGuardFires(
        uint256 assets,
        string memory shareName,
        string memory shareSymbol
    ) external {
        assets = bound(assets, 1, type(uint128).max);
        address admin = makeAddr("admin");
        OffchainAssetReceiptVault vault = createVault(admin, shareName, shareSymbol);

        ReentrantAuthorizer maliciousAuth = new ReentrantAuthorizer(DEPOSIT);
        maliciousAuth.setVault(IReentrantAuthorizerVault(address(vault)));
        vm.prank(admin);
        vault.setAuthorizer(maliciousAuth);

        address depositor = makeAddr("depositor");
        vm.prank(depositor);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vault.deposit(assets, depositor, 0, "");
    }

    /// Row 12: a swapped, REAL reentrant authorizer re-enters `vault.deposit`
    /// from inside the `authorizeReceiptTransfer3` `authorize(TRANSFER_RECEIPT)`
    /// call fired during the ERC1155 receipt mint — also inside the held
    /// `_deposit` guard. The nested deposit reverts with
    /// `ReentrancyGuardReentrantCall`, reverting the whole deposit.
    function testDepositSwappedAuthorizerReceiptTransferGuardFires(
        uint256 assets,
        string memory shareName,
        string memory shareSymbol
    ) external {
        assets = bound(assets, 1, type(uint128).max);
        address admin = makeAddr("admin");
        OffchainAssetReceiptVault vault = createVault(admin, shareName, shareSymbol);

        ReentrantAuthorizer maliciousAuth = new ReentrantAuthorizer(TRANSFER_RECEIPT);
        maliciousAuth.setVault(IReentrantAuthorizerVault(address(vault)));
        vm.prank(admin);
        vault.setAuthorizer(maliciousAuth);

        address depositor = makeAddr("depositor");
        vm.prank(depositor);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vault.deposit(assets, depositor, 0, "");
    }

    /// Row 15: the share `_update` `authorize(TRANSFER_SHARES)` call is NOT
    /// guarded and runs BEFORE `super._update` writes balances. A swapped, REAL
    /// reentrant authorizer exploits that window: during alice's transfer it
    /// re-enters `transferFrom(alice, attacker, amount)` to move alice's shares a
    /// second time. The attack MUST fail — the nested transfer zeroes alice, then
    /// the outer `super._update` underflows and reverts with
    /// `ERC20InsufficientBalance`. No double-spend, and the specific selector
    /// (not a reentrancy-guard revert) proves ERC20 accounting is the protection.
    function testShareTransferSwappedAuthorizerCannotOverspend(
        uint256 amount,
        string memory shareName,
        string memory shareSymbol
    ) external {
        amount = bound(amount, 1, type(uint128).max);
        address admin = makeAddr("admin");
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        address attacker = makeAddr("attacker");

        OffchainAssetReceiptVault vault = createVault(admin, shareName, shareSymbol);

        // Give alice `amount` shares via a normal deposit under an always-pass
        // authorizer.
        AlwaysAuthorize alwaysAuth = new AlwaysAuthorize();
        vm.prank(admin);
        vault.setAuthorizer(alwaysAuth);
        vm.prank(alice);
        vault.deposit(amount, alice, 0, "");
        assertEq(vault.balanceOf(alice), amount, "alice funded");

        // Alice approves the (soon-to-be) malicious authorizer to spend her
        // shares, modelling a pre-existing allowance the attacker abuses.
        ReentrantShareTransferAuthorizer maliciousAuth = new ReentrantShareTransferAuthorizer();
        vm.prank(alice);
        vault.approve(address(maliciousAuth), amount);
        maliciousAuth.configure(IReentrantShareVault(address(vault)), alice, attacker, amount);

        vm.prank(admin);
        vault.setAuthorizer(maliciousAuth);

        // Alice transfers all her shares to bob; the reentrant authorizer tries
        // to also drain them to attacker. The double-move underflows.
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, amount));
        vault.transfer(bob, amount);

        // Nothing moved.
        assertEq(vault.balanceOf(alice), amount, "alice retains shares");
        assertEq(vault.balanceOf(bob), 0, "bob got nothing");
        assertEq(vault.balanceOf(attacker), 0, "attacker got nothing");
    }

    /// Row 14: `certify` is NOT guarded; its safety rests on `certifiedUntil`
    /// being written BEFORE the `authorize(CERTIFY)` call. A swapped, REAL
    /// reentrant authorizer reads the vault back during that callback and MUST
    /// observe the fresh certification already in effect. Observing the stale
    /// (expired) state would mean the write was ordered after the call.
    function testCertifyReentrantAuthorizerObservesWrittenCertification(
        string memory shareName,
        string memory shareSymbol
    ) external {
        address admin = makeAddr("admin");
        OffchainAssetReceiptVault vault = createVault(admin, shareName, shareSymbol);

        CertifyObserverAuthorizer observerAuth = new CertifyObserverAuthorizer();
        observerAuth.setVault(ICertifiableObserverVault(address(vault)));
        vm.prank(admin);
        vault.setAuthorizer(observerAuth);

        vm.warp(1000);
        assertTrue(vault.isCertificationExpired(), "expired before certify");

        vm.prank(admin);
        vault.certify(block.timestamp + 1000, false, "");

        assertTrue(observerAuth.observed(), "authorizer observed the certify callback");
        assertTrue(
            !observerAuth.observedExpiredDuringCertify(),
            "certifiedUntil written before authorize (fresh certification visible in callback)"
        );
        assertTrue(!vault.isCertificationExpired(), "certified after");
    }

    /// Row 11: the ETH refund `sendValue` fires OUTSIDE the `nonReentrant` guard,
    /// after `_deposit` completes. A REAL reentrant depositor re-enters
    /// `vault.deposit` from its `receive()` when the refund lands. Because the
    /// refund is outside the guard, the re-entrant deposit is a fresh, successful,
    /// independent deposit under a new receipt id — both deposits land. (If the
    /// guard spanned the refund, the nested deposit would revert, `sendValue`
    /// would revert on the failed call, and neither deposit would land.)
    function testDepositEthRefundReentryIsBenign(
        uint256 assets,
        uint256 refund,
        string memory shareName,
        string memory shareSymbol
    ) external {
        assets = bound(assets, 1, type(uint128).max);
        refund = bound(refund, 1, 100 ether);
        address admin = makeAddr("admin");
        OffchainAssetReceiptVault vault = createVault(admin, shareName, shareSymbol);

        AlwaysAuthorize alwaysAuth = new AlwaysAuthorize();
        vm.prank(admin);
        vault.setAuthorizer(alwaysAuth);

        EthRefundReenterDepositor attacker = new EthRefundReenterDepositor(IEthRefundReenterVault(address(vault)));
        address outerReceiver = makeAddr("outerReceiver");
        address innerReceiver = makeAddr("innerReceiver");

        vm.deal(address(attacker), refund);
        attacker.deposit{value: refund}(assets, outerReceiver, assets, innerReceiver);

        // Both the outer deposit (id 1) and the refund-triggered re-entrant
        // deposit (id 2) succeeded independently.
        assertEq(attacker.reenterCount(), 1, "refund re-entered exactly once");
        assertEq(vault.highwaterId(), 2, "two independent deposits, two ids");
        assertEq(vault.balanceOf(outerReceiver), assets, "outer shares minted");
        assertEq(vault.balanceOf(innerReceiver), assets, "re-entrant shares minted");
        assertEq(vault.receipt().balanceOf(outerReceiver, 1), assets, "outer receipt id 1");
        assertEq(vault.receipt().balanceOf(innerReceiver, 2), assets, "re-entrant receipt id 2");
    }

    /// Row 16: `confiscateReceipt` is `nonReentrant` and transfers the receipt to
    /// the confiscator (`to == _msgSender()`), firing the ERC1155
    /// `onERC1155Received` acceptance callback. A REAL reentrant confiscator
    /// re-enters `confiscateReceipt` from that callback and hits the held guard;
    /// the ERC1155 acceptance check bubbles the `ReentrancyGuardReentrantCall`
    /// revert, reverting the whole confiscation.
    function testConfiscateReceiptReentrantConfiscatorGuardFires(
        uint256 assets,
        string memory shareName,
        string memory shareSymbol
    ) external {
        assets = bound(assets, 1, type(uint128).max);
        address admin = makeAddr("admin");
        address alice = makeAddr("alice");
        OffchainAssetReceiptVault vault = createVault(admin, shareName, shareSymbol);

        ReentrantConfiscator confiscator = new ReentrantConfiscator();

        // alice can deposit (DEPOSIT role lets minting through while cert is
        // expired); the confiscator can confiscate receipts.
        vm.startPrank(admin);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(
            CONFISCATE_RECEIPT, address(confiscator)
        );
        vm.stopPrank();

        // alice deposits, receiving receipt id 1.
        vm.prank(alice);
        vault.deposit(assets, alice, 0, "");
        assertEq(vault.receipt().balanceOf(alice, 1), assets, "alice holds receipt id 1");

        // The confiscator confiscates and re-enters from onERC1155Received.
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        confiscator.attack(IReentrantConfiscateVault(address(vault)), alice, 1, assets);
    }
}
