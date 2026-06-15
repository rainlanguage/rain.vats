// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

/// @title TestReceiptManagerAsset
/// @notice TEST asset contract that exposes a `symbol` and `name` for use as the
/// underlying asset of a `TestReceiptManager`. Intended for use only by the test
/// harness to drive tests.
contract TestReceiptManagerAsset {
    function symbol() external pure returns (string memory) {
        return "TRMAsset";
    }

    function name() external pure returns (string memory) {
        return "TestReceiptManagerAsset";
    }
}
