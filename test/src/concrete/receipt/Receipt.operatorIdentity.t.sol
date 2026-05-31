// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {ReceiptFactoryTest} from "test/abstract/ReceiptFactoryTest.sol";
import {SpyReceiptManager} from "test/concrete/SpyReceiptManager.sol";
import {RecordingReceiver} from "test/concrete/RecordingReceiver.sol";
import {ReentrantTransferReceiver} from "test/concrete/ReentrantTransferReceiver.sol";
import {IERC1155} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155.sol";

/// @title ReceiptOperatorIdentityTest
/// @notice Validates the operator identity the #309 fix forwards to
/// `authorizeReceiptTransfer3`: it must be the true initiator (the explicit
/// `sender` the vault passes for manager calls, the real caller for direct
/// peer transfers), never the vault and never spoofable. Also confirms the
/// acceptance callback observes the true `msg.sender`, and that the operator is
/// scoped to the manager call (reset afterwards).
contract ReceiptOperatorIdentityTest is ReceiptFactoryTest {
    function _setup() internal returns (SpyReceiptManager manager, ReceiptContract receipt) {
        manager = new SpyReceiptManager();
        receipt = ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(manager))));
    }

    /// managerMint forwards the explicit `sender` as the authorization operator.
    function testManagerMintOperatorIsSender(uint256 id, uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);
        (SpyReceiptManager manager, ReceiptContract receipt) = _setup();
        address sender = makeAddr("sender");
        address account = makeAddr("account");

        manager.mint(receipt, sender, account, id, amount, "");

        assertEq(manager.lastOperator(), sender, "mint operator is the explicit sender");
        assertEq(manager.lastFrom(), address(0));
        assertEq(manager.lastTo(), account);
    }

    /// managerBurn forwards the explicit `sender` as the authorization operator.
    function testManagerBurnOperatorIsSender(uint256 id, uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);
        (SpyReceiptManager manager, ReceiptContract receipt) = _setup();
        address holder = makeAddr("holder");
        address burnSender = makeAddr("burnSender");

        manager.mint(receipt, makeAddr("mintSender"), holder, id, amount, "");
        manager.burn(receipt, burnSender, holder, id, amount, "");

        assertEq(manager.lastOperator(), burnSender, "burn operator is the explicit sender");
        assertEq(manager.lastFrom(), holder);
        assertEq(manager.lastTo(), address(0));
    }

    /// managerTransferFrom forwards the explicit `sender` (e.g. a confiscator)
    /// as the authorization operator — preserving the confiscation authz path.
    function testManagerTransferFromOperatorIsSender(uint256 id, uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);
        (SpyReceiptManager manager, ReceiptContract receipt) = _setup();
        address from = makeAddr("from");
        address to = makeAddr("to");
        address confiscator = makeAddr("confiscator");

        manager.mint(receipt, makeAddr("mintSender"), from, id, amount, "");
        manager.transferFrom(receipt, confiscator, from, to, id, amount, "");

        assertEq(manager.lastOperator(), confiscator, "transfer operator is the explicit sender");
        assertEq(manager.lastFrom(), from);
        assertEq(manager.lastTo(), to);
    }

    /// A direct peer-to-peer transfer (no manager call) forwards the REAL caller
    /// as the operator — `_msgSender()` is no longer overridden.
    function testDirectTransferOperatorIsCaller(uint256 id, uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);
        (SpyReceiptManager manager, ReceiptContract receipt) = _setup();
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        manager.mint(receipt, alice, alice, id, amount, "");

        vm.prank(alice);
        receipt.safeTransferFrom(alice, bob, id, amount, "");

        assertEq(manager.lastOperator(), alice, "direct transfer operator is the caller");
        assertEq(manager.lastFrom(), alice);
        assertEq(manager.lastTo(), bob);
    }

    /// An approved-operator transfer forwards the OPERATOR (the caller), not the
    /// token owner — standard ERC1155 operator semantics, preserved.
    function testApprovedOperatorTransferOperatorIsOperator(uint256 id, uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);
        (SpyReceiptManager manager, ReceiptContract receipt) = _setup();
        address alice = makeAddr("alice");
        address operator = makeAddr("operator");
        address bob = makeAddr("bob");

        manager.mint(receipt, alice, alice, id, amount, "");

        vm.prank(alice);
        receipt.setApprovalForAll(operator, true);

        vm.prank(operator);
        receipt.safeTransferFrom(alice, bob, id, amount, "");

        assertEq(manager.lastOperator(), operator, "operator transfer forwards the operator, not the owner");
    }

    /// The acceptance callback observes the true `msg.sender` (the manager that
    /// called `managerMint`), NOT the spoofed depositor — the core of the #309
    /// fix at the callback layer.
    function testCallbackOperatorIsNotSpoofed(uint256 id, uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);
        (SpyReceiptManager manager, ReceiptContract receipt) = _setup();
        address depositor = makeAddr("depositor");
        RecordingReceiver receiver = new RecordingReceiver();

        manager.mint(receipt, depositor, address(receiver), id, amount, "");

        assertEq(receiver.lastOperator(), address(manager), "callback sees the true caller (manager)");
        assertTrue(receiver.lastOperator() != depositor, "callback operator is NOT the spoofed depositor");
    }

    /// The operator is scoped to the manager call: after `managerMint` returns,
    /// a subsequent direct transfer uses the real caller, not a stale operator.
    function testOperatorResetsAfterManagerCall(uint256 id, uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);
        (SpyReceiptManager manager, ReceiptContract receipt) = _setup();
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        address carol = makeAddr("carol");

        // managerMint sets the operator to `alice` then resets it.
        manager.mint(receipt, alice, bob, id, amount, "");

        // A later direct transfer by bob must record bob, not a stale `alice`.
        vm.prank(bob);
        receipt.safeTransferFrom(bob, carol, id, amount, "");

        assertEq(manager.lastOperator(), bob, "operator was reset; direct caller is used");
    }

    /// Edge case of the consume-once sentinel: `address(0)` doubles as the "no
    /// operator set" marker, so a manager call that passes `sender == address(0)`
    /// is indistinguishable from a direct transfer and falls back to forwarding
    /// the true caller (the manager) as the operator — never `address(0)` itself.
    /// This is benign (real vaults never pass a zero initiator: `_msgSender()`
    /// cannot be the zero address), but pinning it guards the sentinel logic
    /// against silent change.
    function testManagerCallWithZeroSenderFallsBackToCaller(uint256 id, uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);
        (SpyReceiptManager manager, ReceiptContract receipt) = _setup();
        address account = makeAddr("account");

        manager.mint(receipt, address(0), account, id, amount, "");

        assertEq(manager.lastOperator(), address(manager), "zero sender falls back to the caller, not address(0)");
        assertTrue(manager.lastOperator() != address(0), "operator is never the zero sentinel");
        assertEq(manager.lastFrom(), address(0));
        assertEq(manager.lastTo(), account);
    }

    /// The batch entrypoint forwards the same operator identity as the single
    /// one: a direct `safeBatchTransferFrom` forwards the real caller.
    function testDirectBatchTransferOperatorIsCaller(uint256 id, uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);
        (SpyReceiptManager manager, ReceiptContract receipt) = _setup();
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        manager.mint(receipt, alice, alice, id, amount, "");

        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        vm.prank(alice);
        receipt.safeBatchTransferFrom(alice, bob, ids, amounts, "");

        assertEq(manager.lastOperator(), alice, "direct batch transfer operator is the caller");
    }

    /// An approved-operator `safeBatchTransferFrom` forwards the operator, not
    /// the owner.
    function testApprovedOperatorBatchTransferOperatorIsOperator(uint256 id, uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);
        (SpyReceiptManager manager, ReceiptContract receipt) = _setup();
        address alice = makeAddr("alice");
        address operator = makeAddr("operator");
        address bob = makeAddr("bob");

        manager.mint(receipt, alice, alice, id, amount, "");

        vm.prank(alice);
        receipt.setApprovalForAll(operator, true);

        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        vm.prank(operator);
        receipt.safeBatchTransferFrom(alice, bob, ids, amounts, "");

        assertEq(manager.lastOperator(), operator, "batch operator transfer forwards the operator");
    }

    /// A transfer that RE-ENTERS during a manager call's acceptance callback uses
    /// its own true caller as the operator, NOT the stale stored operator from
    /// the outer manager call. The stored operator is cleared before the callback
    /// fires, so it cannot leak (e.g. a confiscation-style authz bypass) into
    /// re-entrant transfers.
    function testReentrantTransferDuringCallbackUsesRealCaller(uint256 id, uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);
        (SpyReceiptManager manager, ReceiptContract receipt) = _setup();
        address depositor = makeAddr("depositor");
        address thirdParty = makeAddr("thirdParty");

        ReentrantTransferReceiver receiver =
            new ReentrantTransferReceiver(IERC1155(address(receipt)), thirdParty, id, amount);

        // managerMint delivers to the receiver, which re-enters during its
        // acceptance callback to forward its own tokens to `thirdParty`. That
        // nested transfer is the LAST authz the spy records.
        manager.mint(receipt, depositor, address(receiver), id, amount, "");

        assertEq(manager.lastFrom(), address(receiver), "nested transfer is from the receiver");
        assertEq(manager.lastTo(), thirdParty);
        assertEq(
            manager.lastOperator(),
            address(receiver),
            "re-entrant transfer operator is its true caller, not the stale outer operator"
        );

        // The legitimate nested forward also SUCCEEDS end-to-end: a receiver
        // moving its own just-received tokens during the callback is authorized
        // as itself, so the balances actually move. This is the benign case the
        // consume-once must not break.
        assertEq(receipt.balanceOf(thirdParty, id), amount, "forwarded tokens landed at the third party");
        assertEq(receipt.balanceOf(address(receiver), id), 0, "receiver forwarded everything it received");
    }
}
