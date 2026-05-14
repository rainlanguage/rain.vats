// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibERC7201} from "test/lib/LibERC7201.sol";
import {Test} from "forge-std-1.16.1/src/Test.sol";
import {
    OFFCHAIN_ASSET_RECEIPT_VAULT_STORAGE_LOCATION,
    OFFCHAIN_ASSET_RECEIPT_VAULT_STORAGE_ID
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";

contract OffchainAssetReceiptVault7201Test is Test {
    function testOffchainAssetReceiptVault7201StorageLocation() external pure {
        bytes32 expected = LibERC7201.idForString(OFFCHAIN_ASSET_RECEIPT_VAULT_STORAGE_ID);
        bytes32 actual = OFFCHAIN_ASSET_RECEIPT_VAULT_STORAGE_LOCATION;
        assertEq(actual, expected);
    }
}
