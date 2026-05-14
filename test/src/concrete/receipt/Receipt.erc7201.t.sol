// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibERC7201} from "test/lib/LibERC7201.sol";
import {Test} from "forge-std-1.16.1/src/Test.sol";
import {RECEIPT_STORAGE_ID, RECEIPT_STORAGE_LOCATION} from "src/concrete/receipt/Receipt.sol";

contract Receipt7201Test is Test {
    function testReceiptStorageLocation() external pure {
        bytes32 expected = LibERC7201.idForString(RECEIPT_STORAGE_ID);
        bytes32 actual = RECEIPT_STORAGE_LOCATION;
        assertEq(actual, expected);
    }
}
