// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibERC7201} from "test/lib/LibERC7201.sol";
import {Test} from "forge-std-1.16.1/src/Test.sol";
import {
    ERC20_PRICE_ORACLE_RECEIPT_VAULT_STORAGE_LOCATION,
    ERC20_PRICE_ORACLE_RECEIPT_VAULT_STORAGE_ID
} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";

contract ERC20PriceOracleReceiptVault7201Test is Test {
    function testERC20PriceOracleReceiptVault7201StorageLocation() external pure {
        bytes32 expected = LibERC7201.idForString(ERC20_PRICE_ORACLE_RECEIPT_VAULT_STORAGE_ID);
        bytes32 actual = ERC20_PRICE_ORACLE_RECEIPT_VAULT_STORAGE_LOCATION;
        assertEq(actual, expected);
    }
}
