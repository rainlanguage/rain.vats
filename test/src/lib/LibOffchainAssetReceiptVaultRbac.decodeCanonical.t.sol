// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    LibOffchainAssetReceiptVaultRbac,
    OffchainAssetReceiptVaultRbacV1,
    NonCanonicalRbac
} from "../../../src/lib/LibOffchainAssetReceiptVaultRbac.sol";

contract LibOffchainAssetReceiptVaultRbacDecodeCanonicalTest is Test {
    function decodeCanonicalExternal(address authority, bytes32 name, bytes memory value)
        external
        pure
        returns (OffchainAssetReceiptVaultRbacV1 memory)
    {
        return LibOffchainAssetReceiptVaultRbac.decodeCanonical(authority, name, value);
    }

    /// The canonical encoding of any binding decodes to that binding.
    function testDecodeCanonicalRoundTrip(address authority, bytes32 name, OffchainAssetReceiptVaultRbacV1 memory rbac)
        external
        view
    {
        OffchainAssetReceiptVaultRbacV1 memory decoded = this.decodeCanonicalExternal(authority, name, abi.encode(rbac));
        assertEq(decoded.owner, rbac.owner);
        assertEq(abi.encode(decoded), abi.encode(rbac));
    }

    /// Trailing bytes revert, reporting the authority and name passed in.
    function testDecodeCanonicalTrailingBytes(
        address authority,
        bytes32 name,
        OffchainAssetReceiptVaultRbacV1 memory rbac,
        bytes memory trailing
    ) external {
        vm.assume(trailing.length > 0);
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalRbac.selector, authority, name));
        this.decodeCanonicalExternal(authority, name, bytes.concat(abi.encode(rbac), trailing));
    }

    /// A non-canonical array offset reverts: the array is moved one word
    /// further from the head than `abi.encode` places it.
    function testDecodeCanonicalNonCanonicalOffset(address authority, bytes32 name, address owner) external {
        bytes memory value = abi.encode(uint256(0x20), owner, uint256(0x60), uint256(0), uint256(0));
        OffchainAssetReceiptVaultRbacV1 memory decoded = abi.decode(value, (OffchainAssetReceiptVaultRbacV1));
        assertEq(decoded.owner, owner);
        assertEq(decoded.authorizers.length, 0);
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalRbac.selector, authority, name));
        this.decodeCanonicalExternal(authority, name, value);
    }

    /// A non-canonical value exactly as long as its canonical re-encoding
    /// reverts: the array offset points at its own word, which reads as a
    /// length of 32, and one padding word fills the length gap.
    function testDecodeCanonicalSameLengthNonCanonical(
        address authority,
        bytes32 name,
        address owner,
        address authorizer,
        bytes32 pad
    ) external {
        bytes memory value = abi.encode(uint256(0x20), owner, uint256(0x20));
        for (uint256 i = 0; i < 32; i++) {
            value = bytes.concat(value, abi.encode(authorizer));
        }
        value = bytes.concat(value, pad);
        OffchainAssetReceiptVaultRbacV1 memory decoded = abi.decode(value, (OffchainAssetReceiptVaultRbacV1));
        assertEq(decoded.authorizers.length, 32);
        assertEq(abi.encode(decoded).length, value.length);
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalRbac.selector, authority, name));
        this.decodeCanonicalExternal(authority, name, value);
    }
}
