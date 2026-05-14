// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {PriceOracleV2} from "../../abstract/PriceOracleV2.sol";
import {LibSceptreStakedFlare} from "rain-flare-0.1.1/src/lib/sflr/LibSceptreStakedFlare.sol";

contract SceptreStakedFlrOracle is PriceOracleV2 {
    /// @inheritdoc PriceOracleV2
    function _price() internal view override returns (uint256) {
        return LibSceptreStakedFlare.getSFLRPerFLR18();
    }
}
