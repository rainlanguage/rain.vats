// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IReceiptManagerV2, IReceiptVaultV3, ICloneableV2} from "src/abstract/ReceiptVault.sol";
import {Test} from "forge-std-1.16.1/src/Test.sol";
import {ConcreteReceiptVault} from "test/concrete/ConcreteReceiptVault.sol";

import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";

contract ReceiptVaultIERC165Test is Test {
    function testReceiptVaultIERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(IReceiptManagerV2).interfaceId);
        vm.assume(badInterfaceId != type(IReceiptVaultV3).interfaceId);
        vm.assume(badInterfaceId != type(ICloneableV2).interfaceId);

        ConcreteReceiptVault receiptVault = new ConcreteReceiptVault();
        assertTrue(receiptVault.supportsInterface(type(IERC165).interfaceId));
        assertTrue(receiptVault.supportsInterface(type(IReceiptManagerV2).interfaceId));
        assertTrue(receiptVault.supportsInterface(type(IReceiptVaultV3).interfaceId));
        assertTrue(receiptVault.supportsInterface(type(ICloneableV2).interfaceId));

        assertFalse(receiptVault.supportsInterface(badInterfaceId));
    }
}
