// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OracleTest} from "test/abstract/OracleTest.sol";
import {FtsoV2LTSFeedOracle, FtsoV2LTSFeedOracleConfig} from "src/concrete/oracle/FtsoV2LTSFeedOracle.sol";
import {FLR_USD_FEED_ID} from "rain-flare-0.1.2/src/lib/lts/LibFtsoV2LTS.sol";
import {StalePrice} from "rain-flare-0.1.2/src/err/ErrFtso.sol";
import {IFeeCalculator} from "rain-flare-0.1.2/src/vendor/flare-smart-contracts-v2/userInterfaces/IFeeCalculator.sol";
import {LibFlareContractRegistry} from "rain-flare-0.1.2/src/lib/registry/LibFlareContractRegistry.sol";
import {IGoverned, IGovernanceSettings} from "rain-flare-0.1.2/src/interface/IGoverned.sol";
import {IGovernedFeeCalculator} from "rain-flare-0.1.2/src/interface/IGovernedFeeCalculator.sol";

contract FtsoV2LTSFeedOracleTest is OracleTest {
    function testFtsoV2LTSFeedOracle() external {
        FtsoV2LTSFeedOracle oracle =
            new FtsoV2LTSFeedOracle(FtsoV2LTSFeedOracleConfig({feedId: FLR_USD_FEED_ID, staleAfter: 60}));

        vm.prank(ALICE);
        assertEq(oracle.price(), 0.0141082e18);
    }

    function testFtsoV2LTSFeedOracleStale() external {
        FtsoV2LTSFeedOracle oracle =
            new FtsoV2LTSFeedOracle(FtsoV2LTSFeedOracleConfig({feedId: FLR_USD_FEED_ID, staleAfter: 60}));

        uint256 feedTime = 1730042030;

        vm.warp(block.timestamp + 61);
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(StalePrice.selector, feedTime, 60));
        oracle.price();
    }

    /// forge-config: default.fuzz.runs = 1
    function testFtsoV2LTSFeedOraclePaid(uint128 fee) external {
        vm.assume(fee > 0);

        uint256 timelock;
        {
            IFeeCalculator feeCalculator = LibFlareContractRegistry.getFeeCalculator();
            address gov = IGoverned(address(feeCalculator)).governance();
            IGovernanceSettings govSettings = IGoverned(address(feeCalculator)).governanceSettings();
            address[] memory executors = govSettings.getExecutors();
            timelock = govSettings.getTimelock();
            vm.prank(gov);
            bytes21[] memory feeds = new bytes21[](1);
            feeds[0] = bytes21(FLR_USD_FEED_ID);
            uint256[] memory fees = new uint256[](1);
            fees[0] = fee;
            bytes4 setFeedsFeesSelector = bytes4(0x755fcecd);
            IGovernedFeeCalculator(address(feeCalculator)).setFeedsFees(feeds, fees);
            vm.warp(block.timestamp + timelock);
            vm.prank(executors[0]);
            IGoverned(address(feeCalculator)).executeGovernanceCall(setFeedsFeesSelector);
        }

        FtsoV2LTSFeedOracle oracle =
            new FtsoV2LTSFeedOracle(FtsoV2LTSFeedOracleConfig({feedId: FLR_USD_FEED_ID, staleAfter: 60 + timelock}));

        vm.deal(ALICE, fee);
        vm.prank(ALICE);
        assertEq(oracle.price{value: fee}(), 0.0141082e18);
        assertEq(ALICE.balance, 0);

        vm.deal(ALICE, uint256(fee) + 5);
        vm.prank(ALICE);
        assertEq(oracle.price{value: uint256(fee) + 5}(), 0.0141082e18);
        assertEq(ALICE.balance, 5);

        vm.deal(ALICE, fee);
        vm.prank(ALICE);
        // Out of funds here due to insufficient value for fee.
        vm.expectRevert();
        oracle.price{value: fee - 1}();
    }
}
