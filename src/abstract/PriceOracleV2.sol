// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IPriceOracleV2} from "../interface/IPriceOracleV2.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

abstract contract PriceOracleV2 is IPriceOracleV2 {
    /// Hook for implementing contracts to define their own price logic.
    function _price() internal virtual returns (uint256);

    /// @inheritdoc IPriceOracleV2
    function price() external payable override returns (uint256) {
        uint256 val = _price();
        Address.sendValue(payable(msg.sender), address(this).balance);
        return val;
    }

    /// Need to accept refunds from the oracle.
    fallback() external payable virtual {}

    /// Need to accept refunds from the oracle.
    receive() external payable virtual {}
}
