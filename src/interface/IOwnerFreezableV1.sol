// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IERC5313} from "@openzeppelin-contracts-5.6.1/interfaces/IERC5313.sol";

/// @title IOwnerFreezableV1
/// @notice Interface for the OwnerFreezable contract.
interface IOwnerFreezableV1 is IERC5313 {
    /// Thrown when the owner attempts to remove a `from` address from the always
    /// allowed list while it is still protected.
    /// @param from The address that is always allowed to send.
    /// @param protectedUntil The timestamp until the `from` address is unable to
    /// be removed from the always allowed list.
    error OwnerFreezeAlwaysAllowedFromProtected(address from, uint256 protectedUntil);

    /// Thrown when the owner attempts to add a `from` address to the always allowed
    /// list with a zero protected time.
    /// @param from The address that is always allowed to send.
    error OwnerFreezeAlwaysAllowedFromZero(address from);

    /// Thrown when the owner attempts to add a `to` address to the always allowed
    /// list with a zero protected time.
    /// @param to The address that is always allowed to receive.
    error OwnerFreezeAlwaysAllowedToZero(address to);

    /// Thrown when the owner attempts to remove a `to` address from the always
    /// allowed list while it is still protected.
    /// @param to The address that is always allowed to receive.
    /// @param protectedUntil The timestamp until the `to` address is unable to
    /// be removed from the always allowed list.
    error OwnerFreezeAlwaysAllowedToProtected(address to, uint256 protectedUntil);

    /// Thrown when a transfer is attempted when the contract is frozen.
    /// @param freezeUntil The timestamp until when the contract is frozen.
    /// @param from The address that tokens are being sent from.
    /// @param to The address that tokens are being sent to.
    error OwnerFrozen(uint256 freezeUntil, address from, address to);

    /// Owner froze the contract until the given timestamp.
    /// @param owner The address of the owner.
    /// @param targetTimestamp The timestamp requested by the owner.
    /// @param actualTimestamp The actual time the contract is frozen until. Will be greater
    /// than or equal to the target time.
    event OwnerFrozenUntil(address owner, uint256 targetTimestamp, uint256 actualTimestamp);

    /// Owner added a `from` address to the always allowed list.
    /// @param owner The address of the owner.
    /// @param from The address that is always allowed to send.
    /// @param targetProtectedUntil The timestamp the owner attempted to protect
    /// the `from` until. Can be less than the actual protection if a previous
    /// call already set it higher.
    /// @param protectedUntil The timestamp until the `from` address is unable to
    /// be removed from the always allowed list.
    event OwnerFreezeAlwaysAllowedFrom(
        address owner, address from, uint256 targetProtectedUntil, uint256 protectedUntil
    );

    /// Owner added a `to` address to the always allowed list.
    /// @param owner The address of the owner.
    /// @param to The address that is always allowed to receive.
    /// @param targetProtectedUntil The timestamp the owner attempted to protect
    /// the `to` until. Can be less than the actual protection if a previous
    /// call already set it higher.
    /// @param protectedUntil The timestamp until the `to` address is unable to
    /// be removed from the always allowed list.
    event OwnerFreezeAlwaysAllowedTo(address owner, address to, uint256 targetProtectedUntil, uint256 protectedUntil);

    /// Returns the timestamp until when the contract is frozen.
    /// @return The timestamp until when the contract is frozen.
    function ownerFrozenUntil() external view returns (uint256);

    /// The owner can freeze the contract until a given timestamp. The owner
    /// cannot reverse this freeze, although they can extend it by calling this
    /// function again with a later timestamp.
    /// @param freezeUntil The timestamp until when the contract is frozen.
    function ownerFreezeUntil(uint256 freezeUntil) external;

    /// If the `from` address is always allowed to send tokens a non-zero
    /// timestamp is returned. The timestamp represents the time until when
    /// the `from` address is unable to be removed from the always allowed list.
    /// After this time the `from` address is still always allowed to send
    /// tokens, but the owner can remove it from the always allowed list.
    /// @param from The address that is always allowed to send.
    /// @return protectedUntil The timestamp until the `from` address is unable
    /// to be removed from the always allowed list.
    function ownerFreezeAlwaysAllowedFrom(address from) external view returns (uint256 protectedUntil);

    /// The owner can add a `from` address to the always allowed list. The
    /// owner cannot remove this address from the always allowed list until
    /// the current time is greater than the protected time. The owner can
    /// extend the protected time by calling this function again with a later
    /// timestamp.
    /// @param from The address that is always allowed to send.
    /// @param protectUntil The timestamp until the `from` address is unable to
    /// be removed from the always allowed list.
    function ownerFreezeAlwaysAllowFrom(address from, uint256 protectUntil) external;

    /// The owner can remove a `from` address from the always allowed list,
    /// provided the current time is greater than the protected time.
    /// @param from The address that is always allowed to send.
    function ownerFreezeStopAlwaysAllowingFrom(address from) external;

    /// If the `to` address is always allowed to receive tokens a non-zero
    /// timestamp is returned. The timestamp represents the time until when
    /// the `to` address is unable to be removed from the always allowed list.
    /// After this time the `to` address is still always allowed to receive
    /// tokens, but the owner can remove it from the always allowed list.
    /// @param to The address that is always allowed to receive.
    /// @return protectedUntil The timestamp until the `to` address is unable
    /// to be removed from the always allowed list.
    function ownerFreezeAlwaysAllowedTo(address to) external view returns (uint256 protectedUntil);

    /// The owner can add a `to` address to the always allowed list. The
    /// owner cannot remove this address from the always allowed list until
    /// the current time is greater than the protected time. The owner can
    /// extend the protected time by calling this function again with a later
    /// timestamp.
    /// @param to The address that is always allowed to receive.
    /// @param protectUntil The timestamp until the `to` address is unable to
    /// be removed from the always allowed list.
    function ownerFreezeAlwaysAllowTo(address to, uint256 protectUntil) external;

    /// The owner can remove a `to` address from the always allowed list,
    /// provided the current time is greater than the protected time.
    /// @param to The address that is always allowed to receive.
    function ownerFreezeStopAlwaysAllowingTo(address to) external;
}
