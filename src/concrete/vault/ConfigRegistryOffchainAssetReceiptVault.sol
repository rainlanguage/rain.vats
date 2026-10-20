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
import {
    LibOffchainAssetReceiptVaultRbac,
    OffchainAssetReceiptVaultRbacV1
} from "../../lib/LibOffchainAssetReceiptVaultRbac.sol";

/// @dev How long an RBAC binding must have stood in the `ConfigRegistry`
/// before `initialize` accepts it. The window in which a rebind is public
/// before any token snapshots it.
uint256 constant CONFIG_REGISTRY_RBAC_MIN_AGE = 48 hours;

/// Thrown when constructing with a zero receipt beacon.
error ZeroReceiptBeacon();

/// Thrown when the config selects an authorizer the RBAC binding does not
/// list.
/// @param authorizerIndex The index the config selected.
/// @param authorizersLength The number of authorizers the binding lists.
error AuthorizerIndexOutOfRange(uint256 authorizerIndex, uint256 authorizersLength);

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
/// anyone through an open-salt beacon-proxy factory. The vault's address is
/// a function of the factory, the beacon, the salt and the config, so the
/// same four give the same address on every chain where the factory and
/// beacon share their addresses. The chain must support Cancun, as
/// `BeaconProxy` uses `MCOPY`. The owner and authorizer are resolved on each
/// chain at that chain's first deploy, so the same address on two chains has
/// the same roles only if the binding was the same on both when each was
/// deployed.
///
/// The authority comes from the config rather than from this implementation.
/// An open-salt factory hashes the config into the address, so whoever pins
/// the address pins the authority and the RBAC name, and a config with a
/// different authority is a different address nothing pins. The address
/// commits to the authority and name, not to what they resolve to: a pinned
/// address not yet deployed takes whatever binding has stood for
/// `CONFIG_REGISTRY_RBAC_MIN_AGE` when anyone first deploys it. The
/// implementation stays the same for every authority.
///
/// Anyone can deploy a look-alike vault under the same authority and RBAC
/// name with another token name, symbol, salt or metadata, and it resolves
/// the same owner and authorizer. The owner, the authorizer and the fields of
/// the initialization event are therefore not evidence a vault is genuine.
/// Only the pinned address is.
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

    /// The beacon every vault's receipt is a proxy of. Its owner can upgrade
    /// every receipt, so it is trusted for the receipt as the vault beacon's
    /// owner is for the vault, and the two MUST be the same principal.
    IBeacon public immutable iReceiptBeacon;

    /// @param receiptBeacon The beacon every vault's receipt is a proxy of. Its
    /// owner MUST be the vault beacon's owner. Its implementation MUST override
    /// the asset-symbol metadata, as the generic `Receipt` metadata reverts for
    /// a vault whose asset is `address(0)` (see `_initialize`).
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

        OffchainAssetReceiptVaultRbacV1 memory rbac = LibOffchainAssetReceiptVaultRbac.decodeCanonical(
            config.authority,
            config.rbacName,
            LibConfigRegistry.resolveSafe(config.authority, config.rbacName, CONFIG_REGISTRY_RBAC_MIN_AGE)
        );
        if (config.authorizerIndex >= rbac.authorizers.length) {
            revert AuthorizerIndexOutOfRange(config.authorizerIndex, rbac.authorizers.length);
        }
        IAuthorizeV1 selectedAuthorizer = rbac.authorizers[config.authorizerIndex];

        // The receipt's address is `CREATE` from this proxy at its first
        // nonce, so it is as deterministic as this proxy's address.
        ICloneableV2 newReceipt = ICloneableV2(address(new BeaconProxy(address(iReceiptBeacon), "")));
        if (newReceipt.initialize(abi.encode(address(this))) != ICLONEABLE_V2_SUCCESS) {
            revert InitializeReceiptFailed();
        }

        _initialize(
            OffchainAssetReceiptVaultConfigV2({
                initialAdmin: rbac.owner,
                receiptVaultConfig: ReceiptVaultConfigV2({
                    asset: address(0), name: config.name, symbol: config.symbol, receipt: address(newReceipt)
                })
            })
        );
        _setAuthorizer(selectedAuthorizer);

        emit ConfigRegistryOffchainAssetReceiptVaultInitializedV1(_msgSender(), config, rbac.owner, selectedAuthorizer);

        return ICLONEABLE_V2_SUCCESS;
    }
}
