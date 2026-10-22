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
import {
    IConfigRegistryOffchainAssetReceiptVaultV1,
    ConfigRegistryOffchainAssetReceiptVaultConfigV1,
    CONFIG_REGISTRY_OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V1_TAG
} from "../../interface/IConfigRegistryOffchainAssetReceiptVaultV1.sol";
import {ICloneableV2} from "rain-factory-0.2.4/src/interface/ICloneableV2.sol";
import {IBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/IBeacon.sol";
import {ICloneableFactoryV5} from "rain-factory-0.2.4/src/interface/ICloneableFactoryV5.sol";
import {LibCloneFactoryDeploy} from "rain-factory-deploy-0.2.1/src/lib/LibCloneFactoryDeploy.sol";
import {ERC1967Utils} from "@openzeppelin-contracts-5.7.0/proxy/ERC1967/ERC1967Utils.sol";
import {Ownable} from "@openzeppelin-contracts-5.7.0/access/Ownable.sol";
import {IERC1155MetadataURI} from "@openzeppelin-contracts-5.7.0/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {LibConfigRegistry} from "rain-deploy-0.1.21/src/lib/LibConfigRegistry.sol";
import {
    LibOffchainAssetReceiptVaultRbac,
    OffchainAssetReceiptVaultRbacV1
} from "../../lib/LibOffchainAssetReceiptVaultRbac.sol";

/// @dev How long an RBAC binding must have stood in the `ConfigRegistry`
/// before `initialize` accepts it. The window in which a rebind is public
/// before any token snapshots it.
uint256 constant CONFIG_REGISTRY_RBAC_MIN_AGE = 1 hours;

/// Thrown when the RBAC binding names no receipt beacon.
error ZeroReceiptBeacon();

/// Thrown when the config selects an authorizer the RBAC binding does not
/// list.
/// @param authorizerIndex The index the config selected.
/// @param authorizersLength The number of authorizers the binding lists.
error AuthorizerIndexOutOfRange(uint256 authorizerIndex, uint256 authorizersLength);

/// Thrown when `initialize` data is not the canonical ABI encoding of the
/// version tag and `ConfigRegistryOffchainAssetReceiptVaultConfigV1`.
error NonCanonicalConfig();

/// Thrown when `initialize` data does not lead with
/// `CONFIG_REGISTRY_OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V1_TAG`.
/// @param version The leading word, or zero for data shorter than a word.
error UnknownConfigVersion(bytes32 version);

/// Thrown when initializing outside a beacon proxy.
error VaultNotBeaconProxy();

/// Thrown when the pinned clone factory's code is not the pinned code.
/// @param actual The code hash found at the pinned address.
error UnexpectedCloneFactoryCodeHash(bytes32 actual);

/// Thrown when the receipt beacon's owner is not the vault beacon's owner.
/// @param vaultBeaconOwner The owner of the beacon this vault proxies.
/// @param receiptBeaconOwner The owner of the receipt beacon.
error ReceiptBeaconOwnerMismatch(address vaultBeaconOwner, address receiptBeaconOwner);

/// Thrown when the new receipt's `uri` reverts.
/// @param receipt The new receipt.
error ReceiptMetadataReverts(address receipt);

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
contract ConfigRegistryOffchainAssetReceiptVault is
    OffchainAssetReceiptVault,
    IConfigRegistryOffchainAssetReceiptVaultV1
{
    /// The receipt beacon is the RBAC binding's `receiptBeacon`. Its owner can
    /// upgrade every receipt made from it, so it is trusted for the receipt as
    /// the vault beacon's owner is for the vault, and the two MUST be the same
    /// principal. Its implementation MUST override
    /// the asset-symbol metadata, as the generic `Receipt` metadata reverts for
    /// a vault whose asset is `address(0)` (see `_initialize`). The
    /// implementation cannot see the vault beacon, so `initialize` checks both:
    /// the two beacons' `owner` must be equal and the new receipt's `uri` must
    /// not revert. Neither holds after initialization if either beacon changes
    /// owner or the receipt beacon is upgraded; nothing on chain prevents that.
    /// Both beacons MUST expose `Ownable.owner`, or `initialize` reverts
    /// without data. `owner` is reported by each beacon itself, so the check
    /// catches a misconfigured pairing, not a beacon built to pass it; the
    /// vault beacon is part of the vault's address, so only the pinned beacon
    /// matters.
    ///
    /// @param data `abi.encode(CONFIG_REGISTRY_OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V1_TAG, config)`.
    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) public virtual override initializer returns (bytes32) {
        if (data.length < 0x20) {
            revert UnknownConfigVersion(bytes32(0));
        }
        bytes32 version = abi.decode(data, (bytes32));
        if (version != CONFIG_REGISTRY_OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V1_TAG) {
            revert UnknownConfigVersion(version);
        }
        (, ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory config) =
            abi.decode(data, (bytes32, ConfigRegistryOffchainAssetReceiptVaultConfigV1));
        // `abi.decode` ignores trailing bytes and accepts non-canonical
        // offsets, and the factory hashes the raw `data` into the address, so
        // without this one config has many addresses.
        if (keccak256(abi.encode(version, config)) != keccak256(data)) {
            revert NonCanonicalConfig();
        }

        OffchainAssetReceiptVaultRbacV1 memory rbac = LibOffchainAssetReceiptVaultRbac.decodeCanonical(
            config.authority,
            config.rbacName,
            LibConfigRegistry.resolveSafe(config.authority, config.rbacName, CONFIG_REGISTRY_RBAC_MIN_AGE)
        );
        if (address(rbac.receiptBeacon) == address(0)) {
            revert ZeroReceiptBeacon();
        }
        address vaultBeacon = ERC1967Utils.getBeacon();
        if (vaultBeacon == address(0)) {
            revert VaultNotBeaconProxy();
        }
        address vaultBeaconOwner = Ownable(vaultBeacon).owner();
        address receiptBeaconOwner = Ownable(address(rbac.receiptBeacon)).owner();
        if (vaultBeaconOwner != receiptBeaconOwner) {
            revert ReceiptBeaconOwnerMismatch(vaultBeaconOwner, receiptBeaconOwner);
        }

        if (config.authorizerIndex >= rbac.authorizers.length) {
            revert AuthorizerIndexOutOfRange(config.authorizerIndex, rbac.authorizers.length);
        }
        IAuthorizeV1 selectedAuthorizer = rbac.authorizers[config.authorizerIndex];

        // The receipt is a beacon proxy from the pinned factory, which
        // initializes it with this vault as manager and checks the answer. Its
        // address commits to this vault's, so it is as deterministic.
        if (
            LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS.codehash
                != LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_CODEHASH
        ) {
            revert UnexpectedCloneFactoryCodeHash(LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS.codehash);
        }
        address newReceipt = ICloneableFactoryV5(LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS)
            .beaconProxyDeterministicOpenSalt(address(rbac.receiptBeacon), abi.encode(address(this)), bytes32(0));

        _initialize(
            OffchainAssetReceiptVaultConfigV2({
                initialAdmin: rbac.owner,
                receiptVaultConfig: ReceiptVaultConfigV2({
                    asset: address(0), name: config.name, symbol: config.symbol, receipt: newReceipt
                })
            })
        );
        _setAuthorizer(selectedAuthorizer);

        // `uri` reads this vault's share symbol and decimals, so it runs after
        // `_initialize`.
        // Only whether `uri` reverts matters, not what it returns.
        //slither-disable-next-line unused-return
        try IERC1155MetadataURI(newReceipt).uri(0) returns (string memory) {}
        catch {
            revert ReceiptMetadataReverts(newReceipt);
        }

        emit ConfigRegistryOffchainAssetReceiptVaultInitializedV1(_msgSender(), config, rbac.owner, selectedAuthorizer);

        return ICLONEABLE_V2_SUCCESS;
    }
}
