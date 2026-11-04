// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IAuthorizeV1, Unauthorized} from "../../interface/IAuthorizeV1.sol";

import {AccessControlUpgradeable} from "@openzeppelin-contracts-upgradeable-5.7.0/access/AccessControlUpgradeable.sol";
import {IAccessControl} from "@openzeppelin-contracts-5.7.0/access/IAccessControl.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain-factory-0.2.10/src/interface/ICloneableV2.sol";
import {
    CONFISCATE_RECEIPT,
    CONFISCATE_SHARES,
    CERTIFY,
    DEPOSIT,
    WITHDRAW,
    TRANSFER_SHARES,
    TRANSFER_RECEIPT,
    TransferSharesStateChange,
    TransferReceiptStateChange
} from "../../abstract/OffchainAssetReceiptVault.sol";
import {IERC165} from "@openzeppelin-contracts-5.7.0/utils/introspection/IERC165.sol";
import {LibConfigRegistry} from "rain-deploy-0.1.30/src/lib/LibConfigRegistry.sol";

/// Thrown when the admin is address zero.
error ZeroInitialAdmin();

/// Thrown when `initialize` data does not lead with
/// `OFFCHAIN_ASSET_RECEIPT_VAULT_AUTHORIZER_V1_CONFIG_V2_TAG`.
/// @param version The leading word, or zero for data shorter than a word.
error UnknownAuthorizerConfigVersion(bytes32 version);

/// Thrown when `initialize` data is not the canonical ABI encoding of the
/// version tag and `OffchainAssetReceiptVaultAuthorizerV1ConfigV2`.
error NonCanonicalAuthorizerConfig();

/// Thrown when the initial admin binding is not the canonical ABI encoding of
/// an address.
/// @param authority The authority the binding was resolved under.
/// @param name The name the binding was resolved from.
error NonCanonicalInitialAdmin(address authority, bytes32 name);

/// Thrown when a transfer is attempted by an unpriviledged account during system
/// freeze due to certification lapse.
/// @param from The account the transfer is from.
/// @param to The account the transfer is to.
error CertificationExpired(address from, address to);

/// @dev Rolename for certify admins.
bytes32 constant CERTIFY_ADMIN = keccak256("CERTIFY_ADMIN");
/// @dev Rolename for confiscating shares admins.
bytes32 constant CONFISCATE_SHARES_ADMIN = keccak256("CONFISCATE_SHARES_ADMIN");
/// @dev Rolename for confiscating receipts admins.
bytes32 constant CONFISCATE_RECEIPT_ADMIN = keccak256("CONFISCATE_RECEIPT_ADMIN");
/// @dev Rolename for deposit admins.
bytes32 constant DEPOSIT_ADMIN = keccak256("DEPOSIT_ADMIN");
/// @dev Rolename for withdraw admins.
bytes32 constant WITHDRAW_ADMIN = keccak256("WITHDRAW_ADMIN");

/// @dev The `ConfigRegistry` value type the initial admin is bound as.
bytes32 constant INITIAL_ADMIN_VALUE_TYPE_HASH = keccak256("address");

/// @dev The version tag leading `OffchainAssetReceiptVaultAuthorizerV1`
/// `initialize` data: `abi.encode(TAG, config)`. An implementation rejects a
/// tag it does not know, so data written for a later implementation reverts on
/// an earlier one instead of being misread.
bytes32 constant OFFCHAIN_ASSET_RECEIPT_VAULT_AUTHORIZER_V1_CONFIG_V2_TAG =
    keccak256("OffchainAssetReceiptVaultAuthorizerV1ConfigV2");

/// @dev The resolved config `_initialize` takes.
/// @param initialAdmin The initial admin of the contract.
struct OffchainAssetReceiptVaultAuthorizerV1Config {
    address initialAdmin;
}

/// The config `OffchainAssetReceiptVaultAuthorizerV1.initialize` takes after
/// its version tag. It names the admin binding, not the admin, so the same
/// data initializes a clone at one address on every chain while each chain
/// binds its own admin.
/// @param authority The `ConfigRegistry` authority whose binding of
/// `initialAdminName` is trusted for the initial admin.
/// @param initialAdminName The name the initial admin is resolved from, once,
/// at `initialize`. A later rebind moves no roles.
struct OffchainAssetReceiptVaultAuthorizerV1ConfigV2 {
    address authority;
    bytes32 initialAdminName;
}

/// @title OffchainAssetReceiptVaultAuthorizorV1
/// Implements the IAuthorizeV1 interface and provides a simple role based
/// access control for the OffchainAssetReceiptVault.
contract OffchainAssetReceiptVaultAuthorizerV1 is IAuthorizeV1, ICloneableV2, AccessControlUpgradeable {
    constructor() {
        _disableInitializers();
    }

    /// Resolves the initial admin from the registry and initializes with it.
    /// @param data `abi.encode(OFFCHAIN_ASSET_RECEIPT_VAULT_AUTHORIZER_V1_CONFIG_V2_TAG, config)`.
    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) external virtual override initializer returns (bytes32) {
        if (data.length < 0x20) {
            revert UnknownAuthorizerConfigVersion(bytes32(0));
        }
        bytes32 version = abi.decode(data, (bytes32));
        if (version != OFFCHAIN_ASSET_RECEIPT_VAULT_AUTHORIZER_V1_CONFIG_V2_TAG) {
            revert UnknownAuthorizerConfigVersion(version);
        }
        (, OffchainAssetReceiptVaultAuthorizerV1ConfigV2 memory config) =
            abi.decode(data, (bytes32, OffchainAssetReceiptVaultAuthorizerV1ConfigV2));
        // The factory hashes the raw `data` into the address, so without this
        // one config has many addresses.
        if (keccak256(abi.encode(version, config)) != keccak256(data)) {
            revert NonCanonicalAuthorizerConfig();
        }

        // When the binding was written does not matter here.
        //slither-disable-next-line unused-return
        (bytes memory adminValue,) =
            LibConfigRegistry.resolve(config.authority, config.initialAdminName, INITIAL_ADMIN_VALUE_TYPE_HASH);
        address initialAdmin = abi.decode(adminValue, (address));
        if (keccak256(abi.encode(initialAdmin)) != keccak256(adminValue)) {
            revert NonCanonicalInitialAdmin(config.authority, config.initialAdminName);
        }

        return _initialize(OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin}));
    }

    /// Initialization logic without the initializer modifier so inheriting
    /// contracts can access it and be the initializer. Accepts the decoded
    /// config so child contracts don't need to double-decode.
    function _initialize(OffchainAssetReceiptVaultAuthorizerV1Config memory config) internal virtual returns (bytes32) {
        __AccessControl_init();

        // The config admin MUST be set.
        if (config.initialAdmin == address(0)) {
            revert ZeroInitialAdmin();
        }

        // Define all admin roles. Note that admins can admin each other which
        // is a double edged sword. ANY admin can forcibly take over the entire
        // role by removing all other admins.
        _setRoleAdmin(CERTIFY, CERTIFY_ADMIN);
        _setRoleAdmin(CERTIFY_ADMIN, CERTIFY_ADMIN);

        _setRoleAdmin(CONFISCATE_RECEIPT, CONFISCATE_RECEIPT_ADMIN);
        _setRoleAdmin(CONFISCATE_RECEIPT_ADMIN, CONFISCATE_RECEIPT_ADMIN);

        _setRoleAdmin(CONFISCATE_SHARES, CONFISCATE_SHARES_ADMIN);
        _setRoleAdmin(CONFISCATE_SHARES_ADMIN, CONFISCATE_SHARES_ADMIN);

        _setRoleAdmin(DEPOSIT, DEPOSIT_ADMIN);
        _setRoleAdmin(DEPOSIT_ADMIN, DEPOSIT_ADMIN);

        _setRoleAdmin(WITHDRAW, WITHDRAW_ADMIN);
        _setRoleAdmin(WITHDRAW_ADMIN, WITHDRAW_ADMIN);

        _grantRole(CERTIFY_ADMIN, config.initialAdmin);
        _grantRole(CONFISCATE_RECEIPT_ADMIN, config.initialAdmin);
        _grantRole(CONFISCATE_SHARES_ADMIN, config.initialAdmin);
        _grantRole(DEPOSIT_ADMIN, config.initialAdmin);
        _grantRole(WITHDRAW_ADMIN, config.initialAdmin);

        return ICLONEABLE_V2_SUCCESS;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAuthorizeV1).interfaceId || interfaceId == type(ICloneableV2).interfaceId
            || interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /// Permissions are treated as roles in this implementation. This makes the
    /// implementation roughly equivalent overall to the `onlyRole` modifier in
    /// OpenZeppelin's AccessControl.
    /// As this is implemented as `view` we don't need to enforce the caller.
    /// @inheritdoc IAuthorizeV1
    function authorize(address user, bytes32 permission, bytes memory data) public virtual override {
        // The permission to transfer is not RBAC. In certain circumstances some
        // users with roles MAY be able to transfer when otherwise disallowed,
        // but the base case is that everyone can transfer.
        /// Reverts if some transfer is disallowed. Handles both share and receipt
        /// transfers. Standard logic reverts any transfer that is EITHER to or from
        /// an address that does not have the required tier OR the system is no
        /// longer certified therefore ALL unpriviledged transfers MUST revert.
        ///
        /// Certain exemptions to transfer restrictions apply:
        /// - If a tier contract is not set OR the minimum tier is 0 then tier
        ///   restrictions are ignored.
        /// - Any handler role MAY SEND AND RECEIVE TOKENS AT ALL TIMES BETWEEN
        ///   THEMSELVES AND ANYONE ELSE. Tier and certification restrictions are
        ///   ignored for both sender and receiver when either is a handler. Handlers
        ///   exist to _repair_ certification issues, so MUST be able to transfer
        ///   unhindered.
        /// - `address(0)` is treated as a handler for the purposes of any minting
        ///   and burning that may be required to repair certification blockers.
        /// - Transfers TO a confiscator are treated as handler-like at all times,
        ///   but transfers FROM confiscators are treated as unpriviledged. This is
        ///   to allow potential legal requirements on confiscation during system
        ///   freeze, without assigning unnecessary priviledges to confiscators.
        if (permission == TRANSFER_SHARES || permission == TRANSFER_RECEIPT) {
            address from;
            address to;
            bool isCertificationExpired;
            if (permission == TRANSFER_SHARES) {
                TransferSharesStateChange memory transferSharesStateChange =
                    abi.decode(data, (TransferSharesStateChange));
                from = transferSharesStateChange.from;
                to = transferSharesStateChange.to;
                isCertificationExpired = transferSharesStateChange.isCertificationExpired;
            } else {
                TransferReceiptStateChange memory transferReceiptStateChange =
                    abi.decode(data, (TransferReceiptStateChange));
                from = transferReceiptStateChange.from;
                to = transferReceiptStateChange.to;
                isCertificationExpired = transferReceiptStateChange.isCertificationExpired;
            }

            // Everyone else can only transfer while the certification is valid.
            if (isCertificationExpired) {
                // Minting and burning is always allowed for the respective roles if they
                // interact directly with the shares/receipt. Minting and burning is ALSO
                // valid after the certification expires as it is likely the only way to
                // repair the system and bring it back to a certifiable state.
                if ((from == address(0) && hasRole(DEPOSIT, to)) || (to == address(0) && hasRole(WITHDRAW, from))) {
                    return;
                }

                // Confiscators bypass the certification check when they are the
                // user. This allows for legal confiscation during system freeze
                // and for certification repair.
                if (
                    (permission == TRANSFER_SHARES && hasRole(CONFISCATE_SHARES, user))
                        || (permission == TRANSFER_RECEIPT && hasRole(CONFISCATE_RECEIPT, user))
                ) {
                    return;
                }

                revert CertificationExpired(from, to);
            } else {
                return;
            }
        } else if (hasRole(permission, user)) {
            return;
        }

        revert Unauthorized(user, permission, data);
    }
}
