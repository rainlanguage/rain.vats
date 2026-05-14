// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain-math-fixedpoint-0.2.0/src/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {PriceOracleV2, IPriceOracleV2} from "../../abstract/PriceOracleV2.sol";
import {ErrTwoPriceOracleV2SameQuoteBase} from "../../error/ErrTwoPriceOracleV2.sol";

/// Construction config for `TwoPriceOracle`.
/// @param base The base price of the merged pair, will be the numerator.
/// @param quote The quote price of the merged pair, will be the denominator.
struct TwoPriceOracleConfigV2 {
    IPriceOracleV2 base;
    IPriceOracleV2 quote;
}

/// @title TwoPriceOracle
/// Any time we have two price feeds that share a denominator we can derive the
/// price of the numerators by dividing the two ratios. We leverage the fixed
/// point 18 decimal normalisation from `IPriceOracleV2.price` to simplify this
/// logic to a single `fixedPointDiv` call here.
///
/// For example, an ETH/USD (base) and an XAU/USD (quote) price can be combined
/// to a single ETH/XAU price as (ETH/USD) / (XAU/USD).
contract TwoPriceOracleV2 is PriceOracleV2 {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Emitted upon deployment and construction.
    event Construction(address sender, TwoPriceOracleConfigV2 config);

    /// As per `ConstructionConfig.base`.
    //slither-disable-next-line naming-convention
    IPriceOracleV2 public immutable BASE;
    /// As per `ConstructionConfig.quote`.
    //slither-disable-next-line naming-convention
    IPriceOracleV2 public immutable QUOTE;

    /// @param config Config required to construct.
    constructor(TwoPriceOracleConfigV2 memory config) {
        if (config.base == config.quote) {
            revert ErrTwoPriceOracleV2SameQuoteBase(address(config.base));
        }

        BASE = IPriceOracleV2(config.base);
        QUOTE = IPriceOracleV2(config.quote);
        emit Construction(msg.sender, config);

        // Dry run the price to flush out any trivial issues with the oracles
        // that cause errors, such as a zero address or corrupted oracle.
        // This is not a perfect test, as an arbitrary contract MAY return a
        // value for `price` that is not valid according to the `IPriceOracleV2`
        // interface, but it should flush out most basic configuration mistakes.
        uint256 dryRunPrice = _price();
        (dryRunPrice);
    }

    /// Calculates the price as `base / quote` using fixed point 18 decimal math.
    /// Round UP to avoid edge cases that could return `0` which is disallowed
    /// by `IPriceOracleV2` despite compliant sub-oracles.
    /// @inheritdoc PriceOracleV2
    function _price() internal virtual override returns (uint256) {
        // This contract is never intended to hold gas, it's only here to pay the
        // oracles that might need to be paid.
        // This means the slither detector here is a false positive.
        //slither-disable-next-line arbitrary-send-eth
        uint256 quotePrice = QUOTE.price{value: address(this).balance}();
        //slither-disable-next-line arbitrary-send-eth
        uint256 basePrice = BASE.price{value: address(this).balance}();
        return basePrice.fixedPointDiv(quotePrice, Math.Rounding.Ceil);
    }
}
