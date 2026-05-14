// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {PriceOracleV2} from "src/abstract/PriceOracleV2.sol";
import {Test} from "forge-std-1.16.1/src/Test.sol";

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

contract PriceOracleV2Test is Test {
    address constant ALICE = address(uint160(uint256(keccak256("ALICE"))));

    function testPriceOracleV2(uint256 priceA, uint256 priceB) external {
        PriceOracleV2TestImpl oracle = new PriceOracleV2TestImpl(priceA);

        vm.prank(ALICE);
        assertEq(oracle.price(), priceA);

        oracle.setPrice(priceB);

        vm.prank(ALICE);
        assertEq(oracle.price(), priceB);
    }

    function testPriceOracleV2Refund(uint256 priceA) external {
        PriceOracleV2TestImpl oracle = new PriceOracleV2TestImpl(priceA);

        vm.deal(ALICE, 1e18);
        vm.prank(ALICE);
        assertEq(oracle.price{value: 1e18}(), priceA);
        assertEq(ALICE.balance, 1e18);
    }
}
