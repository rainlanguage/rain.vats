// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibERC7201} from "test/lib/LibERC7201.sol";
import {Test} from "forge-std-1.16.1/src/Test.sol";

import {
    OFFCHAIN_ASSET_RECEIPT_VAULT_PAYMENT_MINT_AUTHORIZER_V1_STORAGE_LOCATION,
    OFFCHAIN_ASSET_RECEIPT_VAULT_PAYMENT_MINT_AUTHORIZER_V1_STORAGE_ID
} from "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";

contract OffchainAssetReceiptVaultPaymentMintAuthorizerV17201Test is Test {
    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1StorageLocation() external pure {
        bytes32 expected = LibERC7201.idForString(OFFCHAIN_ASSET_RECEIPT_VAULT_PAYMENT_MINT_AUTHORIZER_V1_STORAGE_ID);
        bytes32 actual = OFFCHAIN_ASSET_RECEIPT_VAULT_PAYMENT_MINT_AUTHORIZER_V1_STORAGE_LOCATION;
        assertEq(actual, expected);
    }
}
