// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, console2} from "forge-std-1.17.0/src/Test.sol";
import {
    OffchainAssetReceiptVaultConfigV3,
    OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V3_TAG
} from "../../../../src/interface/IOffchainAssetReceiptVaultV1.sol";

/// @title OffchainAssetReceiptVaultCanonicalGasTest
/// What `initialize`'s canonical-encoding check costs on a typical token
/// config, against checking the layout in place with assembly. `initialize`
/// decodes either way, so each is measured on top of the decode.
contract OffchainAssetReceiptVaultCanonicalGasTest is Test {
    /// `initialize`'s check: re-encode the decoded config and compare hashes.
    function reencode(bytes memory data, bytes32 version, OffchainAssetReceiptVaultConfigV3 memory config)
        internal
        pure
        returns (bool)
    {
        return keccak256(abi.encode(version, config)) == keccak256(data);
    }

    /// The same property read off `data` directly: every offset is the one
    /// `abi.encode` writes, every padding byte is zero and nothing trails.
    /// Run after `abi.decode`, which has already bounds-checked every offset
    /// and length.
    function inPlace(bytes memory data) internal pure returns (bool ok) {
        assembly ("memory-safe") {
            function padded(len) -> r {
                r := and(add(len, 0x1f), not(0x1f))
            }
            // Zero iff the bytes after `len` up to the next word are zero.
            function dirt(p, len) -> r {
                let tail := and(len, 0x1f)
                r := 0
                if tail { r := shl(mul(tail, 8), mload(add(p, sub(len, tail)))) }
            }
            let base := add(data, 0x20)
            let tuple := add(base, 0x40)
            ok := eq(mload(add(base, 0x20)), 0x40)
            let nameOffset := mload(tuple)
            ok := and(ok, eq(nameOffset, 0xc0))
            let nameLength := mload(add(tuple, nameOffset))
            let symbolOffset := add(add(nameOffset, 0x20), padded(nameLength))
            ok := and(ok, eq(mload(add(tuple, 0x20)), symbolOffset))
            let symbolLength := mload(add(tuple, symbolOffset))
            let metadataOffset := add(add(symbolOffset, 0x20), padded(symbolLength))
            ok := and(ok, eq(mload(add(tuple, 0xa0)), metadataOffset))
            let metadataLength := mload(add(tuple, metadataOffset))
            ok := and(ok, eq(mload(data), add(add(0x60, metadataOffset), padded(metadataLength))))
            ok := and(ok, iszero(dirt(add(tuple, add(nameOffset, 0x20)), nameLength)))
            ok := and(ok, iszero(dirt(add(tuple, add(symbolOffset, 0x20)), symbolLength)))
            ok := and(ok, iszero(dirt(add(tuple, add(metadataOffset, 0x20)), metadataLength)))
        }
    }

    function decode(bytes memory data) internal pure returns (bytes32, OffchainAssetReceiptVaultConfigV3 memory) {
        return abi.decode(data, (bytes32, OffchainAssetReceiptVaultConfigV3));
    }

    function typical() internal pure returns (bytes memory) {
        return abi.encode(
            OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V3_TAG,
            OffchainAssetReceiptVaultConfigV3({
                name: "Tesla, Inc. ST0x",
                symbol: "tTSLA",
                authority: address(0x0b300013CD54a8F1aC40981f80FaaA18b8Cc1E4c),
                rbacName: keccak256("st0x.rbac.us.v1"),
                receiptBeaconName: keccak256("st0x.receipt-beacon.v1"),
                metadata: ""
            })
        );
    }

    function testCanonicalCheckGas() external view {
        bytes memory data = typical();
        (bytes32 version, OffchainAssetReceiptVaultConfigV3 memory config) = decode(data);

        uint256 before = gasleft();
        bool reencoded = reencode(data, version, config);
        uint256 reencodeGas = before - gasleft();

        before = gasleft();
        bool checked = inPlace(data);
        uint256 inPlaceGas = before - gasleft();

        assertTrue(reencoded);
        assertTrue(checked);
        console2.log("re-encode check gas:", reencodeGas);
        console2.log("in-place assembly check gas:", inPlaceGas);
    }

    /// The two checks agree on every canonical encoding, and on the same
    /// encoding with trailing bytes.
    function testChecksAgree(OffchainAssetReceiptVaultConfigV3 memory config, bytes memory trailing) external pure {
        bytes memory data = abi.encode(OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V3_TAG, config);
        (bytes32 version, OffchainAssetReceiptVaultConfigV3 memory decoded) = decode(data);
        assertTrue(reencode(data, version, decoded));
        assertTrue(inPlace(data));

        if (trailing.length > 0) {
            bytes memory longer = bytes.concat(data, trailing);
            (version, decoded) = decode(longer);
            assertFalse(reencode(longer, version, decoded));
            assertFalse(inPlace(longer));
        }
    }
}
