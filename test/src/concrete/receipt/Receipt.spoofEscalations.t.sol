// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {IReceiptV3} from "src/interface/IReceiptV3.sol";
import {IReceiptManagerV2} from "src/interface/IReceiptManagerV2.sol";
import {ReceiptFactoryTest} from "test/abstract/ReceiptFactoryTest.sol";
import {IERC1155Receiver} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155Receiver.sol";
import {IERC1155} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155.sol";
import {IERC1155Errors} from "@openzeppelin-contracts-5.6.1/interfaces/draft-IERC6093.sol";

/// @title FreeTransferReceiptManager
/// @notice Minimal manager that authorizes ALL receipt transfers (no-op
/// `authorizeReceiptTransfer3`) — the worst case for the #309 spoofing bug,
/// where receipts are unconditionally transferable and there is no per-transfer
/// authorization hook to lean on (e.g. any vault inheriting the base
/// `ReceiptVault` no-op authorizer). `mint` takes an explicit `sender` so tests
/// can drive the operator directly, the way a vault passes `_msgSender()` (the
/// depositor) into `managerMint`.
contract FreeTransferReceiptManager is IReceiptManagerV2 {
    function authorizeReceiptTransfer3(address, address, address, uint256[] memory, uint256[] memory) external {}

    function mint(IReceiptV3 receipt, address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
    {
        receipt.managerMint(sender, account, id, amount, data);
    }
}

/// Re-enters the receipt during the acceptance callback and tries to grant
/// `attacker` operator approval. Pre-fix this was spoofed onto the depositor;
/// post-fix it lands on this contract (the true `msg.sender`).
contract ApprovalSpoofReceiver is IERC1155Receiver {
    IERC1155 internal immutable iReceipt;
    address internal immutable iAttacker;

    constructor(IERC1155 receipt, address attacker) {
        iReceipt = receipt;
        iAttacker = attacker;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        iReceipt.setApprovalForAll(iAttacker, true);
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}

/// Re-enters the receipt during the acceptance callback and tries to drain the
/// victim's pre-existing receipts. Pre-fix the spoof made `_msgSender()` the
/// victim so OZ's `from == sender` check passed; post-fix `_msgSender()` is this
/// contract, so the transfer reverts with `ERC1155MissingApprovalForAll`.
contract AtomicDrainReceiver is IERC1155Receiver {
    IERC1155 internal immutable iReceipt;
    address internal immutable iVictim;
    address internal immutable iAttacker;
    uint256 internal immutable iDrainId;
    uint256 internal immutable iDrainAmount;

    constructor(IERC1155 receipt, address victim, address attacker, uint256 drainId, uint256 drainAmount) {
        iReceipt = receipt;
        iVictim = victim;
        iAttacker = attacker;
        iDrainId = drainId;
        iDrainAmount = drainAmount;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        iReceipt.safeTransferFrom(iVictim, iAttacker, iDrainId, iDrainAmount, "");
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}

/// A benign receiver that does nothing in the callback — models a trusted
/// recipient such as a pass-through mint/deposit wrapper.
contract BenignReceiver is IERC1155Receiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}

/// @title ReceiptSpoofEscalationsTest
/// @notice Regression tests for issue #309 against a free-transfer (no-op
/// authorizer) manager — the worst case. They replay every known escalation of
/// the spoofing attack and assert the fix neutralizes it, and confirm normal
/// ERC1155 approval/revocation semantics are preserved.
contract ReceiptSpoofEscalationsTest is ReceiptFactoryTest {
    function _setup() internal returns (FreeTransferReceiptManager manager, ReceiptContract receipt) {
        manager = new FreeTransferReceiptManager();
        receipt = ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(manager))));
    }

    /// E1 (neutralized): the atomic same-tx drain of the victim's pre-existing
    /// receipts now reverts. Post-fix `_msgSender()` during the callback is the
    /// malicious receiver, so its `safeTransferFrom(victim, ...)` fails OZ's
    /// approval check, reverting the whole malicious deposit. The victim's
    /// holdings — held at their own EOA, no custody needed — are untouched.
    function testAtomicDrainAttemptRevertsAndPreservesHoldings(uint256 legitAmount) external {
        legitAmount = bound(legitAmount, 1, type(uint128).max);

        (FreeTransferReceiptManager manager, ReceiptContract receipt) = _setup();
        address victim = makeAddr("victim");
        address attacker = makeAddr("attacker");
        uint256 legitId = 1;

        manager.mint(receipt, victim, victim, legitId, legitAmount, "");
        assertEq(receipt.balanceOf(victim, legitId), legitAmount);

        AtomicDrainReceiver drainer =
            new AtomicDrainReceiver(IERC1155(address(receipt)), victim, attacker, legitId, legitAmount);

        // The malicious deposit reverts because the drainer is not approved to
        // move the victim's receipts (no spoof).
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, address(drainer), victim)
        );
        manager.mint(receipt, victim, address(drainer), 2, 1, "");

        // Victim keeps everything; attacker got nothing.
        assertEq(receipt.balanceOf(victim, legitId), legitAmount, "victim's receipts untouched");
        assertEq(receipt.balanceOf(attacker, legitId), 0, "attacker drained nothing");
    }

    /// E2 (neutralized): no operator approval is spoofed onto the victim, so
    /// receipts the victim acquires later are NOT reachable by the attacker. The
    /// approval the malicious callback makes lands on the receiver itself.
    function testNoSpoofedApprovalSoFutureReceiptsSafe(uint256 futureAmount) external {
        futureAmount = bound(futureAmount, 1, type(uint128).max);

        (FreeTransferReceiptManager manager, ReceiptContract receipt) = _setup();
        address victim = makeAddr("victim");
        address attacker = makeAddr("attacker");

        ApprovalSpoofReceiver malicious = new ApprovalSpoofReceiver(IERC1155(address(receipt)), attacker);

        // The malicious deposit succeeds (mints to the receiver) but grants the
        // victim NO approval.
        manager.mint(receipt, victim, address(malicious), 1, 1, "");
        assertFalse(receipt.isApprovedForAll(victim, attacker), "victim not spoofed into approving attacker");
        assertTrue(receipt.isApprovedForAll(address(malicious), attacker), "approval landed on the true caller");

        // The victim later acquires receipts; the attacker cannot take them.
        uint256 futureId = 2;
        manager.mint(receipt, victim, victim, futureId, futureAmount, "");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, attacker, victim));
        receipt.safeTransferFrom(victim, attacker, futureId, futureAmount, "");
    }

    /// A deposit routed through a benign receiver (the mint-wrapper pattern) is
    /// unaffected and grants no approval — sanity that legitimate
    /// contract-recipient deposits still work.
    function testBenignReceiverDepositIsUnaffected(uint256 legitAmount, uint256 depositAmount) external {
        legitAmount = bound(legitAmount, 1, type(uint128).max);
        depositAmount = bound(depositAmount, 1, type(uint128).max);

        (FreeTransferReceiptManager manager, ReceiptContract receipt) = _setup();
        address victim = makeAddr("victim");
        address attacker = makeAddr("attacker");

        manager.mint(receipt, victim, victim, 1, legitAmount, "");

        BenignReceiver wrapper = new BenignReceiver();
        manager.mint(receipt, victim, address(wrapper), 2, depositAmount, "");

        assertFalse(receipt.isApprovedForAll(victim, attacker), "no approval granted");
        assertEq(receipt.balanceOf(victim, 1), legitAmount, "pre-existing receipts untouched");
        assertEq(receipt.balanceOf(address(wrapper), 2), depositAmount, "wrapper received the deposit");
    }

    /// Approval revocation works as standard ERC1155 (the fix does not override
    /// `_msgSender()`, so approvals are managed by the true caller): a victim can
    /// grant an operator, the operator can transfer, and after revocation the
    /// operator can no longer transfer.
    function testApprovalRevocationWorks(uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);

        (FreeTransferReceiptManager manager, ReceiptContract receipt) = _setup();
        address victim = makeAddr("victim");
        address operator = makeAddr("operator");
        uint256 id = 1;

        manager.mint(receipt, victim, victim, id, amount, "");

        // Grant.
        vm.prank(victim);
        receipt.setApprovalForAll(operator, true);
        assertTrue(receipt.isApprovedForAll(victim, operator));

        // Operator can move the victim's receipts while approved.
        vm.prank(operator);
        receipt.safeTransferFrom(victim, operator, id, amount, "");
        assertEq(receipt.balanceOf(operator, id), amount);

        // Revoke; the operator can no longer move anything.
        vm.prank(victim);
        receipt.setApprovalForAll(operator, false);
        assertFalse(receipt.isApprovedForAll(victim, operator));

        uint256 id2 = 2;
        manager.mint(receipt, victim, victim, id2, amount, "");
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, operator, victim));
        receipt.safeTransferFrom(victim, operator, id2, amount, "");
    }
}
