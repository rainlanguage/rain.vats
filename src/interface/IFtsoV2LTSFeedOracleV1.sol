// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.0;

/// @title IFtsoV2LTSFeedOracleV1
/// @notice V1 interface for FtsoV2LTSFeedOracle. Uses the original I_ naming
/// convention. Deployed contracts on-chain have this ABI.
interface IFtsoV2LTSFeedOracleV1 {
    // solhint-disable-next-line func-name-mixedcase
    function I_FEED_ID() external view returns (bytes21);
    // solhint-disable-next-line func-name-mixedcase
    function I_STALE_AFTER() external view returns (uint256);
}
