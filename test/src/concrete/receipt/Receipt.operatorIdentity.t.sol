// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {IReceiptV3} from "src/interface/IReceiptV3.sol";
import {IReceiptManagerV2} from "src/interface/IReceiptManagerV2.sol";
import {ReceiptFactoryTest} from "test/abstract/ReceiptFactoryTest.sol";
import {IERC1155Receiver} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155Receiver.sol";

/// @title SpyReceiptManager
/// @notice Manager that authorizes ALL transfers and records the
/// `(operator, from, to)` of the most recent `authorizeReceiptTransfer3` call,
/// so tests can assert exactly what operator identity the receipt forwards. The
/// `mint`/`burn`/`transferFrom` helpers forward to the manager-gated functions
/// with an explicit `sender`.
contract SpyReceiptManager is IReceiptManagerV2 {
    address public lastOperator;
    address public lastFrom;
    address public lastTo;

    function authorizeReceiptTransfer3(address operator, address from, address to, uint256[] memory, uint256[] memory)
        external
    {
        lastOperator = operator;
        lastFrom = from;
        lastTo = to;
    }

    function mint(IReceiptV3 receipt, address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
    {
        receipt.managerMint(sender, account, id, amount, data);
    }

    function burn(IReceiptV3 receipt, address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
    {
        receipt.managerBurn(sender, account, id, amount, data);
    }

    function transferFrom(
        IReceiptV3 receipt,
        address sender,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external {
        receipt.managerTransferFrom(sender, from, to, id, amount, data);
    }
}

/// Records the `operator` it is told about in the ERC1155 acceptance callback.
contract RecordingReceiver is IERC1155Receiver {
    address public lastOperator;

    function onERC1155Received(address operator, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        lastOperator = operator;
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address operator, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        returns (bytes4)
    {
        lastOperator = operator;
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}

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
