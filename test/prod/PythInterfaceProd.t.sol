// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {IPyth} from "../../src/vendor/pyth-sdk/IPyth.sol";
import {PythStructs} from "../../src/vendor/pyth-sdk/PythStructs.sol";

/// @title PythInterfaceProdTest
/// @notice Exercises the IPyth method this repo calls against the live Pyth
/// deployment on Arbitrum (Pyth isn't on Flare). If the upstream Pyth
/// contract changes its method signature, the test fails — pinning the
/// vendored IPyth.sol copy to the on-chain ABI.
contract PythInterfaceProdTest is Test {
    /// @dev Pyth's deployment on Arbitrum One. Pyth ships at the same
    /// address on most chains but the canonical reference for this test
    /// is the Pyth docs:
    /// https://docs.pyth.network/price-feeds/contract-addresses/evm
    IPyth constant PYTH = IPyth(0xff1a0f4744e8582DF1aE09D5611b887B6a12925C);

    /// @dev BTC/USD price feed ID (Pyth canonical feed).
    bytes32 constant BTC_USD_FEED_ID = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;

    /// @dev Generous staleness window so the test is robust across pinned fork
    /// blocks; the only thing under test is that the call returns plausible
    /// values, not that the price is fresh.
    uint256 constant STALE_AFTER = 1 hours;

    /// IPyth.getPriceNoOlderThan — the only IPyth method this repo invokes,
    /// via PythOracle.price().
    function testPythGetPriceNoOlderThan() external {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));
        PythStructs.Price memory p = PYTH.getPriceNoOlderThan(BTC_USD_FEED_ID, STALE_AFTER);
        assertTrue(p.price > 0, "BTC price is non-positive");
        assertTrue(p.conf > 0, "BTC confidence is zero");
        assertTrue(p.publishTime > 0, "BTC publishTime is zero");
        // Pyth USD feeds use expo = -8 (8 decimals after the point).
        assertEq(p.expo, -8, "unexpected BTC expo");
    }
}
