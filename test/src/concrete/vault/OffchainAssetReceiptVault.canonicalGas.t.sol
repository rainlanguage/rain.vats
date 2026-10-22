// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, console2} from "forge-std-1.17.0/src/Test.sol";
import {
    OffchainAssetReceiptVaultConfigV3,
    OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V3_TAG
} from "../../../../src/interface/IOffchainAssetReceiptVaultV1.sol";

/// @title OffchainAssetReceiptVaultCanonicalGasTest
/// The cost of `initialize`'s canonical-encoding check, decode then re-encode
/// and compare hashes, on a typical token config.
contract OffchainAssetReceiptVaultCanonicalGasTest is Test {
    function canonical(bytes memory data) internal pure returns (bool) {
        (bytes32 version, OffchainAssetReceiptVaultConfigV3 memory config) =
            abi.decode(data, (bytes32, OffchainAssetReceiptVaultConfigV3));
        return keccak256(abi.encode(version, config)) == keccak256(data);
    }

    function testCanonicalCheckGas() external view {
        bytes memory data = abi.encode(
            OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V3_TAG,
            OffchainAssetReceiptVaultConfigV3({
                name: "Tesla, Inc. ST0x",
                symbol: "tTSLA",
                authority: address(0x0b300013CD54a8F1aC40981f80FaaA18b8Cc1E4c),
                rbacName: keccak256("st0x.rbac.us.v1"),
                metadata: ""
            })
        );
        uint256 before = gasleft();
        bool ok = canonical(data);
        uint256 spent = before - gasleft();
        assertTrue(ok);
        console2.log("canonical check gas:", spent);
    }
}
