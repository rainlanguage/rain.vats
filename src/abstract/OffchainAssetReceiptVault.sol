// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ReceiptVaultConfigV2, ReceiptVault, ShareAction, InvalidId, ICLONEABLE_V2_SUCCESS} from "./ReceiptVault.sol";
import {Math} from "@openzeppelin-contracts-5.7.0/utils/math/Math.sol";
import {IAuthorizeV1, Unauthorized} from "../interface/IAuthorizeV1.sol";
import {IAuthorizableV1} from "../interface/IAuthorizableV1.sol";
import {ICertifiableV1} from "../interface/ICertifiableV1.sol";
import {IERC165} from "@openzeppelin-contracts-5.7.0/utils/introspection/IERC165.sol";

import {ZeroInitialAdmin} from "../concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {OwnerFreezable} from "./OwnerFreezable.sol";
import {
    IOffchainAssetReceiptVaultV1,
    OffchainAssetReceiptVaultConfigV3,
    OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V3_TAG
} from "../interface/IOffchainAssetReceiptVaultV1.sol";
import {ICloneableV2} from "rain-factory-0.2.5/src/interface/ICloneableV2.sol";
import {ICloneableFactoryV6} from "rain-factory-0.2.5/src/interface/ICloneableFactoryV6.sol";
import {LibICloneableFactoryV6} from "rain-factory-0.2.5/src/lib/LibICloneableFactoryV6.sol";
import {LibCloneFactoryDeploy} from "rain-factory-deploy-0.2.4/src/lib/LibCloneFactoryDeploy.sol";
import {ERC1967Utils} from "@openzeppelin-contracts-5.7.0/proxy/ERC1967/ERC1967Utils.sol";
import {Ownable} from "@openzeppelin-contracts-5.7.0/access/Ownable.sol";
import {IERC1155MetadataURI} from "@openzeppelin-contracts-5.7.0/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {LibConfigRegistry} from "rain-deploy-0.1.26/src/lib/LibConfigRegistry.sol";
import {LibConfigRegistryDeploy} from "rain-deploy-0.1.26/src/lib/LibConfigRegistryDeploy.sol";
import {
    LibOffchainAssetReceiptVaultRbac,
    OffchainAssetReceiptVaultRbacV1,
    OFFCHAIN_ASSET_RECEIPT_VAULT_RBAC_V1_VALUE_TYPE_HASH
} from "../lib/LibOffchainAssetReceiptVaultRbac.sol";

/// Thrown when the asset is NOT address zero.
error NonZeroAsset();

/// Thrown when a 0 certification time is attempted.
error ZeroCertifyUntil();

/// Thrown when a 0 confiscation amount is attempted.
error ZeroConfiscateAmount();

/// Thrown when the authorizer is incompatible according to `IERC165` when set.
error IncompatibleAuthorizer();

/// Thrown when `receiptBeaconName` resolves to address zero.
error ZeroReceiptBeacon();

/// Thrown when `initialize` data is not the canonical ABI encoding of the
/// version tag and `OffchainAssetReceiptVaultConfigV3`.
error NonCanonicalConfig();

/// Thrown when `initialize` data does not lead with
/// `OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V3_TAG`.
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

/// @dev String ID for the OffchainAssetReceiptVault storage location v1.
string constant OFFCHAIN_ASSET_RECEIPT_VAULT_STORAGE_ID = "rain.storage.offchain-asset-receipt-vault.1";

/// @dev "rain.storage.offchain-asset-receipt-vault.1"
bytes32 constant OFFCHAIN_ASSET_RECEIPT_VAULT_STORAGE_LOCATION =
    0xba9f160a0257aef2aa878e698d5363429ea67cc3c427f23f7cb9c3069b67bd00;

/// All data required to construct `OffchainAssetReceiptVault`.
/// @param initialAdmin The initial admin has ALL ROLES. It is up to the admin to
/// appropriately delegate and renounce roles or to be a smart contract with
/// formal governance processes. In general a single EOA holding all admin roles
/// is completely insecure and counterproductive as it allows a single address
/// to both mint and audit assets (and everything else).
/// @param receiptVaultConfig Forwarded to ReceiptVault.
struct OffchainAssetReceiptVaultConfigV2 {
    address initialAdmin;
    ReceiptVaultConfigV2 receiptVaultConfig;
}

/// Represents a change in the certification state of the system.
/// Provided to the authorization contract in case it needs to make decisions
/// based on the specifics of the change.
/// @param oldCertifiedUntil The previous certification time.
/// @param newCertifiedUntil The new certification time. May be the same as the
/// old certification time according to the logic of `certify`.
/// @param userCertifyUntil The certification time that the certifier attempted
/// to set.
/// @param forceUntil Whether the certifier forced the certification time.
/// @param data Arbitrary data justifying the certification as provided by the
/// certifier.
struct CertifyStateChange {
    uint256 oldCertifiedUntil;
    uint256 newCertifiedUntil;
    uint256 userCertifyUntil;
    bool forceUntil;
    bytes data;
}

/// Represents the confiscation of some or all of a receipt.
/// Provided to the authorization contract in case it needs to make decisions
/// based on the specifics of the confiscation.
/// @param confiscatee The address that the receipt is being confiscated from.
/// @param id The ID of the receipt being confiscated.
/// @param targetAmount The amount of the receipt that the confiscator attempted
/// to confiscate.
/// @param actualAmount The amount of the receipt that was actually confiscated.
/// @param data Arbitrary data justifying the confiscation as provided by the
/// confiscator.
struct ConfiscateReceiptStateChange {
    address confiscatee;
    uint256 id;
    uint256 targetAmount;
    uint256 actualAmount;
    bytes data;
}

/// Represents the confiscation of some or all of a user's shares.
/// Provided to the authorization contract in case it needs to make decisions
/// based on the specifics of the confiscation.
/// @param confiscatee The address that the shares are being confiscated from.
/// @param targetAmount The amount of shares that the confiscator attempted to
/// confiscate.
/// @param actualAmount The amount of shares that were actually confiscated.
/// @param data Arbitrary data justifying the confiscation as provided by the
/// confiscator.
struct ConfiscateSharesStateChange {
    address confiscatee;
    uint256 targetAmount;
    uint256 actualAmount;
    bytes data;
}

/// Represents a change in the state of the system due to a transfer of shares.
/// Provided to the authorization contract in case it needs to make decisions
/// based on the specifics of the transfer.
/// @param from The address that the shares are being transferred from.
/// @param to The address that the shares are being transferred to.
/// @param amount The amount of shares that are being transferred.
/// @param isCertificationExpired Whether the system is currently in a state of
/// certification lapse.
struct TransferSharesStateChange {
    address from;
    address to;
    uint256 amount;
    bool isCertificationExpired;
}

/// Represents a change in the state of the system due to a transfer of receipts.
/// Provided to the authorization contract in case it needs to make decisions
/// based on the specifics of the transfer.
/// @param from The address that the receipts are being transferred from.
/// @param to The address that the receipts are being transferred to.
/// @param ids The IDs of the receipts that are being transferred.
/// @param amounts The amounts of the receipts that are being transferred.
/// @param isCertificationExpired Whether the system is currently in a state of
/// certification lapse.
struct TransferReceiptStateChange {
    address from;
    address to;
    uint256[] ids;
    uint256[] amounts;
    bool isCertificationExpired;
}

/// Represents a change in the state of the system due to a deposit of assets.
/// Provided to the authorization contract in case it needs to make decisions
/// based on the specifics of the deposit.
/// @param owner The address that owns the assets being deposited.
/// @param receiver The address that shares and receipts are being minted to.
/// @param id The ID of the receipt that the assets are being deposited under.
/// @param assetsDeposited The amount of assets that are being deposited.
/// @param sharesMinted The amount of shares that are being minted.
/// @param data Arbitrary data justifying the deposit as provided by the
struct DepositStateChange {
    address owner;
    address receiver;
    uint256 id;
    uint256 assetsDeposited;
    uint256 sharesMinted;
    bytes data;
}

/// Represents a change in the state of the system due to a withdrawal of assets.
/// Provided to the authorization contract in case it needs to make decisions
/// based on the specifics of the withdrawal.
/// @param owner The address that owns the shares and receipts being burned.
/// @param receiver The address that the assets are being withdrawn to.
/// @param id The ID of the receipt that the assets are being withdrawn from.
/// @param assetsWithdrawn The amount of assets that are being withdrawn.
/// @param sharesBurned The amount of shares that are being burned.
/// @param data Arbitrary data justifying the withdrawal as provided by the
struct WithdrawStateChange {
    address owner;
    address receiver;
    uint256 id;
    uint256 assetsWithdrawn;
    uint256 sharesBurned;
    bytes data;
}

/// @dev Permission for certification.
bytes32 constant CERTIFY = keccak256("CERTIFY");

/// @dev Permission for confiscating shares.
bytes32 constant CONFISCATE_SHARES = keccak256("CONFISCATE_SHARES");

/// @dev Permission for confiscating receipts.
bytes32 constant CONFISCATE_RECEIPT = keccak256("CONFISCATE_RECEIPT");

/// @dev Permission for transferring tokens.
bytes32 constant TRANSFER_SHARES = keccak256("TRANSFER_SHARES");

/// @dev Permission for transferring receipts
bytes32 constant TRANSFER_RECEIPT = keccak256("TRANSFER_RECEIPT");

/// @dev Permission for depositing tokens.
bytes32 constant DEPOSIT = keccak256("DEPOSIT");

/// @dev Permission for withdrawing tokens.
bytes32 constant WITHDRAW = keccak256("WITHDRAW");

/// @title OffchainAssetReceiptVault
/// @notice Enables issuers of offchain assets to create a token that they can
/// arbitrage offchain assets against onchain assets. This allows them to
/// maintain a peg between offchain and onchain markets.
///
/// At a high level this works because the issuer can always profitably trade
/// the peg against offchain markets in both directions. The exact tokenomics
/// are somewhat flexible and intentionally left open to the issuer to design.
/// The main requirement is that bringing the peg up or down is profitable for
/// the issuer, all the way down to buying and burning 100% of the supply.
///
/// Price is higher onchain: Issuer can buy/produce assets offchain and mint
/// tokens then sell the tokens for more than the assets would sell for offchain
/// thus making a profit. The sale of the tokens brings the onchain price down.
///
/// Price is higher offchain: Issuer can sell assets offchain and
/// buyback+burn tokens onchain for less than the offchain sale, thus making a
/// profit. The token purchase brings the onchain price up.
///
/// The issuer doesn't necessarily have to mint and burn tokens immediately, as
/// the offchain assets may not trade/yield so quickly, but delays have
/// implications for the peg fidelity onchain.
///
/// In contrast to pure algorithmic tokens and sentiment based stablecoins, a
/// competent issuer must profit sustainably to maintain the peg no matter how
/// badly or frequently the peg breaks. Ideally the issuer profits more when the
/// peg is broken more.
///
/// This contract does not attempt to solve for liquidity and trustworthiness,
/// it only seeks to provide baseline functionality that a competent issuer
/// will need to tackle the problem. The implementation provides:
///
/// - `ReceiptVault` base that allows transparent onchain/offchain audit history
/// - Certifier role that allows for audits of offchain assets that can fail
/// - KYC/membership lists that can restrict who can hold/transfer assets as
///   any Rain `ITierV2` interface
/// - Ability to comply with sanctions/regulators by confiscating assets
/// - `ERC20` shares in the vault that can be traded minted/burned to track a peg
/// - `ERC4626` inspired vault interface (inherited from `ReceiptVault`)
/// - Fine grained standard Open Zeppelin access control for all system roles
///
/// Its `initialize` takes no roles
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
/// commits to the authority and names, not to what they resolve to: a pinned
/// address not yet deployed takes whatever is bound when anyone first deploys
/// it. The implementation stays the same for every authority.
///
/// Anyone can deploy a look-alike vault under the same authority and RBAC
/// name with another token name, symbol, salt or metadata, and it resolves
/// the same owner and authorizer. The owner, the authorizer and the fields of
/// the initialization event are therefore not evidence a vault is genuine.
/// Only the pinned address is.
///
/// The authority is trusted for the initial owner, the authorizer and the
/// receipt beacon. Its bindings are read once, here. After initialization the
/// vault never reads the registry again.

abstract contract OffchainAssetReceiptVault is
    IAuthorizableV1,
    ICertifiableV1,
    IAuthorizeV1,
    IOffchainAssetReceiptVaultV1,
    ReceiptVault,
    OwnerFreezable
{
    using Math for uint256;

    /// Contract has initialized.
    /// @param sender The msg sender constructing the contract.
    /// @param config All initialization config.
    event OffchainAssetReceiptVaultInitializedV2(address sender, OffchainAssetReceiptVaultConfigV2 config);

    /// A new certification time has been set.
    /// @param sender The certifier setting the new time.
    /// @param certifyUntil The time the system is newly certified until.
    /// Normally this will be a future time but certifiers MAY set it to a time
    /// in the past which will immediately freeze all transfers.
    /// @param forceUntil Whether the certifier forced the certification time.
    /// @param data The certifier MAY provide additional supporting data such
    /// as an auditor's report/comments etc.
    event Certify(address sender, uint256 certifyUntil, bool forceUntil, bytes data);

    /// Shares have been confiscated from a user who is not currently meeting
    /// the ERC20 tier contract minimum requirements.
    /// @param sender The confiscator who is confiscating the shares.
    /// @param confiscatee The user who had their shares confiscated.
    /// @param confiscated The amount of shares that were confiscated.
    /// @param justification The contextual data justifying the confiscation.
    event ConfiscateShares(
        address sender, address confiscatee, uint256 targetAmount, uint256 confiscated, bytes justification
    );

    /// A receipt has been confiscated from a user who is not currently meeting
    /// the ERC1155 tier contract minimum requirements.
    /// @param sender The confiscator who is confiscating the receipt.
    /// @param confiscatee The user who had their receipt confiscated.
    /// @param id The receipt ID that was confiscated.
    /// @param confiscated The amount of the receipt that was confiscated.
    /// @param justification The contextual data justifying the confiscation.
    event ConfiscateReceipt(
        address sender, address confiscatee, uint256 id, uint256 targetAmount, uint256 confiscated, bytes justification
    );

    /// @param authorizer The authorizer contract that is used to authorize
    /// actions in the vault.
    /// @param highwaterId The largest issued id. The next id issued will be
    /// larger than this.
    /// @param certifiedUntil The system is certified until this timestamp. If
    /// this is in the past then general transfers of shares and receipts will
    /// fail until the system can be certified to a future time.
    /// @custom:storage-location erc7201:rain.storage.offchain-asset-receipt-vault.1
    struct OffchainAssetReceiptVault7201Storage {
        IAuthorizeV1 authorizer;
        uint256 highwaterId;
        uint256 certifiedUntil;
    }

    /// @dev Accessor for OffchainAssetReceiptVault storage.
    function getStorageOffchainAssetReceiptVault()
        private
        pure
        returns (OffchainAssetReceiptVault7201Storage storage s)
    {
        assembly ("memory-safe") {
            s.slot := OFFCHAIN_ASSET_RECEIPT_VAULT_STORAGE_LOCATION
        }
    }

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
    /// @param data `abi.encode(OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V3_TAG, config)`.
    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) public virtual override initializer returns (bytes32) {
        if (data.length < 0x20) {
            revert UnknownConfigVersion(bytes32(0));
        }
        bytes32 version = abi.decode(data, (bytes32));
        if (version != OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V3_TAG) {
            revert UnknownConfigVersion(version);
        }
        (, OffchainAssetReceiptVaultConfigV3 memory config) =
            abi.decode(data, (bytes32, OffchainAssetReceiptVaultConfigV3));
        // `abi.decode` ignores trailing bytes and accepts non-canonical
        // offsets, and the factory hashes the raw `data` into the address, so
        // without this one config has many addresses.
        if (keccak256(abi.encode(version, config)) != keccak256(data)) {
            revert NonCanonicalConfig();
        }

        // When the binding was written does not matter here.
        //slither-disable-next-line unused-return
        (bytes memory rbacValue,) = LibConfigRegistry.resolve(
            config.authority, config.rbacName, OFFCHAIN_ASSET_RECEIPT_VAULT_RBAC_V1_VALUE_TYPE_HASH
        );
        OffchainAssetReceiptVaultRbacV1 memory rbac =
            LibOffchainAssetReceiptVaultRbac.decodeCanonical(config.authority, config.rbacName, rbacValue);
        address receiptBeacon = LibICloneableFactoryV6.resolveBeacon(
            LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_ADDRESS, config.authority, config.receiptBeaconName
        );
        if (receiptBeacon == address(0)) {
            revert ZeroReceiptBeacon();
        }
        address vaultBeacon = ERC1967Utils.getBeacon();
        if (vaultBeacon == address(0)) {
            revert VaultNotBeaconProxy();
        }
        address vaultBeaconOwner = Ownable(vaultBeacon).owner();
        address receiptBeaconOwner = Ownable(receiptBeacon).owner();
        if (vaultBeaconOwner != receiptBeaconOwner) {
            revert ReceiptBeaconOwnerMismatch(vaultBeaconOwner, receiptBeaconOwner);
        }

        IAuthorizeV1 selectedAuthorizer = rbac.authorizer;

        // The receipt is a registry beacon proxy from the pinned factory, which
        // initializes it with this vault as manager and checks the answer. Its
        // address commits to this vault's and to the binding, not the beacon,
        // so it is the same on every chain.
        if (
            LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS.codehash
                != LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_CODEHASH
        ) {
            revert UnexpectedCloneFactoryCodeHash(LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS.codehash);
        }
        address newReceipt = receiptFor(config.authority, config.receiptBeaconName);

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

        emit OffchainAssetReceiptVaultInitializedV3(_msgSender(), config, rbac.owner, selectedAuthorizer);

        return ICLONEABLE_V2_SUCCESS;
    }

    /// This vault's receipt from the pinned factory, deployed or, if anyone
    /// made it first, adopted. Anyone can, since the factory is open and the
    /// address is known before the vault exists. The address commits to the
    /// registry, authority, name and `abi.encode(this)`, so code there is this
    /// vault's receipt.
    /// @param authority The authority binding the receipt beacon.
    /// @param receiptBeaconName The name the receipt beacon is bound to.
    /// @return The receipt.
    function receiptFor(address authority, bytes32 receiptBeaconName) internal returns (address) {
        ICloneableFactoryV6 factory = ICloneableFactoryV6(LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS);
        bytes memory receiptData = abi.encode(address(this));
        address deployed = factory.predictRegistryBeaconProxyAddress(
            LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_ADDRESS,
            authority,
            receiptBeaconName,
            receiptData,
            bytes32(0)
        );
        if (deployed.code.length == 0) {
            deployed = factory.registryBeaconProxy(
                LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_ADDRESS,
                authority,
                receiptBeaconName,
                receiptData,
                bytes32(0)
            );
        }
        return deployed;
    }

    /// `initialize` without the `initializer` modifier or the decode, so an
    /// inheriting contract that builds the config itself can be the
    /// initializer. Makes `initialAdmin` the owner and the vault its own
    /// authorizer.
    /// @param config All config required to initialize.
    function _initialize(OffchainAssetReceiptVaultConfigV2 memory config) internal virtual onlyInitializing {
        __OwnerFreezable_init();

        __ReceiptVault_init(config.receiptVaultConfig);

        // There is no asset, the asset is offchain. Because `asset()` is
        // therefore `address(0)`, the generic `Receipt` metadata path
        // (`_vaultAssetSymbol` calls `IERC20Metadata(address(0)).symbol()`)
        // reverts, so this vault MUST be paired with a receipt implementation
        // that overrides the asset-symbol metadata rather than the generic
        // `Receipt`.
        if (config.receiptVaultConfig.asset != address(0)) {
            revert NonZeroAsset();
        }
        // The config admin MUST be set.
        if (config.initialAdmin == address(0)) {
            revert ZeroInitialAdmin();
        }

        _setAuthorizer(IAuthorizeV1(address(this)));

        _transferOwnership(config.initialAdmin);

        emit OffchainAssetReceiptVaultInitializedV2(
            _msgSender(),
            OffchainAssetReceiptVaultConfigV2({
                initialAdmin: config.initialAdmin, receiptVaultConfig: config.receiptVaultConfig
            })
        );
    }

    /// Returns the current highwater id.
    function highwaterId() external view returns (uint256) {
        OffchainAssetReceiptVault7201Storage storage s = getStorageOffchainAssetReceiptVault();
        return s.highwaterId;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAuthorizeV1).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IAuthorizableV1
    function authorizer() external view override returns (IAuthorizeV1) {
        OffchainAssetReceiptVault7201Storage storage s = getStorageOffchainAssetReceiptVault();
        return s.authorizer;
    }

    /// The vault initializes with the authorizer as itself. Every permission
    /// reverts unconditionally, so the owner MUST set the real authorizer before
    /// any operations can be performed.
    /// @inheritdoc IAuthorizeV1
    function authorize(address user, bytes32 permission, bytes memory data) external view virtual override {
        (user, permission, data);
        revert Unauthorized(user, permission, data);
    }

    /// Internal function to set the authorizer contract. This has no access
    /// control so it MUST only be externally accessible by functions with an
    /// access check.
    /// @param newAuthorizer The new authorizer contract.
    function _setAuthorizer(IAuthorizeV1 newAuthorizer) internal virtual {
        if (!IERC165(address(newAuthorizer)).supportsInterface(type(IAuthorizeV1).interfaceId)) {
            revert IncompatibleAuthorizer();
        }
        OffchainAssetReceiptVault7201Storage storage s = getStorageOffchainAssetReceiptVault();
        s.authorizer = newAuthorizer;
        emit AuthorizerSet(msg.sender, newAuthorizer);
    }

    /// Sets the authorizer contract. This is a critical operation and should be
    /// done with extreme care by the owner.
    /// @param newAuthorizer The new authorizer contract.
    function setAuthorizer(IAuthorizeV1 newAuthorizer) public virtual onlyOwner {
        _setAuthorizer(newAuthorizer);
    }

    /// Apply standard transfer restrictions to receipt transfers.
    /// @inheritdoc ReceiptVault
    function authorizeReceiptTransfer3(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public virtual override {
        super.authorizeReceiptTransfer3(operator, from, to, ids, amounts);
        ownerFreezeCheckTransaction(from, to);
        OffchainAssetReceiptVault7201Storage storage s = getStorageOffchainAssetReceiptVault();
        s.authorizer
            .authorize(
                operator,
                TRANSFER_RECEIPT,
                abi.encode(
                    TransferReceiptStateChange({
                        from: from, to: to, ids: ids, amounts: amounts, isCertificationExpired: isCertificationExpired()
                    })
                )
            );
    }

    /// DO NOT call super `_beforeDeposit` as there are no assets to move.
    /// Highwater needs to witness the incoming id.
    /// @inheritdoc ReceiptVault
    function _beforeDeposit(
        uint256 assets,
        address receiver,
        uint256 shares,
        uint256 id,
        bytes memory receiptInformation
    ) internal virtual override {
        (assets, receiver, shares, receiptInformation);
        OffchainAssetReceiptVault7201Storage storage s = getStorageOffchainAssetReceiptVault();
        s.highwaterId = s.highwaterId.max(id);
    }

    /// Authorize the deposit after the minting so that the authorizer can handle
    /// minted assets if appropriate and approved.
    /// For example, the "authorization" could be payment to a third party for
    /// the right to mint specific shares.
    /// @inheritdoc ReceiptVault
    function _afterDeposit(
        uint256 assets,
        address receiver,
        uint256 shares,
        uint256 id,
        bytes memory receiptInformation
    ) internal virtual override {
        OffchainAssetReceiptVault7201Storage storage s = getStorageOffchainAssetReceiptVault();
        s.authorizer
            .authorize(
                _msgSender(),
                DEPOSIT,
                abi.encode(
                    DepositStateChange({
                        owner: _msgSender(),
                        receiver: receiver,
                        id: id,
                        assetsDeposited: assets,
                        sharesMinted: shares,
                        data: receiptInformation
                    })
                )
            );
    }

    /// DO NOT call super `_afterWithdraw` as there are no assets to move.
    /// @inheritdoc ReceiptVault
    function _afterWithdraw(
        uint256 assets,
        address receiver,
        address owner,
        uint256 shares,
        uint256 id,
        bytes memory receiptInformation
    ) internal virtual override {
        OffchainAssetReceiptVault7201Storage storage s = getStorageOffchainAssetReceiptVault();
        s.authorizer
            .authorize(
                _msgSender(),
                WITHDRAW,
                abi.encode(
                    WithdrawStateChange({
                        owner: owner,
                        receiver: receiver,
                        id: id,
                        assetsWithdrawn: assets,
                        sharesBurned: shares,
                        data: receiptInformation
                    })
                )
            );
    }

    /// Shares total supply is 1:1 with offchain assets.
    /// Assets aren't real so only way to report this is to return the total
    /// supply of shares.
    /// @inheritdoc ReceiptVault
    function totalAssets() public view virtual override returns (uint256) {
        return totalSupply();
    }

    /// IDs for offchain assets are merely autoincremented. If the minter wants
    /// to track some external ID system as a foreign key they can emit this in
    /// the associated receipt information.
    /// @inheritdoc ReceiptVault
    function _nextId() internal view virtual override returns (uint256) {
        OffchainAssetReceiptVault7201Storage storage s = getStorageOffchainAssetReceiptVault();
        return s.highwaterId + 1;
    }

    /// Depositors can increase the deposited assets for the existing id of this
    /// receipt. It is STRONGLY RECOMMENDED the redepositor also provides data to
    /// be forwarded to asset information to justify the additional deposit. New
    /// offchain assets MUST NOT redeposit under existing IDs, they MUST be
    /// deposited under a new id instead. The ID preservation provided by
    /// `redeposit` is intended to ensure a consistent audit trail for the
    /// lifecycle of any asset. We do not need a corresponding "rewithdraw"
    /// function because withdrawals already target an ID.
    ///
    /// Note that the existence of `redeposit` and `withdraw` both allow the
    /// potential of two different depositor/withdrawer accounts to apply the
    /// same mint/burn concurrently to the mempool and have both included in a
    /// block inappropriately. Features like this, as well as more fundamental
    /// trust assumptions/limitations offchain, make it impossible to fully
    /// decouple depositors and withdrawers from each other _per token_. The
    /// model is that there are many decoupled tokens each with their own "team"
    /// that can be expected to coordinate to prevent double-mint/burn.
    ///
    /// @param assets As per IERC4626 `deposit`.
    /// @param receiver As per IERC4626 `deposit`.
    /// @param id The existing receipt to despoit additional assets under. Will
    /// mint new ERC20 shares and also increase the held receipt amount 1:1.
    /// @param receiptInformation Forwarded to receipt mint and
    /// `receiptInformation`.
    /// @return shares As per IERC4626 `deposit`.
    function redeposit(uint256 assets, address receiver, uint256 id, bytes calldata receiptInformation)
        external
        returns (uint256)
    {
        OffchainAssetReceiptVault7201Storage storage s = getStorageOffchainAssetReceiptVault();
        // Only allow redepositing for IDs that exist.
        if (id > s.highwaterId) {
            revert InvalidId(id);
        }

        uint256 shares = _calculateDeposit(assets, _shareRatio(_msgSender(), receiver, id, ShareAction.Mint), 0);

        _deposit(assets, receiver, shares, id, receiptInformation);
        return shares;
    }

    /// Certifiers MAY EXTEND OR REDUCE the `certifiedUntil` time. If there are
    /// many certifiers, any certifier can modify the certifiation at any time.
    /// It is STRONGLY RECOMMENDED that certifiers DO NOT set the `forceUntil`
    /// flag to `true` unless they want to:
    ///
    /// - Potentially override another certifier's concurrent certification
    /// - Reduce the certification time
    ///
    /// The certifier is STRONGLY RECOMMENDED to submit a summary report of the
    /// process and findings used to justify the modified `certifiedUntil` time.
    ///
    /// The certifier is STRONGLY RECOMMENDED to provide an unambiguous reference
    /// to the information used to inform their certification decision. This
    /// can be provided in the `data` field, and the onchain contracts are
    /// unopinionated as to what encoding convention is used, but it is
    /// important that end users can easily access and understand it somehow.
    /// This reference information is a SNAPSHOT of data and so if the onchain
    /// state moves relative to this snapshot (e.g. vault owner mints additional
    /// tokens while auditor is driving home from the gold vault), the auditor
    /// can't accidentally certify data that doesn't match what they reviewed
    /// in the real world. A good example of this would be a block number or a
    /// transaction hash from the blockchain this contract is deployed to, from
    /// which an offchain indexer such as a subgraph can compile all the mints,
    /// burns, additional data, etc. It is also STRONGLY RECOMMENDED that a self
    /// describing data format is used so that clients can interpret whether the
    /// reference is a block number, a transaction hash, a URL, etc.
    ///
    /// The certifier is STRONGLY RECOMMENDED to ONLY use publicly available
    /// documents e.g. those directly referenced by `ReceiptInformation` events
    /// to make their decision. The certifier SHOULD specify if, when and why
    /// private data was used to inform their certification decision. This is
    /// important for share (ERC20) holders who inform themselves on the quality
    /// of their tokens not only by the overall audit outcome, but by the
    /// integrity of the sum of its parts in the form of receipt and associated
    /// visible information.
    ///
    /// Note that redundant certifications MAY be submitted. Regardless of the
    /// `forceUntil` flag the transaction WILL NOT REVERT and the `Certify`
    /// event will be emitted for any valid `certifyUntil` time. If certifier A
    /// certifies until time X and certifier B certifies until time X - Y then
    /// both certifications will emit an event and time X is the certification
    /// date of the system. This encouranges multiple certifications to be sought
    /// in parallel if it helps maintain trust in the overall system.
    ///
    /// @param certifyUntil The new `certifiedUntil` time.
    /// @param forceUntil Whether to force the new certification time even if it
    /// is in the past relative to the existing certification time.
    /// @param data Arbitrary data justifying the certification. SHOULD reference
    /// data available offchain e.g. indexed data from this blockchain, IPFS,
    /// etc.
    function certify(uint256 certifyUntil, bool forceUntil, bytes calldata data) external {
        if (certifyUntil == 0) {
            revert ZeroCertifyUntil();
        }
        OffchainAssetReceiptVault7201Storage storage s = getStorageOffchainAssetReceiptVault();

        CertifyStateChange memory certifyStateChange = CertifyStateChange({
            oldCertifiedUntil: s.certifiedUntil,
            newCertifiedUntil: s.certifiedUntil,
            userCertifyUntil: certifyUntil,
            forceUntil: forceUntil,
            data: data
        });

        // A certifier can set `forceUntil` to true to force a _decrease_ in
        // the `certifiedUntil` time, which is unusual but MAY need to be done
        // in the case of rectifying a prior mistake.
        if (forceUntil || certifyUntil > s.certifiedUntil) {
            s.certifiedUntil = certifyUntil;
            certifyStateChange.newCertifiedUntil = certifyUntil;
        }
        emit Certify(_msgSender(), certifyUntil, forceUntil, data);

        s.authorizer.authorize(_msgSender(), CERTIFY, abi.encode(certifyStateChange));
    }

    /// @inheritdoc ICertifiableV1
    function isCertificationExpired() public view override returns (bool) {
        OffchainAssetReceiptVault7201Storage storage s = getStorageOffchainAssetReceiptVault();
        // `certifiedUntil` is a certifier-chosen deadline meant to span days or
        // longer, so the seconds a validator could skew only reclassify a
        // transfer already sitting on the boundary. Expiry is also not a
        // terminal state: a fresh `certify` reopens it, so skew has no lasting
        // effect in either direction.
        // forge-lint: disable-next-line(block-timestamp)
        return block.timestamp > s.certifiedUntil;
    }

    /// Apply standard transfer restrictions to share transfers.
    /// @inheritdoc ReceiptVault
    function _update(address from, address to, uint256 amount) internal virtual override {
        ownerFreezeCheckTransaction(from, to);

        OffchainAssetReceiptVault7201Storage storage s = getStorageOffchainAssetReceiptVault();
        s.authorizer
            .authorize(
                _msgSender(),
                TRANSFER_SHARES,
                abi.encode(
                    TransferSharesStateChange({
                        from: from, to: to, amount: amount, isCertificationExpired: isCertificationExpired()
                    })
                )
            );
        super._update(from, to, amount);
    }

    /// Confiscators can confiscate ERC20 vault shares from `confiscatee`.
    /// Confiscation BYPASSES the CERTIFICATION-EXPIRY transfer restriction (the
    /// authorizer permits a confiscator to move tokens while certification is
    /// expired) and IGNORES ALLOWANCES set by the confiscatee. It does NOT
    /// bypass the OWNER FREEZE: confiscation runs through the same
    /// `ownerFreezeCheckTransaction` as any other transfer, so while an owner
    /// freeze is active a confiscation reverts unless `from` and `to` are
    /// allowlisted via `ownerFreezeAlwaysAllowFrom` / `ownerFreezeAlwaysAllowTo`.
    ///
    /// The LIMITATION ON CONFISCATION is that the confiscatee MUST NOT have the
    /// minimum tier for transfers. I.e. confiscation is a two step process.
    /// First the tokens must be frozen according to due process by the token
    /// issuer (which may be an individual, organisation or many entities), THEN
    /// the confiscation can clear. This prevents rogue/compromised confiscators
    /// from being able to arbitrarily take tokens from users to themselves. At
    /// the least, assuming separate private keys managing the tiers and
    /// confiscation, the two steps require at least two critical security
    /// breaches per attack rather than one.
    ///
    /// Confiscation is a binary event. All shares or zero shares are
    /// confiscated from the confiscatee.
    ///
    /// Typically people DO NOT LIKE having their assets confiscated. It SHOULD
    /// be treated as a rare and extreme action, only taken when all other
    /// avenues/workarounds are explored and exhausted. The confiscator SHOULD
    /// provide their justification of each confiscation, and the general public,
    /// especially token holders SHOULD review and be highly suspect of unjust
    /// confiscation events. If you review and DO NOT agree with a confiscation
    /// you SHOULD NOT continue to hold the token, exiting systems that play fast
    /// and loose with user assets is the ONLY way to discourage such behaviour.
    ///
    /// @param confiscatee The address that shares are being confiscated from.
    /// @param targetAmount The amount of shares to confiscate. The actual amount
    /// will be capped at the current balance of the confiscatee.
    /// @param data The associated justification of the confiscation, and/or
    /// other relevant data.
    /// @return The amount of shares confiscated.
    function confiscateShares(address confiscatee, uint256 targetAmount, bytes memory data)
        external
        nonReentrant
        returns (uint256)
    {
        if (targetAmount == 0) {
            revert ZeroConfiscateAmount();
        }

        uint256 actualAmount = balanceOf(confiscatee).min(targetAmount);
        if (actualAmount > 0) {
            emit ConfiscateShares(_msgSender(), confiscatee, targetAmount, actualAmount, data);
            _transfer(confiscatee, _msgSender(), actualAmount);
        }

        OffchainAssetReceiptVault7201Storage storage s = getStorageOffchainAssetReceiptVault();
        s.authorizer
            .authorize(
                _msgSender(),
                CONFISCATE_SHARES,
                abi.encode(
                    ConfiscateSharesStateChange({
                        confiscatee: confiscatee, targetAmount: targetAmount, actualAmount: actualAmount, data: data
                    })
                )
            );

        return actualAmount;
    }

    /// Confiscators can confiscate ERC1155 vault receipts from `confiscatee`.
    /// The process, limitations and logic is identical to share confiscation
    /// except that receipt confiscation is performed per-ID.
    ///
    /// Typically people DO NOT LIKE having their assets confiscated. It SHOULD
    /// be treated as a rare and extreme action, only taken when all other
    /// avenues/workarounds are explored and exhausted. The confiscator SHOULD
    /// provide their justification of each confiscation, and the general public,
    /// especially token holders SHOULD review and be highly suspect of unjust
    /// confiscation events. If you review and DO NOT agree with a confiscation
    /// you SHOULD NOT continue to hold the token, exiting systems that play fast
    /// and loose with user assets is the ONLY way to discourage such behaviour.
    ///
    /// @param confiscatee The address that receipts are being confiscated from.
    /// @param id The ID of the receipt to confiscate.
    /// @param targetAmount The amount of the receipt to confiscate. The actual
    /// amount will be capped at the current balance of the confiscatee.
    /// @param data The associated justification of the confiscation, and/or
    /// other relevant data.
    /// @return The amount of receipt confiscated.
    function confiscateReceipt(address confiscatee, uint256 id, uint256 targetAmount, bytes memory data)
        external
        nonReentrant
        returns (uint256)
    {
        if (targetAmount == 0) {
            revert ZeroConfiscateAmount();
        }

        uint256 actualAmount = receipt().balanceOf(confiscatee, id).min(targetAmount);
        if (actualAmount > 0) {
            emit ConfiscateReceipt(_msgSender(), confiscatee, id, targetAmount, actualAmount, data);
            receipt().managerTransferFrom(_msgSender(), confiscatee, _msgSender(), id, actualAmount, "");
        }

        OffchainAssetReceiptVault7201Storage storage s = getStorageOffchainAssetReceiptVault();
        s.authorizer
            .authorize(
                _msgSender(),
                CONFISCATE_RECEIPT,
                abi.encode(
                    ConfiscateReceiptStateChange({
                        confiscatee: confiscatee,
                        id: id,
                        targetAmount: targetAmount,
                        actualAmount: actualAmount,
                        data: data
                    })
                )
            );

        return actualAmount;
    }
}
