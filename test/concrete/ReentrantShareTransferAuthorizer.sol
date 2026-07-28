// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IAuthorizeV1} from "src/interface/IAuthorizeV1.sol";
import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";
import {TRANSFER_SHARES} from "src/concrete/vault/OffchainAssetReceiptVault.sol";

/// @dev Minimal view of the share `transferFrom` the authorizer re-enters.
interface IReentrantShareVault {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title ReentrantShareTransferAuthorizer
/// @notice TEST authorizer that is a REAL, owner-swappable, reentrant dependency
/// targeting the share `_update` call site (row 15). The vault's `_update` calls
/// `authorize(TRANSFER_SHARES)` BEFORE `super._update` writes balances, and
/// `_update` is deliberately NOT `nonReentrant`. This authorizer exploits that
/// window: from inside the outer transfer's authorize hook it re-enters
/// `transferFrom(victim, attacker, amount)` to try to move the victim's shares a
/// second time before the outer transfer's balance write lands.
///
/// The attack MUST fail: the nested transfer writes the victim to zero, then the
/// outer `super._update` underflows the victim's balance and reverts with
/// `ERC20InsufficientBalance`. No double-spend is possible. This proves the row
/// 15 claim that ERC20 accounting — not a reentrancy guard — protects the
/// unguarded share-transfer authorize hook.
///
/// The re-entry is one-shot (`iEntered`) so the nested transfer's own authorize
/// hook does not recurse, isolating the single overspend attempt under test.
contract ReentrantShareTransferAuthorizer is IAuthorizeV1, IERC165 {
    IReentrantShareVault internal iVault;
    address internal iVictim;
    address internal iAttacker;
    uint256 internal iAmount;
    bool internal iEntered;

    /// Configure the overspend attempt.
    function configure(IReentrantShareVault vault, address victim, address attacker, uint256 amount) external {
        iVault = vault;
        iVictim = victim;
        iAttacker = attacker;
        iAmount = amount;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IAuthorizeV1).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /// @inheritdoc IAuthorizeV1
    function authorize(address, bytes32 permission, bytes memory) external override {
        if (permission == TRANSFER_SHARES && !iEntered && address(iVault) != address(0)) {
            iEntered = true;
            // Try to move the victim's shares a second time inside the
            // pre-balance-write window. Succeeds here (victim still holds them)
            // but dooms the outer transfer to an underflow revert.
            iVault.transferFrom(iVictim, iAttacker, iAmount);
        }
    }
}
