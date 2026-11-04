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

    /// Dirty bits above either address revert in the decode.
    function testDecodeCanonicalDirtyAddressBits(
        address authority,
        bytes32 name,
        OffchainAssetReceiptVaultRbacV1 memory rbac,
        uint96 dirt,
        bool dirtyOwner
    ) external {
        vm.assume(dirt != 0);
        bytes memory value = abi.encode(rbac);
        uint256 offset = dirtyOwner ? 0x20 : 0x40;
        assembly ("memory-safe") {
            let p := add(value, offset)
            mstore(p, or(mload(p), shl(160, dirt)))
        }
        vm.expectRevert(bytes(""));
        this.decodeCanonicalExternal(authority, name, value);
    }

    /// A value shorter than the two-word encoding reverts in the decode.
    function testDecodeCanonicalShort(address authority, bytes32 name, bytes memory value) external {
        vm.assume(value.length < 0x40);
        vm.expectRevert(bytes(""));
        this.decodeCanonicalExternal(authority, name, value);
    }
}
