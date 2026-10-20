// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// A beacon that implements `IBeacon.implementation` and nothing else, so it
/// has no `owner`.
contract OwnerlessBeacon {
    address internal immutable iImplementation;

    constructor(address implementation_) {
        iImplementation = implementation_;
    }

    function implementation() external view returns (address) {
        return iImplementation;
    }
}
