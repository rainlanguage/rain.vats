// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IAuthorizeV1} from "./IAuthorizeV1.sol";

/// @title IAuthorizableV1
/// @notice Read-only interface for any contract that delegates its
/// permission checks to an `IAuthorizeV1` contract and exposes the
/// current authorizer through a getter. The consumer side of the
/// `IAuthorizeV1` pattern; useful for off-chain tooling, integrators,
/// and tests that need to identify or pin a contract's current
/// authorizer without importing the concrete implementation.
interface IAuthorizableV1 {
    /// @return The current `IAuthorizeV1` authorizer.
    function authorizer() external view returns (IAuthorizeV1);
}
