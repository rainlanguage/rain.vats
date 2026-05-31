// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {ReceiptFactoryTest} from "test/abstract/ReceiptFactoryTest.sol";
import {FreezeSimReceiptManager, NotPrivileged} from "test/concrete/FreezeSimReceiptManager.sol";
import {ReentrantLeakReceiver} from "test/concrete/ReentrantLeakReceiver.sol";
import {IERC1155} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155.sol";

/// @title ReceiptOperatorLeakTest
/// @notice Proves the SECURITY consequence of the #309 consume-once operator,
/// not just the operator identity: against a privilege-gated manager (only a
/// designated handler may move receipts), a transfer that re-enters during an
/// acceptance callback must NOT inherit the privileged operator of the outer
/// manager call. The receipt consumes (clears) the stored operator before the
/// callback fires, so the re-entrant transfer authorizes as the (unprivileged)
/// receiver and is denied — closing the operator-leak freeze-evasion vector.
contract ReceiptOperatorLeakTest is ReceiptFactoryTest {
    function _setup(address privileged) internal returns (FreezeSimReceiptManager manager, ReceiptContract receipt) {
        manager = new FreezeSimReceiptManager(privileged);
        receipt = ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(manager))));
    }

    /// The privileged operator does not leak into a re-entrant transfer. A mint
    /// runs under the privileged operator and delivers to a malicious receiver;
    /// the receiver re-enters to forward the tokens to an attacker, but that
    /// nested transfer authorizes as the receiver (unprivileged) and is denied.
    function testPrivilegedOperatorDoesNotLeakIntoReentrantTransfer(uint256 id, uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);
        address privileged = makeAddr("privileged");
        address attacker = makeAddr("attacker");
        (FreezeSimReceiptManager manager, ReceiptContract receipt) = _setup(privileged);

        ReentrantLeakReceiver receiver = new ReentrantLeakReceiver(IERC1155(address(receipt)), attacker, id, amount);

        // Mint to the receiver under the PRIVILEGED operator (mints are always
        // allowed). The receiver re-enters during its acceptance callback.
        manager.mint(receipt, privileged, address(receiver), id, amount, "");

        // The nested transfer was attempted but DENIED — no operator leak, so it
        // authorized as the unprivileged receiver.
        assertTrue(receiver.nestedAttempted(), "receiver attempted the re-entrant transfer");
        assertFalse(receiver.nestedSucceeded(), "re-entrant transfer denied: privileged operator did not leak");
        assertEq(receipt.balanceOf(attacker, id), 0, "attacker received nothing");
        assertEq(receipt.balanceOf(address(receiver), id), amount, "receiver kept its receipts");

        // The nested transfer was rejected SPECIFICALLY because its operator was
        // the receiver, not the privileged handler — i.e. the privileged operator
        // did not leak. (The manager's `lastOperator` write during the nested
        // call is rolled back by the revert, so the captured revert data is the
        // reliable witness.)
        assertEq(
            receiver.nestedRevertData(),
            abi.encodeWithSelector(NotPrivileged.selector, address(receiver)),
            "nested transfer rejected as the unprivileged receiver operator"
        );
    }

    /// Positive control: the SAME peer transfer succeeds when the manager runs it
    /// under the privileged operator — confirming the denial above is purely the
    /// operator identity (receiver vs privileged), i.e. the gate works and the
    /// only thing stopping the attacker is the absence of a leak.
    function testPrivilegedOperatorCanMoveTheSameReceipts(uint256 id, uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);
        address privileged = makeAddr("privileged");
        address holder = makeAddr("holder");
        address attacker = makeAddr("attacker");
        (FreezeSimReceiptManager manager, ReceiptContract receipt) = _setup(privileged);

        manager.mint(receipt, privileged, holder, id, amount, "");

        // Under the privileged operator the manager moves the holder's receipts.
        manager.transferFrom(receipt, privileged, holder, attacker, id, amount, "");
        assertEq(receipt.balanceOf(attacker, id), amount, "privileged operator moved the receipts");
        assertEq(receipt.balanceOf(holder, id), 0, "holder's receipts moved");
    }

    /// And an UNPRIVILEGED operator is rejected for the same peer transfer,
    /// pinning that the gate is keyed on the forwarded operator identity.
    function testUnprivilegedOperatorIsRejected(uint256 id, uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);
        address privileged = makeAddr("privileged");
        address intruder = makeAddr("intruder");
        address holder = makeAddr("holder");
        address attacker = makeAddr("attacker");
        (FreezeSimReceiptManager manager, ReceiptContract receipt) = _setup(privileged);

        manager.mint(receipt, privileged, holder, id, amount, "");

        vm.expectRevert(abi.encodeWithSelector(NotPrivileged.selector, intruder));
        manager.transferFrom(receipt, intruder, holder, attacker, id, amount, "");
    }
}
