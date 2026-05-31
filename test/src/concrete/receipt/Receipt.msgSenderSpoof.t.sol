// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {TestReceiptManager} from "test/concrete/TestReceiptManager.sol";
import {ApprovalSpoofReceiver} from "test/concrete/ApprovalSpoofReceiver.sol";
import {ReceiptFactoryTest} from "test/abstract/ReceiptFactoryTest.sol";
import {IERC1155} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155.sol";

/// @title ReceiptMsgSenderSpoofTest
/// @notice Regression test for issue #309: an ERC1155 acceptance callback must
/// NOT be able to spoof the depositor's identity. With the fix (no `_msgSender`
/// override), the callback observes the true `msg.sender` (the malicious
/// receiver), so a `setApprovalForAll` made during the callback lands on the
/// receiver itself, never on the spoofed depositor.
contract ReceiptMsgSenderSpoofTest is ReceiptFactoryTest {
    /// The vault calls `managerMint(victim, maliciousReceiver, ...)` when the
    /// victim deposits with a malicious contract as `receiver`. `_mint` fires
    /// `onERC1155Received` on the malicious receiver, which calls
    /// `setApprovalForAll(attacker, true)`. Pre-fix this was recorded as the
    /// victim (spoofed `_msgSender()`); post-fix it is recorded as the malicious
    /// receiver (the true caller), so the victim is never made to approve anyone.
    function testReceiptMsgSenderSpoofGrantsOperatorApproval(uint256 id, uint256 amount, bytes memory data) external {
        amount = bound(amount, 1, type(uint256).max);

        address victim = makeAddr("victim");
        address attacker = makeAddr("attacker");

        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        ApprovalSpoofReceiver maliciousReceiver = new ApprovalSpoofReceiver(IERC1155(address(receipt)), attacker);

        // The mint transfers from address(0) to the malicious receiver; both
        // must be authorized for `_update` to pass.
        testManager.setFrom(address(0));
        testManager.setTo(address(maliciousReceiver));

        assertFalse(receipt.isApprovedForAll(victim, attacker), "precondition: no approval");

        vm.prank(victim);
        testManager.managerMint(receipt, address(maliciousReceiver), id, amount, data);

        // FIXED (#309): the spoof is gone. The victim was NOT made to approve the
        // attacker...
        assertFalse(
            receipt.isApprovedForAll(victim, attacker), "victim must not be spoofed into approving the attacker"
        );

        // ...the approval the malicious callback made is attributed to the
        // malicious receiver itself (the true `msg.sender`), which is harmless.
        assertTrue(
            receipt.isApprovedForAll(address(maliciousReceiver), attacker),
            "callback approval lands on the true caller, not the victim"
        );
    }
}
