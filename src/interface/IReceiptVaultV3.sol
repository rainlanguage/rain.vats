// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.0;

import {IReceiptVaultV1} from "./deprecated/IReceiptVaultV1.sol";
import {IReceiptV3} from "./IReceiptV3.sol";

/// @title IReceiptVaultV3
/// @notice The `IReceiptVaultV3` interface extends `IReceiptVaultV1` with a
/// getter for the `receipt` contract. Otherwise it is identical to
/// `IReceiptVaultV1`.
///
/// A single deposit creates positions at three addresses:
/// - Receipt (ERC-1155): Proof of deposit. One ID per deposit; required for
///   withdrawal.
/// - ReceiptVault (ERC-20): Fungible vault shares. Represents pro-rata claim
///   on the vault's underlying assets.
/// - WrappedTokenVault (ERC-4626, optional): Wraps receipt-vault shares;
///   captures rebases in share price rather than supply.
///
/// To withdraw underlying assets, a holder must burn both the receipt
/// (ERC-1155 at the specific deposit ID) and the shares (ERC-20). The receipt
/// is the audit-trail proof; the shares are the value claim.
interface IReceiptVaultV3 is IReceiptVaultV1 {
    /// @return The `IReceiptV3` contract that is the receipt for this vault.
    function receipt() external view returns (IReceiptV3);
}
