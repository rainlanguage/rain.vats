// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IAuthorizeV1} from "../interface/IAuthorizeV1.sol";

/// Thrown when an RBAC binding is not the canonical ABI encoding of
/// `OffchainAssetReceiptVaultRbacV1`.
/// @param authority The authority the binding was resolved under.
/// @param name The name the binding was resolved from.
error NonCanonicalRbac(address authority, bytes32 name);

/// The value a `ConfigRegistry` authority binds an RBAC name to, ABI encoded.
/// @param owner The owner of every vault initialized from the binding.
/// @param authorizer The authorizer of every vault initialized from the
/// binding.
struct OffchainAssetReceiptVaultRbacV1 {
    address owner;
    IAuthorizeV1 authorizer;
}

/// The ABI type `OffchainAssetReceiptVaultRbacV1` is registered under.
string constant OFFCHAIN_ASSET_RECEIPT_VAULT_RBAC_V1_VALUE_TYPE = "(address,address)";

bytes32 constant OFFCHAIN_ASSET_RECEIPT_VAULT_RBAC_V1_VALUE_TYPE_HASH =
    keccak256(bytes(OFFCHAIN_ASSET_RECEIPT_VAULT_RBAC_V1_VALUE_TYPE));

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
        // `abi.decode` ignores trailing bytes; re-encoding and comparing
        // rejects them.
        if (keccak256(abi.encode(rbac)) != keccak256(value)) {
            revert NonCanonicalRbac(authority, name);
        }
        return rbac;
    }
}
