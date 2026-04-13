// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {PriceOracleV2} from "../../abstract/PriceOracleV2.sol";
import {IPyth} from "pyth-sdk/IPyth.sol";
import {PythStructs} from "pyth-sdk/PythStructs.sol";
import {LibDecimalFloat, Float} from "rain.math.float/lib/LibDecimalFloat.sol";

error NonPositivePrice(int256 price);

struct PythOracleConfig {
    bytes32 priceFeedId;
    uint256 staleAfter;
    IPyth pythContract;
}

contract PythOracle is PriceOracleV2 {
    event Construction(address sender, PythOracleConfig config);

    bytes32 public immutable iPriceFeedId;
    uint256 public immutable iStaleAfter;
    IPyth public immutable iPythContract;

    constructor(PythOracleConfig memory config) {
        iPriceFeedId = config.priceFeedId;
        iStaleAfter = config.staleAfter;
        iPythContract = config.pythContract;

        emit Construction(msg.sender, config);
    }

    function _price() internal virtual override returns (uint256) {
        // Slither false positive, confidence is checked here.
        // slither-disable-next-line pyth-unchecked-confidence
        PythStructs.Price memory priceData = iPythContract.getPriceNoOlderThan(iPriceFeedId, iStaleAfter);
        int256 conservativePrice = int256(priceData.price) - int256(uint256(priceData.conf));
        if (conservativePrice <= 0) {
            revert NonPositivePrice(conservativePrice);
        }
        // It is safe to pack lossless here because the price data uses only
        // 64 bits while we have 224 bits for a packed signed coefficient, and
        // the exponent bit size is the same for both.
        Float conservativePriceFloat = LibDecimalFloat.packLossless(conservativePrice, priceData.expo);
        // We ignore precision loss here, truncating towards zero.
        //slither-disable-next-line unused-return
        (uint256 price18,) = LibDecimalFloat.toFixedDecimalLossy(conservativePriceFloat, 18);
        return price18;
    }
}
