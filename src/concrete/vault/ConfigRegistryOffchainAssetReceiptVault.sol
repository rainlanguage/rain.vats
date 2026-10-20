// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV2,
    ReceiptVaultConfigV2,
    ICLONEABLE_V2_SUCCESS
} from "./OffchainAssetReceiptVault.sol";
import {IAuthorizeV1} from "../../interface/IAuthorizeV1.sol";
import {ICloneableV2} from "rain-factory-0.1.31-pr271/src/interface/ICloneableV2.sol";
import {IBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/IBeacon.sol";
import {BeaconProxy} from "@openzeppelin-contracts-5.7.0/proxy/beacon/BeaconProxy.sol";
import {LibConfigRegistry} from "rain-deploy-0.1.19-pr322/src/lib/LibConfigRegistry.sol";
import {InitializeReceiptFailed} from "../../error/ErrDeployer.sol";

/// @dev How long an RBAC binding must have stood in the `ConfigRegistry`
/// before `initialize` accepts it. The window in which a rebind is public
/// before any token snapshots it.
uint256 constant CONFIG_REGISTRY_RBAC_MIN_AGE = 48 hours;

/// Thrown when constructing with a zero receipt beacon.
error ZeroReceiptBeacon();

/// Thrown when the RBAC binding is not the canonical ABI encoding of
/// `OffchainAssetReceiptVaultRbacV1`.
/// @param authority The authority the binding was resolved under.
/// @param name The name the binding was resolved from.
error NonCanonicalRbac(address authority, bytes32 name);

/// Thrown when the config selects an authorizer the RBAC binding does not
/// list.
/// @param authorizerIndex The index the config selected.
/// @param authorizers The number of authorizers the binding lists.
error AuthorizerIndexOutOfRange(uint256 authorizerIndex, uint256 authorizers);

/// The value a `ConfigRegistry` authority binds an RBAC name to, ABI encoded.
/// @param owner The owner of every vault initialized from the binding.
/// @param authorizers The authorizers a vault may select from by index.
struct OffchainAssetReceiptVaultRbacV1 {
    address owner;
    IAuthorizeV1[] authorizers;
}

/// All data `ConfigRegistryOffchainAssetReceiptVault.initialize` takes, ABI
/// encoded. Deployed through an open-salt factory, all of it is part of the
/// vault's address.
/// @param name As per ERC20.
/// @param symbol As per ERC20.
/// @param authority The `ConfigRegistry` authority whose binding of `rbacName`
/// is trusted for the vault's roles.
/// @param rbacName The name the RBAC binding is resolved from.
/// @param authorizerIndex Which of the binding's authorizers the vault uses.
/// @param metadata Opaque to this contract. Committed to by the address and
/// emitted, never decoded.
struct ConfigRegistryOffchainAssetReceiptVaultConfigV1 {
    string name;
    string symbol;
    address authority;
    bytes32 rbacName;
    uint256 authorizerIndex;
    bytes metadata;
}

/// @title ConfigRegistryOffchainAssetReceiptVault
/// @notice An `OffchainAssetReceiptVault` whose `initialize` takes no roles
/// from its caller. It resolves them from the `ConfigRegistry` binding the
/// config names, and deploys its own receipt, so it can be initialized by
/// anyone through an open-salt beacon-proxy factory, and the same config is
/// the same vault, at the same address, on every chain.
///
/// The authority comes from the config rather than from this implementation.
/// An open-salt factory hashes the config into the address, so whoever pins
/// the address pins the authority, and a config with a different authority is
/// a different address nothing pins. The implementation stays the same for
/// every authority.
///
/// The authority is trusted for the initial owner and authorizer. A binding is
/// read once, here, and only if it has stood for longer than
/// `CONFIG_REGISTRY_RBAC_MIN_AGE`, so a rebind is public for that long before
/// any vault snapshots it. After initialization the vault never reads the
/// registry again.
contract ConfigRegistryOffchainAssetReceiptVault is OffchainAssetReceiptVault {
    /// Contract has initialized from the registry.
    /// @param sender The msg sender initializing the contract.
    /// @param config The config it was initialized with.
    /// @param owner The owner the binding resolved to.
    /// @param authorizer The authorizer the config selected from the binding.
    event ConfigRegistryOffchainAssetReceiptVaultInitializedV1(
        address sender, ConfigRegistryOffchainAssetReceiptVaultConfigV1 config, address owner, IAuthorizeV1 authorizer
    );

    /// The beacon every vault's receipt is a proxy of.
    IBeacon public immutable iReceiptBeacon;

    /// @param receiptBeacon The beacon every vault's receipt is a proxy of.
    constructor(IBeacon receiptBeacon) {
        if (address(receiptBeacon) == address(0)) {
            revert ZeroReceiptBeacon();
        }
        iReceiptBeacon = receiptBeacon;
    }

    /// @param data `ConfigRegistryOffchainAssetReceiptVaultConfigV1`, ABI
    /// encoded.
    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) public virtual override initializer returns (bytes32) {
        ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory config =
            abi.decode(data, (ConfigRegistryOffchainAssetReceiptVaultConfigV1));

        bytes memory value =
            LibConfigRegistry.resolveSafe(config.authority, config.rbacName, CONFIG_REGISTRY_RBAC_MIN_AGE);
        OffchainAssetReceiptVaultRbacV1 memory rbac = abi.decode(value, (OffchainAssetReceiptVaultRbacV1));
        // `abi.decode` ignores trailing bytes and non-canonical offsets.
        if (keccak256(abi.encode(rbac)) != keccak256(value)) {
            revert NonCanonicalRbac(config.authority, config.rbacName);
        }
        if (config.authorizerIndex >= rbac.authorizers.length) {
            revert AuthorizerIndexOutOfRange(config.authorizerIndex, rbac.authorizers.length);
        }
        IAuthorizeV1 authorizer = rbac.authorizers[config.authorizerIndex];

        // The receipt's address is `CREATE` from this proxy at its first
        // nonce, so it is as deterministic as this proxy's address.
        ICloneableV2 receipt = ICloneableV2(address(new BeaconProxy(address(iReceiptBeacon), "")));
        if (receipt.initialize(abi.encode(address(this))) != ICLONEABLE_V2_SUCCESS) {
            revert InitializeReceiptFailed();
        }

        _initialize(
            OffchainAssetReceiptVaultConfigV2({
                initialAdmin: rbac.owner,
                receiptVaultConfig: ReceiptVaultConfigV2({
                    asset: address(0), name: config.name, symbol: config.symbol, receipt: address(receipt)
                })
            })
        );
        _setAuthorizer(authorizer);

        emit ConfigRegistryOffchainAssetReceiptVaultInitializedV1(_msgSender(), config, rbac.owner, authorizer);

        return ICLONEABLE_V2_SUCCESS;
    }
}
