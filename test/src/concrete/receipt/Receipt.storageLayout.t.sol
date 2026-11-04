// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Receipt as ReceiptContract, RECEIPT_STORAGE_LOCATION} from "src/concrete/receipt/Receipt.sol";
import {ReceiptFactoryTest} from "test/abstract/ReceiptFactoryTest.sol";
import {SpyReceiptManager} from "test/concrete/SpyReceiptManager.sol";

/// @title ReceiptStorageLayoutTest
/// @notice Pins the physical erc7201 storage layout of the `Receipt7201Storage`
/// struct: `manager` at the base slot and `operator` at base + 1. This is the
/// upgrade-safety property the #309 fix relies on — it RENAMED the second field
/// (`sender` -> `operator`) but MUST keep the same slot, order and `address`
/// type so existing upgradeable deployments (e.g. st0x) are not corrupted. A
/// future reorder or inserted field would break the consume-once logic and any
/// proxy reading these slots; these tests fail loudly if that happens. The
/// existing `Receipt.erc7201.t.sol` only checks the storage LOCATION constant,
/// not the field offsets.
contract ReceiptStorageLayoutTest is ReceiptFactoryTest {
    /// The `operator` field occupies exactly `RECEIPT_STORAGE_LOCATION + 1`.
    bytes32 internal constant OPERATOR_SLOT = bytes32(uint256(RECEIPT_STORAGE_LOCATION) + 1);

    function _setup() internal returns (SpyReceiptManager manager, ReceiptContract receipt) {
        manager = new SpyReceiptManager();
        receipt = ReceiptContract(cloneReceipt(address(iReceiptImplementation), abi.encode(address(manager))));
    }

    /// `manager` is stored at the base slot (`RECEIPT_STORAGE_LOCATION`).
    function testManagerFieldAtBaseSlot() external {
        (SpyReceiptManager manager, ReceiptContract receipt) = _setup();
        bytes32 raw = vm.load(address(receipt), RECEIPT_STORAGE_LOCATION);
        assertEq(address(uint160(uint256(raw))), address(manager), "manager occupies the base storage slot");
    }

    /// `operator` is stored at base + 1 AND the `_update` consume-once reads from
    /// exactly that slot. Proven without relying on a transient observation: a
    /// sentinel is planted directly into base + 1, then a direct (non-manager)
    /// transfer is performed. The fix reads `s.operator` from base + 1, so it
    /// forwards the planted sentinel as the authorization operator and then
    /// clears the slot — both observable.
    function testOperatorFieldAtSlotPlusOneAndConsumed(uint256 id, uint256 amount, address sentinel) external {
        amount = bound(amount, 1, type(uint128).max);
        vm.assume(sentinel != address(0));

        (SpyReceiptManager manager, ReceiptContract receipt) = _setup();
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        // Fund alice via a manager mint (this consumes/clears the operator slot).
        manager.mint(receipt, alice, alice, id, amount, "");
        assertEq(vm.load(address(receipt), OPERATOR_SLOT), bytes32(0), "operator slot cleared after manager call");

        // Plant a sentinel operator directly into base + 1.
        vm.store(address(receipt), OPERATOR_SLOT, bytes32(uint256(uint160(sentinel))));

        // A direct transfer reads the operator from base + 1: it forwards the
        // sentinel (proving the field offset) rather than the caller.
        vm.prank(alice);
        receipt.safeTransferFrom(alice, bob, id, amount, "");

        assertEq(manager.lastOperator(), sentinel, "operator read from base + 1 (forwarded the planted sentinel)");
        assertEq(vm.load(address(receipt), OPERATOR_SLOT), bytes32(0), "operator slot consumed (cleared) by _update");
    }

    /// Sanity that the two fields are DISTINCT slots: planting the operator
    /// sentinel does not disturb the `manager` field at the base slot.
    function testManagerAndOperatorDoNotAlias(address sentinel) external {
        vm.assume(sentinel != address(0));
        (SpyReceiptManager manager, ReceiptContract receipt) = _setup();

        vm.store(address(receipt), OPERATOR_SLOT, bytes32(uint256(uint160(sentinel))));

        bytes32 raw = vm.load(address(receipt), RECEIPT_STORAGE_LOCATION);
        assertEq(address(uint160(uint256(raw))), address(manager), "manager slot unaffected by operator slot write");
        assertEq(receipt.manager(), address(manager), "manager() accessor still returns the manager");
    }
}
