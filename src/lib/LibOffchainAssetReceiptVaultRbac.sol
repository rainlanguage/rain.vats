// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/IBeacon.sol";

import {IAuthorizeV1} from "../interface/IAuthorizeV1.sol";

/// Thrown when an RBAC binding is not the canonical ABI encoding of
/// `OffchainAssetReceiptVaultRbacV1`.
/// @param authority The authority the binding was resolved under.
/// @param name The name the binding was resolved from.
error NonCanonicalRbac(address authority, bytes32 name);

/// The value a `ConfigRegistry` authority binds an RBAC name to, ABI encoded.
/// @param owner The owner of every vault initialized from the binding.
/// @param receiptBeacon The beacon every vault initialized from the binding
/// makes its receipt a proxy of, bound per chain because a chain's beacons
/// are its own. Its owner MUST be the vault beacon's owner.
/// @param authorizers The authorizers a vault may select from by index.
struct OffchainAssetReceiptVaultRbacV1 {
    address owner;
    IBeacon receiptBeacon;
    IAuthorizeV1[] authorizers;
}

/// @title LibOffchainAssetReceiptVaultRbac
/// @notice Decodes an `OffchainAssetReceiptVaultRbacV1` binding, accepting
/// only its canonical encoding, so a binder can run the same check before
/// `registerV1` that a vault runs at `initialize`.
library LibOffchainAssetReceiptVaultRbac {
    /// @param authority The authority the binding is under. Only reported in
    /// the revert.
    /// @param name The name the binding is under. Only reported in the revert.
    /// @param value The bound value.
    /// @return The decoded binding.
    function decodeCanonical(address authority, bytes32 name, bytes memory value)
        internal
        pure
        returns (OffchainAssetReceiptVaultRbacV1 memory)
    {
        OffchainAssetReceiptVaultRbacV1 memory rbac = abi.decode(value, (OffchainAssetReceiptVaultRbacV1));
        // `abi.decode` ignores trailing bytes and accepts non-canonical
        // offsets; re-encoding and comparing rejects both.
        if (keccak256(abi.encode(rbac)) != keccak256(value)) {
            revert NonCanonicalRbac(authority, name);
        }
        return rbac;
    }
}
