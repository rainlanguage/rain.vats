// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {PriceOracleV2} from "src/abstract/PriceOracleV2.sol";

contract PriceOracleV2TestImpl is PriceOracleV2 {
    uint256 internal sPrice;

    constructor(uint256 price) {
        sPrice = price;
    }

    function _price() internal view override returns (uint256) {
        return sPrice;
    }

    function setPrice(uint256 price) external {
        sPrice = price;
    }
}
