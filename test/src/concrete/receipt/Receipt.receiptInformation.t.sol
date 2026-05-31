// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {IReceiptV3} from "src/interface/IReceiptV3.sol";
import {ReceiptFactoryTest} from "test/abstract/ReceiptFactoryTest.sol";
import {FreeTransferReceiptManager} from "test/concrete/FreeTransferReceiptManager.sol";
import {SpyReceiptManager} from "test/concrete/SpyReceiptManager.sol";

/// @title ReceiptReceiptInformationTest
/// @notice Covers the `ReceiptInformation` attribution after the #309 fix. The
/// auditor's recommendation was to pass the depositor explicitly to
/// `_receiptInformation` (rather than via a spoofed `_msgSender()`); these tests
/// isolate three distinct addresses (depositor/recipient/manager, or caller) and
/// assert the event's `sender` field is the correct one. The existing
/// `Receipt.t.sol` coverage uses `sender == account`, so it cannot distinguish
/// which identity the event uses.
contract ReceiptReceiptInformationTest is ReceiptFactoryTest {
    /// managerMint attributes `ReceiptInformation` to the explicit depositor
    /// (`sender`), NOT the recipient (`account`) and NOT the manager/caller.
    function testManagerMintAttributesInformationToSender(uint256 id, uint256 amount, bytes memory data) external {
        amount = bound(amount, 1, type(uint128).max);
        vm.assume(data.length > 0);

        address depositor = makeAddr("depositor");
        address recipient = makeAddr("recipient");

        FreeTransferReceiptManager manager = new FreeTransferReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(manager))));

        vm.expectEmit(true, true, true, true);
        emit IReceiptV3.ReceiptInformation(depositor, id, data);
        manager.mint(receipt, depositor, recipient, id, amount, data);
    }

    /// managerBurn attributes `ReceiptInformation` to the explicit `sender`, NOT
    /// the holder (`account`) and NOT the manager/caller.
    function testManagerBurnAttributesInformationToSender(uint256 id, uint256 amount, bytes memory data) external {
        amount = bound(amount, 1, type(uint128).max);
        vm.assume(data.length > 0);

        address holder = makeAddr("holder");
        address burnSender = makeAddr("burnSender");

        SpyReceiptManager manager = new SpyReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(manager))));

        manager.mint(receipt, makeAddr("mintSender"), holder, id, amount, "");

        vm.expectEmit(true, true, true, true);
        emit IReceiptV3.ReceiptInformation(burnSender, id, data);
        manager.burn(receipt, burnSender, holder, id, amount, data);
    }

    /// The public `receiptInformation` attributes the event to the real caller —
    /// `_msgSender()` is no longer overridden, so it is the true `msg.sender`.
    function testPublicReceiptInformationAttributesToCaller(uint256 id, bytes memory data) external {
        vm.assume(data.length > 0);

        address alice = makeAddr("alice");

        FreeTransferReceiptManager manager = new FreeTransferReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(manager))));

        vm.expectEmit(true, true, true, true);
        emit IReceiptV3.ReceiptInformation(alice, id, data);
        vm.prank(alice);
        receipt.receiptInformation(id, data);
    }
}
