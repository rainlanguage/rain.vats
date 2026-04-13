// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.0;

import {IPyth} from "pyth-sdk/IPyth.sol";

/// @title IPythOracleV1
/// @notice V1 interface for PythOracle. Uses the original I_ naming
/// convention. Deployed contracts on-chain have this ABI.
interface IPythOracleV1 {
    // Matches deployed on-chain ABI.
    //slither-disable-next-line naming-convention
    function I_PRICE_FEED_ID() external view returns (bytes32);
    // Matches deployed on-chain ABI.
    //slither-disable-next-line naming-convention
    function I_STALE_AFTER() external view returns (uint256);
    // Matches deployed on-chain ABI.
    //slither-disable-next-line naming-convention
    function I_PYTH_CONTRACT() external view returns (IPyth);
}
