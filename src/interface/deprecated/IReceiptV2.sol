// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IERC1155} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155.sol";

/// @title IReceiptV2
/// @notice IReceiptV2 is an extension to IERC1155 that requires implementers to
/// provide an interface to allow a manager to UNILATERALLY (e.g. without access
/// or allowance restrictions):
///
/// - mint
/// - burn
/// - transfer
/// - emit data
///
/// The manager MUST implement a compatible `IReceiptManagerV*` to authorize
/// transfers and receipt information. The `IReceiptV2` MUST call the relevant
/// authorization function on its manager for receipt information and standard
/// ERC1155 transfers.
///
/// Earlier versions of `ReceiptVault` implemented the vault as BOTH an ERC1155
/// AND ERC20/4626 vault, which technically worked fine onchain but offchain
/// tooling such as MetaMask seems to only understand a contract implementing one
/// token interface. The combination of `IReceiptV2` and `IReceiptManagerV*`
/// attempts to emulate the hybrid token model through paired interfaces.
///
/// The manager is effectively required to be a smart contract by nature, and
/// expected to be the `ReceiptVault` contract.
interface IReceiptV2 is IERC1155 {
    /// Emitted when new information is provided for a receipt.
    /// @param sender `msg.sender` emitting the information for the receipt.
    /// @param id Receipt the information is for.
    /// @param information Information for the receipt. MAY reference offchain
    /// data where the payload is large.
    event ReceiptInformation(address sender, uint256 id, bytes information);

    /// The name of the receipt token.
    /// This is non-standard and is not part of the ERC1155 interface. It is
    /// added here to ensure maximum compatibility with offchain tools such as
    /// block explorers and wallets that may not support inspecting the metadata
    /// URI.
    /// @return name The name of the receipt token.
    function name() external view returns (string memory);

    /// The symbol of the receipt token.
    /// This is non-standard and is not part of the ERC1155 interface. It is
    /// added here to ensure maximum compatibility with offchain tools such as
    /// block explorers and wallets that may not support inspecting the metadata
    /// URI.
    /// @return symbol The symbol of the receipt token.
    function symbol() external view returns (string memory);

    /// The address of the `IReceiptManagerV*`. This is expected to be a
    /// `ReceiptVault` that can safely manage dangerous `manager*` functions.
    /// @return manager The manager account.
    function manager() external view returns (address);

    /// The manager MAY directly mint receipts for any account, ID and amount
    /// without restriction. The data MUST be treated as both ERC1155 data and
    /// receipt information. Overflow MUST revert as usual for ERC1155.
    /// MUST REVERT if the `msg.sender` is NOT the manager. Receipt information
    /// MUST be emitted under the sender not the receiver account.
    /// @param sender The sender to emit receipt information under.
    /// @param account The account to mint a receipt for.
    /// @param id The receipt ID to mint.
    /// @param amount The amount to mint for the `id`.
    /// @param data The ERC1155 data. MUST be emitted as receipt information.
    function managerMint(address sender, address account, uint256 id, uint256 amount, bytes memory data) external;

    /// The manager MAY directly burn receipts for any account, ID and amount
    /// without restriction. Underflow MUST revert as usual for ERC1155.
    /// MUST REVERT if the `msg.sender` is NOT the manager. Receipt information
    /// MUST be emitted under the sender not the receipt manager account.
    /// @param sender The sender to emit receipt information under.
    /// @param account The account to burn a receipt for.
    /// @param id The receipt ID to burn.
    /// @param amount The amount to mint for the `id`.
    /// @param data MUST be emitted as receipt information.
    function managerBurn(address sender, address account, uint256 id, uint256 amount, bytes memory data) external;

    /// The manager MAY directly transfer receipts from and to any account for
    /// any id and amount without restriction. Overflow and underflow MUST revert
    /// as usual for ERC1155.
    /// MUST REVERT if the `msg.sender` is NOT the manager.
    /// @param from The account to transfer from.
    /// @param to The account to transfer to.
    /// @param id The receipt ID
    /// @param amount The amount to transfer between accounts.
    /// @param data The data associated with the transfer as per ERC1155.
    /// MUST NOT be emitted as receipt information.
    function managerTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;

    /// Emit a `ReceiptInformation` event for some receipt ID with `data` as the
    /// receipt information. ANY `msg.sender` MAY call this, it is up to offchain
    /// processes/indexers to filter unwanted receipt information before display
    /// and consumption.
    /// @param id The receipt ID this information is for.
    /// @param data The data of the receipt information. MAY be ANY data format
    /// or even malicious/garbage data. The indexer is responsible for filtering
    /// unwanted data.
    function receiptInformation(uint256 id, bytes memory data) external;
}
