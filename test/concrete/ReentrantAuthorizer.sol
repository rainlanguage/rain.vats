// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IAuthorizeV1} from "src/interface/IAuthorizeV1.sol";
import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";

/// @dev Minimal view of the vault `deposit` entrypoint the authorizer re-enters.
interface IReentrantAuthorizerVault {
    function deposit(uint256 assets, address receiver, uint256 depositMinShareRatio, bytes memory receiptInformation)
        external
        returns (uint256);
}

/// @title ReentrantAuthorizer
/// @notice TEST authorizer that is a REAL, owner-swappable, reentrant dependency.
/// A malicious owner can install this via `setAuthorizer`. When the vault calls
/// `authorize` for the configured trigger permission, it re-enters the vault's
/// guarded `deposit`. Every non-trigger permission is allowed (returns) so the
/// outer flow proceeds far enough to reach the trigger call site.
///
/// The trigger permission selects which authorize call site is exercised, all of
/// which fire while the shared `nonReentrant` guard held by `_deposit` is live:
/// - `TRANSFER_RECEIPT` — the `authorizeReceiptTransfer3` call during the ERC1155
///   receipt mint (row 12).
/// - `DEPOSIT` — the `_afterDeposit` call (row 13).
///
/// The re-entrant deposit therefore reverts with `ReentrancyGuardReentrantCall`,
/// which propagates out and reverts the whole outer deposit.
contract ReentrantAuthorizer is IAuthorizeV1, IERC165 {
    IReentrantAuthorizerVault internal iVault;
    bytes32 internal immutable iTrigger;

    constructor(bytes32 trigger) {
        iTrigger = trigger;
    }

    /// Point the authorizer at the vault it should re-enter.
    function setVault(IReentrantAuthorizerVault vault) external {
        iVault = vault;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IAuthorizeV1).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /// @inheritdoc IAuthorizeV1
    function authorize(address, bytes32 permission, bytes memory) external override {
        if (address(iVault) != address(0) && permission == iTrigger) {
            iVault.deposit(1, address(this), 0, "");
        }
    }
}
