// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {PythOracle, PythOracleConfig, NonPositivePrice} from "src/concrete/oracle/PythOracle.sol";
import {IPythOracleV2} from "src/interface/IPythOracleV2.sol";
import {IPyth} from "pyth-sdk/IPyth.sol";
import {PythStructs} from "pyth-sdk/PythStructs.sol";

contract PythOracleTest is Test {
    receive() external payable {}

    address constant MOCK_PYTH = address(uint160(uint256(keccak256("MOCK_PYTH"))));
    bytes32 constant FEED_ID = bytes32(uint256(1));
    uint256 constant STALE_AFTER = 60;

    function buildOracle() internal returns (PythOracle) {
        vm.etch(MOCK_PYTH, hex"00");
        return new PythOracle(
            PythOracleConfig({priceFeedId: FEED_ID, staleAfter: STALE_AFTER, pythContract: IPyth(MOCK_PYTH)})
        );
    }

    function mockPrice(int64 price, uint64 conf, int32 expo) internal {
        PythStructs.Price memory priceData =
            PythStructs.Price({price: price, conf: conf, expo: expo, publishTime: block.timestamp});
        vm.mockCall(
            MOCK_PYTH,
            abi.encodeWithSelector(IPyth.getPriceNoOlderThan.selector, FEED_ID, STALE_AFTER),
            abi.encode(priceData)
        );
    }

    /// A normal price with zero confidence returns the price as 18-decimal.
    function testPriceNormalZeroConf() external {
        PythOracle oracle = buildOracle();
        // price = 100, conf = 0, expo = -2 => 1.00 => 1e18
        mockPrice(100, 0, -2);
        assertEq(oracle.price(), 1e18);
    }

    /// Confidence is subtracted from price for a conservative estimate.
    function testPriceSubtractsConfidence() external {
        PythOracle oracle = buildOracle();
        // price = 1000, conf = 50, expo = -3 => (1000 - 50) * 1e-3 = 0.95 => 0.95e18
        mockPrice(1000, 50, -3);
        assertEq(oracle.price(), 0.95e18);
    }

    /// Reverts when confidence >= price (conservative price <= 0).
    function testRevertsNonPositivePrice() external {
        PythOracle oracle = buildOracle();
        // price = 100, conf = 100, expo = -2 => conservative = 0
        mockPrice(100, 100, -2);
        vm.expectRevert(abi.encodeWithSelector(NonPositivePrice.selector, int256(0)));
        oracle.price();
    }

    /// Reverts when confidence exceeds price (conservative price < 0).
    function testRevertsNegativeConservativePrice() external {
        PythOracle oracle = buildOracle();
        // price = 50, conf = 100, expo = -2 => conservative = -50
        mockPrice(50, 100, -2);
        vm.expectRevert(abi.encodeWithSelector(NonPositivePrice.selector, int256(-50)));
        oracle.price();
    }

    /// Positive exponent scales up correctly.
    function testPricePositiveExponent() external {
        PythOracle oracle = buildOracle();
        // price = 5, conf = 0, expo = 2 => 500 => 500e18
        mockPrice(5, 0, 2);
        assertEq(oracle.price(), 500e18);
    }

    /// Large price with negative exponent.
    function testPriceLargeWithNegativeExponent() external {
        PythOracle oracle = buildOracle();
        // price = 350000, conf = 0, expo = -2 => 3500.00 => 3500e18
        mockPrice(350000, 0, -2);
        assertEq(oracle.price(), 3500e18);
    }

    /// Construction emits event and sets immutables.
    function testConstruction() external {
        PythOracle oracle = buildOracle();
        IPythOracleV2 iOracle = IPythOracleV2(address(oracle));
        assertEq(iOracle.iPriceFeedId(), FEED_ID);
        assertEq(iOracle.iStaleAfter(), STALE_AFTER);
        assertEq(address(iOracle.iPythContract()), MOCK_PYTH);
    }
}
