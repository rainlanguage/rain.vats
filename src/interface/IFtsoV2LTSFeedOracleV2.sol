// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.0;

/// @title IFtsoV2LTSFeedOracleV2
/// @notice V2 interface for FtsoV2LTSFeedOracle. Uses camelCase i prefix.
/// New deployments use this ABI.
interface IFtsoV2LTSFeedOracleV2 {
    function iFeedId() external view returns (bytes21);
    function iStaleAfter() external view returns (uint256);
}
