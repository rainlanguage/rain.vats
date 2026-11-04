// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// A receipt whose `initialize` answers anything but success.
contract FailingInitializeReceipt {
    function initialize(bytes memory) external pure returns (bytes32) {
        return bytes32(0);
    }
}
