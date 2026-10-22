// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.0;

import {IAuthorizeV1} from "./IAuthorizeV1.sol";

/// @dev The version tag leading `OffchainAssetReceiptVault`
/// `initialize` data: `abi.encode(TAG, config)`. An implementation rejects a
/// tag it does not know, so data written for a later implementation reverts on
/// an earlier one instead of being misread.
bytes32 constant CONFIG_REGISTRY_OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V1_TAG =
    keccak256("ConfigRegistryOffchainAssetReceiptVaultConfigV1");

/// The config `OffchainAssetReceiptVault.initialize` takes after
/// its version tag. Deployed through an open-salt factory, the tag and config
/// are all part of the vault's address.
/// @param name As per ERC20.
/// @param symbol As per ERC20.
/// @param authority The `ConfigRegistry` authority whose binding of `rbacName`
/// is trusted for the vault's roles.
/// @param rbacName The name the RBAC binding is resolved from.
/// @param authorizerIndex Which of the binding's authorizers the vault uses.
/// @param metadata Opaque to the vault. Committed to by the address and
/// emitted, never decoded.
struct ConfigRegistryOffchainAssetReceiptVaultConfigV1 {
    string name;
    string symbol;
    address authority;
    bytes32 rbacName;
    uint256 authorizerIndex;
    bytes metadata;
}

/// @title IConfigRegistryOffchainAssetReceiptVaultV1
/// @notice The event and config of `OffchainAssetReceiptVault`,
/// for decoders that do not need the concrete vault.
interface IConfigRegistryOffchainAssetReceiptVaultV1 {
    /// Contract has initialized from the registry.
    /// @param sender The msg sender initializing the contract.
    /// @param config The config it was initialized with.
    /// @param owner The owner the binding resolved to.
    /// @param authorizer The authorizer the config selected from the binding.
    event ConfigRegistryOffchainAssetReceiptVaultInitializedV1(
        address sender, ConfigRegistryOffchainAssetReceiptVaultConfigV1 config, address owner, IAuthorizeV1 authorizer
    );
}
