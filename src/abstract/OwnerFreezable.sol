// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IOwnerFreezableV1, IERC5313} from "../interface/IOwnerFreezableV1.sol";

/// @dev String ID for the OwnerFreezableV1 storage location v1.
string constant OWNER_FREEZABLE_V1_STORAGE_ID = "rain.storage.owner-freezable.1";

/// @dev Thrown when an inheritor's initializer runs at `block.timestamp ==
/// 0`. This indicates a corrupted execution environment, not a user
/// input error: every real EVM has a non-zero block timestamp from
/// genesis onward (decades in the past), so a zero timestamp can only
/// arise under contrived test setups (`vm.warp(0)`) or a malformed
/// fork. `OwnerFreezable`'s inclusive timestamp checks treat the
/// stored 0 sentinel as an active deadline at the genesis timestamp,
/// so allowing initialization through this state would let the
/// inheritor wedge itself in an ambiguous freeze permanently.
/// Refuse the deployment at the boundary instead of carrying the
/// ambiguity forward.
error CorruptedEnvironmentBlockTimestampZero();

/// @dev "rain.storage.owner-freezable.1" with the erc7201 formula.
bytes32 constant OWNER_FREEZABLE_V1_STORAGE_LOCATION =
    0x04485615b1da6633eec3daf54aadca2a89ef8b155744e223a046f4a6e38be700;

/// @title OwnerFreezable
/// This abstract contract inherits from Ownable and adds the ability for the
/// owner to freeze the contract until a given timestamp. The owner cannot
/// reverse this freeze, although they can extend it.
///
/// The idea is that if an attacker were to phish/compromise the owner key then
/// the owner can no longer be trusted to perform any actions on the contract.
/// At this point, the only real solution is to snapshot and airdrop a fresh
/// token using offchain data, with a new uncompromised owner.
///
/// The main challenges when performing this snapshot are:
/// - Ascertaining the most correct moment to take the snapshot.
/// - Mitigating secondary fund losses from markets, such as tokens paired
///   against the compromised token on Uniswap, etc.
///
/// By freezing the contract in a way the owner cannot reverse, we create a clear
/// moment to snapshot the contract.
///
/// By allowing the owner to add addresses that can always send/receive, they can
/// partially mitigate the risk of secondary fund losses. For example, the owner
/// could add Uniswap contracts to the always allowed list, to allow LPs to
/// remove their LP positions gracefully. Even if the attacker adds more
/// addresses to the always allowed list, they cannot e.g. infinite mint and rug
/// the pool themselves, everyone still only has access to the tokens they
/// already had.
///
/// Important note: Alone these functions do not protect against a compromised
/// owner key. They are a basic toolkit that would allow a smart contract to be
/// written _as the owner_ to implement the actual governance process desired.
/// For example, the owner could be written such that any modification to the
/// ownership and/or authorizor contract triggers a 24 hour freeze. Or it could
/// allow adding `from` addresses to the always allowed list, but not `to`
/// addresses, to mitigate the risk that the attacker opens up the ability to
/// dump on the LPs en masse after the snapshot.
abstract contract OwnerFreezable is IOwnerFreezableV1, OwnableUpgradeable {
    /// @param ownerFrozenUntil Contract is frozen through and including this
    /// time. Inclusive boundary — at `block.timestamp == ownerFrozenUntil`
    /// the contract is still frozen; the freeze releases on the first block
    /// where `block.timestamp > ownerFrozenUntil`.
    /// @param alwaysAllowedFroms Mapping of `from` addresses that are always
    /// allowed to send. If the protected time is any non-zero value then the
    /// `from` address is always allowed to send. While the current time is at
    /// or before the protected time the `from` address cannot be removed from
    /// the always allowed list (inclusive boundary).
    /// @param alwaysAllowedTos Mapping of `to` addresses that are always
    /// allowed to receive. If the protected time is any non-zero value then the
    /// `to` address is always allowed to receive. While the current time is at
    /// or before the protected time the `to` address cannot be removed from the
    /// always allowed list (inclusive boundary).
    /// @custom:storage-location erc7201:rain.storage.owner-freezable.1
    struct OwnerFreezableV17201Storage {
        uint256 ownerFrozenUntil;
        mapping(address from => uint256 protectedUntil) alwaysAllowedFroms;
        mapping(address to => uint256 protectedUntil) alwaysAllowedTos;
    }

    /// @dev Accessor for the owner freezable storage.
    function getStorageOwnerFreezable() private pure returns (OwnerFreezableV17201Storage storage s) {
        assembly ("memory-safe") {
            s.slot := OWNER_FREEZABLE_V1_STORAGE_LOCATION
        }
    }

    /// @dev Init-time guard against the `block.timestamp == 0` corner.
    /// Inheritors MUST call this from their initializer.
    // slither-disable-next-line dead-code
    function __OwnerFreezable_init() internal {
        if (block.timestamp == 0) revert CorruptedEnvironmentBlockTimestampZero();
    }

    /// @inheritdoc IERC5313
    function owner() public view virtual override(IERC5313, OwnableUpgradeable) returns (address) {
        return super.owner();
    }

    /// @inheritdoc IOwnerFreezableV1
    function ownerFrozenUntil() external view returns (uint256) {
        OwnerFreezableV17201Storage storage s = getStorageOwnerFreezable();
        return s.ownerFrozenUntil;
    }

    /// @inheritdoc IOwnerFreezableV1
    function ownerFreezeAlwaysAllowedFrom(address from) external view returns (uint256) {
        OwnerFreezableV17201Storage storage s = getStorageOwnerFreezable();
        return s.alwaysAllowedFroms[from];
    }

    /// @inheritdoc IOwnerFreezableV1
    function ownerFreezeAlwaysAllowedTo(address to) external view returns (uint256) {
        OwnerFreezableV17201Storage storage s = getStorageOwnerFreezable();
        return s.alwaysAllowedTos[to];
    }

    /// @inheritdoc IOwnerFreezableV1
    function ownerFreezeUntil(uint256 freezeUntil) external onlyOwner {
        OwnerFreezableV17201Storage storage s = getStorageOwnerFreezable();
        // Freezing is additive so we can only increase the freeze time.
        // It is a no-op on the state if the new freeze time is less than the
        // current one.
        if (freezeUntil > s.ownerFrozenUntil) {
            s.ownerFrozenUntil = freezeUntil;
        }

        // Emit the event with the new freeze time. We do this even if the
        // freeze time is unchanged so that we can track the history of
        // freeze calls offchain.
        emit OwnerFrozenUntil(owner(), freezeUntil, s.ownerFrozenUntil);
    }

    /// @inheritdoc IOwnerFreezableV1
    function ownerFreezeAlwaysAllowFrom(address from, uint256 protectUntil) external onlyOwner {
        // Until MUST NOT be zero. Call `ownerFreezeStopAlwaysAllowingFrom`
        // explicitly to remove a `from` address.
        if (protectUntil == 0) {
            revert OwnerFreezeAlwaysAllowedFromZero(from);
        }

        OwnerFreezableV17201Storage storage s = getStorageOwnerFreezable();

        // Adding a `from` is additive so we can only increase the protected
        // time. It is a no-op on the state if the new protected time is less
        // than the current one.
        if (protectUntil > s.alwaysAllowedFroms[from]) {
            s.alwaysAllowedFroms[from] = protectUntil;
        }
        // Emit the event with the new protected time. We do this even if the
        // protected time is unchanged so that we can track the history of
        // protections offchain.
        emit OwnerFreezeAlwaysAllowedFrom(owner(), from, protectUntil, s.alwaysAllowedFroms[from]);
    }

    /// @inheritdoc IOwnerFreezableV1
    function ownerFreezeStopAlwaysAllowingFrom(address from) external onlyOwner {
        OwnerFreezableV17201Storage storage s = getStorageOwnerFreezable();

        // Inclusive boundary: protection is active through and including
        // `protectedUntil`. Removal becomes possible only once
        // `block.timestamp > protectedUntil`. Matches the convention used
        // by `OffchainAssetReceiptVault.certifiedUntil` and the corporate
        // action `effectiveTime` semantics on consumers.
        if (block.timestamp <= s.alwaysAllowedFroms[from]) {
            revert OwnerFreezeAlwaysAllowedFromProtected(from, s.alwaysAllowedFroms[from]);
        }

        delete s.alwaysAllowedFroms[from];
        emit OwnerFreezeAlwaysAllowedFrom(owner(), from, 0, 0);
    }

    /// @inheritdoc IOwnerFreezableV1
    function ownerFreezeAlwaysAllowTo(address to, uint256 protectUntil) external onlyOwner {
        // Until MUST NOT be zero. Call `ownerFreezeStopAlwaysAllowingTo`
        // explicitly to remove a `to` address.
        if (protectUntil == 0) {
            revert IOwnerFreezableV1.OwnerFreezeAlwaysAllowedToZero(to);
        }

        OwnerFreezableV17201Storage storage s = getStorageOwnerFreezable();

        // Adding a `to` is additive so we can only increase the protected time.
        // It is a no-op on the state if the new protected time is less than the
        // current one.
        if (protectUntil > s.alwaysAllowedTos[to]) {
            s.alwaysAllowedTos[to] = protectUntil;
        }
        // Emit the event with the new protected time. We do this even if the
        // protected time is unchanged so that we can track the history of
        // protections offchain.
        emit OwnerFreezeAlwaysAllowedTo(owner(), to, protectUntil, s.alwaysAllowedTos[to]);
    }

    /// @inheritdoc IOwnerFreezableV1
    function ownerFreezeStopAlwaysAllowingTo(address to) external onlyOwner {
        OwnerFreezableV17201Storage storage s = getStorageOwnerFreezable();

        // Inclusive boundary — see `ownerFreezeStopAlwaysAllowingFrom`.
        if (block.timestamp <= s.alwaysAllowedTos[to]) {
            revert IOwnerFreezableV1.OwnerFreezeAlwaysAllowedToProtected(to, s.alwaysAllowedTos[to]);
        }

        delete s.alwaysAllowedTos[to];
        emit OwnerFreezeAlwaysAllowedTo(owner(), to, 0, 0);
    }

    /// Check if the contract is frozen. If it is, revert if the `from` or
    /// `to` addresses are not in their respective always allowed lists.
    /// @param from The address that tokens are being sent from.
    /// @param to The address that tokens are being sent to.
    function ownerFreezeCheckTransaction(address from, address to) internal view {
        OwnerFreezableV17201Storage storage s = getStorageOwnerFreezable();

        // We either simply revert or no-op for this check.
        // Revert if the contract is frozen and neither the `from` nor `to` are
        // in their respective always allowed lists.
        // Inclusive boundary: the freeze is active through and including
        // `ownerFrozenUntil`. Matches the convention used by
        // `OffchainAssetReceiptVault.certifiedUntil`.
        if (block.timestamp <= s.ownerFrozenUntil && s.alwaysAllowedFroms[from] == 0 && s.alwaysAllowedTos[to] == 0) {
            revert IOwnerFreezableV1.OwnerFrozen(s.ownerFrozenUntil, from, to);
        }
    }
}
