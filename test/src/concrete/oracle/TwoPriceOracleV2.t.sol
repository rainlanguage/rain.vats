// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {TwoPriceOracleConfigV2, IPriceOracleV2, TwoPriceOracleV2} from "src/concrete/oracle/TwoPriceOracleV2.sol";
import {ErrTwoPriceOracleV2SameQuoteBase} from "src/error/ErrTwoPriceOracleV2.sol";

contract TwoPriceOracleTest is Test {
    /// A zero address for the base errors construction.
    function testZeroAddressBase(address quote) public {
        vm.assume(quote != address(0));
        TwoPriceOracleConfigV2 memory config =
            TwoPriceOracleConfigV2({base: IPriceOracleV2(payable(0)), quote: IPriceOracleV2(payable(quote))});

        vm.expectRevert();
        new TwoPriceOracleV2(config);
    }

    /// A zero address for the quote errors construction.
    function testZeroAddressQuote(address base) public {
        vm.assume(base != address(0));
        TwoPriceOracleConfigV2 memory config =
            TwoPriceOracleConfigV2({base: IPriceOracleV2(payable(base)), quote: IPriceOracleV2(payable(0))});

        vm.expectRevert();
        new TwoPriceOracleV2(config);
    }

    /// A zero address for both base and quote errors construction.
    function testZeroAddressBoth() public {
        TwoPriceOracleConfigV2 memory config =
            TwoPriceOracleConfigV2({base: IPriceOracleV2(payable(0)), quote: IPriceOracleV2(payable(0))});

        vm.expectRevert();
        new TwoPriceOracleV2(config);
    }

    /// Addresses that are not oracles error construction.
    function testNotOracle(address base, address quote) public {
        vm.assume(base != address(0));
        vm.assume(quote != address(0));
        TwoPriceOracleConfigV2 memory config =
            TwoPriceOracleConfigV2({base: IPriceOracleV2(payable(base)), quote: IPriceOracleV2(payable(quote))});

        vm.expectRevert();
        new TwoPriceOracleV2(config);
    }

    /// Identical base and quote addresses error construction.
    function testSameBaseQuote(address base) public {
        vm.assume(base != address(0));
        TwoPriceOracleConfigV2 memory config =
            TwoPriceOracleConfigV2({base: IPriceOracleV2(payable(base)), quote: IPriceOracleV2(payable(base))});

        vm.expectRevert(abi.encodeWithSelector(ErrTwoPriceOracleV2SameQuoteBase.selector, base));
        new TwoPriceOracleV2(config);
    }

    /// Oracle like contracts will allow construction.
    function testOracleConstructs(address base, uint256 basePrice, address quote, uint256 quotePrice) public {
        vm.assume(base != address(0));
        vm.assume(quote != address(0));
        vm.assume(base != quote);
        base = address(uint160(uint256(keccak256(abi.encodePacked(base)))));
        quote = address(uint160(uint256(keccak256(abi.encodePacked(quote)))));

        basePrice = bound(basePrice, 0, uint256(type(uint128).max));
        quotePrice = bound(quotePrice, 1, uint256(type(uint128).max));

        TwoPriceOracleConfigV2 memory config =
            TwoPriceOracleConfigV2({base: IPriceOracleV2(payable(base)), quote: IPriceOracleV2(payable(quote))});

        vm.mockCall(base, abi.encodeWithSelector(IPriceOracleV2.price.selector), abi.encode(basePrice));
        vm.mockCall(quote, abi.encodeWithSelector(IPriceOracleV2.price.selector), abi.encode(quotePrice));

        new TwoPriceOracleV2(config);
    }
}
