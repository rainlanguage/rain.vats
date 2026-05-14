// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibERC7201} from "test/lib/LibERC7201.sol";
import {Test} from "forge-std-1.16.1/src/Test.sol";
import {RECEIPT_VAULT_V1_STORAGE_ID, RECEIPT_VAULT_V1_STORAGE_LOCATION} from "src/abstract/ReceiptVault.sol";

contract ReceiptVaultERC7201Test is Test {
    function testReceiptVaultStorageLocation() external pure {
        bytes32 expected = LibERC7201.idForString(RECEIPT_VAULT_V1_STORAGE_ID);
        bytes32 actual = RECEIPT_VAULT_V1_STORAGE_LOCATION;
        assertEq(actual, expected);
    }
}
