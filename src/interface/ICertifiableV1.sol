// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @title ICertifiableV1
/// @notice Read-only interface for any contract whose operation is gated
/// on a `certifiedUntil` timestamp set by an offchain certifier and
/// expiring without renewal. The consumer side: useful for off-chain
/// tooling, integrators, and tests that need to assert a contract is
/// currently within its certification window without importing the
/// concrete implementation.
interface ICertifiableV1 {
    /// @return True when the current block timestamp is past the
    /// contract's `certifiedUntil` time.
    function isCertificationExpired() external view returns (bool);
}
