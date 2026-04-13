// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.0;

import {IPyth} from "pyth-sdk/IPyth.sol";

/// @title IPythOracleV2
/// @notice V2 interface for PythOracle. Uses camelCase i prefix. New
/// deployments use this ABI.
interface IPythOracleV2 {
    function iPriceFeedId() external view returns (bytes32);
    function iStaleAfter() external view returns (uint256);
    function iPythContract() external view returns (IPyth);
}
