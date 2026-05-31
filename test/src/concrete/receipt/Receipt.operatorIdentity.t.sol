// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {ReceiptFactoryTest} from "test/abstract/ReceiptFactoryTest.sol";
import {SpyReceiptManager} from "test/concrete/SpyReceiptManager.sol";
import {RecordingReceiver} from "test/concrete/RecordingReceiver.sol";

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
}
