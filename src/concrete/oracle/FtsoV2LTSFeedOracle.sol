// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {PriceOracleV2} from "../../abstract/PriceOracleV2.sol";
import {LibFtsoV2LTS} from "rain.flare/lib/lts/LibFtsoV2LTS.sol";

//forge-lint: disable-next-line(pascal-case-struct)
struct FtsoV2LTSFeedOracleConfig {
    bytes21 feedId;
    uint256 staleAfter;
}

contract FtsoV2LTSFeedOracle is PriceOracleV2 {
    event Construction(address sender, FtsoV2LTSFeedOracleConfig config);

    bytes21 public immutable iFeedId;
    uint256 public immutable iStaleAfter;

    constructor(FtsoV2LTSFeedOracleConfig memory config) {
        iFeedId = config.feedId;
        iStaleAfter = config.staleAfter;

        emit Construction(msg.sender, config);
    }

    /// @inheritdoc PriceOracleV2
    function _price() internal virtual override returns (uint256) {
        return LibFtsoV2LTS.ftsoV2LTSGetFeed(iFeedId, iStaleAfter);
    }
}
