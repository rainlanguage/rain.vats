// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain-factory-0.1.1/src/interface/ICloneableV2.sol";

import {IReceiptManagerV2} from "../../interface/IReceiptManagerV2.sol";
import {IReceiptV3} from "../../interface/IReceiptV3.sol";
import {IReceiptVaultV3} from "../../interface/IReceiptVaultV3.sol";
import {OnlyManager} from "../../error/ErrReceipt.sol";
import {ERC1155Upgradeable} from "@openzeppelin-contracts-upgradeable-5.6.1/token/ERC1155/ERC1155Upgradeable.sol";
import {IERC20Metadata} from "@openzeppelin-contracts-5.6.1/token/ERC20/extensions/IERC20Metadata.sol";
import {Base64} from "@openzeppelin-contracts-5.6.1/utils/Base64.sol";
import {Strings} from "@openzeppelin-contracts-5.6.1/utils/Strings.sol";

/// @dev String ID for the Receipt storage location v1.
string constant RECEIPT_STORAGE_ID = "rain.storage.receipt.1";

/// @dev "rain.storage.receipt.1"
bytes32 constant RECEIPT_STORAGE_LOCATION = 0xe5444a702a2f437387f4eb075af275e349f1dba9a68923d27352f035d01dc200;

/// @dev The prefix for data URIs as base64 encoded JSON.
string constant DATA_URI_BASE64_PREFIX = "data:application/json;base64,";

/// @dev The name of a `Receipt` is "<vault share symbol> Receipt".
string constant RECEIPT_NAME_SUFFIX = " Receipt";

/// @dev The symbol of a `Receipt` is "<vault share symbol> RCPT".
string constant RECEIPT_SYMBOL_SUFFIX = " RCPT";

/// @title Receipt
/// @notice The `IReceiptV3` for a `ReceiptVault`. Standard implementation allows
/// receipt information to be emitted and mints/burns according to manager
/// authorization.
contract Receipt is IReceiptV3, ICloneableV2, ERC1155Upgradeable {
    /// @param manager The manager of the `Receipt` contract.
    /// Set during `initialize` and cannot be changed.
    /// Intended to be a `ReceiptVault` contract.
    /// @param operator The authorization operator for the duration of a manager
    /// call (the depositor/confiscator that the vault passed). Used ONLY to pass
    /// the correct operator to `authorizeReceiptTransfer3`; it deliberately does
    /// NOT affect `_msgSender()`, so the inherited ERC1155 functions and their
    /// acceptance callbacks observe the true `msg.sender` and cannot be spoofed.
    /// @custom:storage-location erc7201:rain.storage.receipt.1
    struct Receipt7201Storage {
        IReceiptManagerV2 manager;
        address operator;
    }

    /// @dev Accessor for receipt storage.
    function getStorageReceipt() private pure returns (Receipt7201Storage storage s) {
        assembly ("memory-safe") {
            s.slot := RECEIPT_STORAGE_LOCATION
        }
    }

    /// Disables initializers so that the clonable implementation cannot be
    /// initialized and used directly outside a factory deployment.
    constructor() {
        _disableInitializers();
    }

    /// Throws if the caller is not the manager of the `Receipt` contract.
    modifier onlyManager() {
        _onlyManager();
        _;
    }
    /// Throws if the caller is not the manager of the `Receipt` contract.
    /// Dedicated function to avoid code bloat from using a modifier directly.

    function _onlyManager() internal view {
        Receipt7201Storage storage s = getStorageReceipt();
        if (_msgSender() != address(s.manager)) {
            revert OnlyManager();
        }
    }

    /// Sets the authorization operator for the duration of a manager call. This
    /// is the address the vault passed (the depositor/confiscator) and is used
    /// ONLY to pass the correct operator to `authorizeReceiptTransfer3` in
    /// `_update`. It deliberately does NOT override `_msgSender()`, so the
    /// inherited ERC1155 functions and acceptance callbacks observe the true
    /// `msg.sender` and cannot be spoofed (see #309).
    /// @param operator The address to set as the authorization operator.
    modifier withOperator(address operator) {
        _withOperatorBefore(operator);
        _;
        _withOperatorAfter();
    }

    /// Sets the operator. Dedicated function to avoid code bloat from using a
    /// modifier directly.
    /// @param operator The address to set as the authorization operator.
    function _withOperatorBefore(address operator) internal {
        getStorageReceipt().operator = operator;
    }

    /// Resets the operator to address(0). Dedicated function to avoid code bloat
    /// from using a modifier directly.
    function _withOperatorAfter() internal {
        getStorageReceipt().operator = address(0);
    }

    /// Initializes the `Receipt` so that it is usable as a clonable
    /// implementation in `ReceiptFactory`.
    /// Compatible with `ICloneableV2`.
    function initialize(bytes memory data) public virtual override initializer returns (bytes32) {
        // `uri` is overridden in this contract so we can just initialize
        // `ERC1155` with an empty string.
        __ERC1155_init("");

        Receipt7201Storage storage s = getStorageReceipt();

        address receiptManager = abi.decode(data, (address));
        s.manager = IReceiptManagerV2(receiptManager);

        return ICLONEABLE_V2_SUCCESS;
    }

    /// @inheritdoc ERC1155Upgradeable
    function uri(uint256) public view virtual override returns (string memory) {
        bytes memory json = bytes(
            string.concat(
                "{\"decimals\":",
                Strings.toString(_vaultDecimals()),
                ",\"description\":\"1 of these receipts can be burned alongside 1 ",
                _vaultShareSymbol(),
                " to redeem ",
                _vaultAssetSymbol(),
                " from the vault.\",",
                "\"name\":\"",
                name(),
                "\"}"
            )
        );

        return string.concat(DATA_URI_BASE64_PREFIX, Base64.encode(json));
    }

    /// @inheritdoc IReceiptV3
    function name() public view virtual returns (string memory) {
        return string.concat(_vaultShareSymbol(), RECEIPT_NAME_SUFFIX);
    }

    /// @inheritdoc IReceiptV3
    function symbol() external view virtual returns (string memory) {
        return string.concat(_vaultShareSymbol(), RECEIPT_SYMBOL_SUFFIX);
    }

    /// Provides the symbol of the `ReceiptVault` ERC20 share token that manages
    /// this `Receipt`. Can be overridden if the manager is not going to be
    /// a `ReceiptVault`.
    function _vaultShareSymbol() internal view virtual returns (string memory) {
        Receipt7201Storage storage s = getStorageReceipt();
        return IERC20Metadata(payable(address(s.manager))).symbol();
    }

    /// Provides the symbol of the ERC20 asset token that the `ReceiptVault`
    /// managing this `Receipt` is accepting for mints. Can be overridden if the
    /// manager is not going to be a `ReceiptVault`.
    function _vaultAssetSymbol() internal view virtual returns (string memory) {
        Receipt7201Storage storage s = getStorageReceipt();
        return IERC20Metadata(IReceiptVaultV3(payable(address(s.manager))).asset()).symbol();
    }

    //slither-disable-next-line dead-code
    function _vaultDecimals() internal view virtual returns (uint8) {
        Receipt7201Storage storage s = getStorageReceipt();
        return IERC20Metadata(payable(address(s.manager))).decimals();
    }

    /// @inheritdoc IReceiptV3
    function manager() external view virtual returns (address) {
        Receipt7201Storage storage s = getStorageReceipt();
        return address(s.manager);
    }

    /// @inheritdoc IReceiptV3
    function managerMint(address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
        virtual
        onlyManager
        withOperator(sender)
    {
        _receiptInformation(sender, id, data);
        _mint(account, id, amount, data);
    }

    /// @inheritdoc IReceiptV3
    function managerBurn(address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
        virtual
        onlyManager
        withOperator(sender)
    {
        _receiptInformation(sender, id, data);
        _burn(account, id, amount);
    }

    /// @inheritdoc IReceiptV3
    function managerTransferFrom(
        address sender,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external virtual onlyManager withOperator(sender) {
        _safeTransferFrom(from, to, id, amount, data);
    }

    /// Checks with the manager before authorizing transfer IN ADDITION to
    /// `super` inherited checks.
    /// @inheritdoc ERC1155Upgradeable
    function _update(address from, address to, uint256[] memory ids, uint256[] memory amounts)
        internal
        virtual
        override
    {
        Receipt7201Storage storage s = getStorageReceipt();
        // The authorization operator is the explicit operator set by the active
        // manager call (the depositor/confiscator the vault passed), falling
        // back to the real caller for direct peer-to-peer transfers. This is
        // kept separate from `_msgSender()` on purpose: `_msgSender()` is NOT
        // overridden, so ERC1155 acceptance callbacks cannot spoof identities
        // (#309), while `authorizeReceiptTransfer3` still receives the true
        // initiator (e.g. a confiscator must still be seen for the
        // confiscation-during-certification-expiry bypass).
        address operator = s.operator;
        if (operator == address(0)) {
            operator = _msgSender();
        }
        // Clear the stored operator now that it has been captured, BEFORE
        // authorizing and BEFORE `super._update` fires any ERC1155 acceptance
        // callback. Otherwise a transfer that re-enters during the callback (or
        // a malicious authorizer) would inherit this call's operator for its own
        // `authorizeReceiptTransfer3` instead of its true caller. Each manager
        // call performs exactly one `_update`, so clearing here does not affect
        // the operator the rest of this call sees.
        s.operator = address(0);
        s.manager.authorizeReceiptTransfer3(operator, from, to, ids, amounts);
        super._update(from, to, ids, amounts);
    }

    /// Emits `ReceiptInformation` if there is any data.
    /// @param account The account that is emitting receipt information.
    /// @param id The id of the receipt this information is for.
    /// @param data The data being emitted as information for the receipt.
    function _receiptInformation(address account, uint256 id, bytes memory data) internal virtual {
        // No data is noop.
        if (data.length > 0) {
            emit ReceiptInformation(account, id, data);
        }
    }

    /// @inheritdoc IReceiptV3
    function receiptInformation(uint256 id, bytes memory data) external virtual {
        _receiptInformation(_msgSender(), id, data);
    }
}
