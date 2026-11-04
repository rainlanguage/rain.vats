// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, stdError} from "forge-std-1.17.0/src/Test.sol";
import {TestERC20} from "./TestERC20.sol";

contract LibERC20StorageApplyBalanceDeltaToTotalSupplyTest is Test {
    TestERC20 internal token;

    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);

    function setUp() public {
        token = new TestERC20();
    }

    function testFuzzBalanceRewriteWithDeltaKeepsOzTotalSupplyEqualToBalanceSum(
        uint128 aliceMint,
        uint128 bobMint,
        uint128 aliceNew
    ) external {
        token.mint(ALICE, aliceMint);
        token.mint(BOB, bobMint);

        token.libSetBalance(ALICE, aliceNew);
        token.libApplyBalanceDeltaToTotalSupply(aliceMint, aliceNew);

        assertEq(token.totalSupply(), token.balanceOf(ALICE) + token.balanceOf(BOB));
        assertEq(token.balanceOf(ALICE), uint256(aliceNew));
        assertEq(token.balanceOf(BOB), uint256(bobMint));
    }

    /// A stale `_totalSupply` would wrap on the burns below and then make
    /// the re-mint revert.
    function testFuzzBalanceRewriteWithDeltaLetsOzBurnEverythingAndMintAgain(
        uint128 aliceMint,
        uint128 bobMint,
        uint128 aliceNew,
        uint128 remint
    ) external {
        token.mint(ALICE, aliceMint);
        token.mint(BOB, bobMint);

        token.libSetBalance(ALICE, aliceNew);
        token.libApplyBalanceDeltaToTotalSupply(aliceMint, aliceNew);

        token.burn(ALICE, aliceNew);
        token.burn(BOB, bobMint);
        assertEq(token.totalSupply(), 0);

        token.mint(ALICE, remint);
        assertEq(token.totalSupply(), uint256(remint));
    }

    function testFuzzTotalSupplyBecomesSupplyPlusNewMinusOld(uint256 supply, uint256 oldBalance, uint256 newBalance)
        external
    {
        newBalance = bound(newBalance, 0, type(uint256).max - supply);
        oldBalance = bound(oldBalance, 0, supply + newBalance);
        token.libSetTotalSupply(supply);

        token.libApplyBalanceDeltaToTotalSupply(oldBalance, newBalance);

        assertEq(token.totalSupply(), supply + newBalance - oldBalance);
    }

    function testFuzzBalancesUntouched(uint128 aliceMint, uint128 bobMint, uint128 oldBalance, uint128 newBalance)
        external
    {
        vm.assume(oldBalance <= uint256(aliceMint) + uint256(bobMint) + uint256(newBalance));
        token.mint(ALICE, aliceMint);
        token.mint(BOB, bobMint);

        token.libApplyBalanceDeltaToTotalSupply(oldBalance, newBalance);

        assertEq(token.balanceOf(ALICE), uint256(aliceMint));
        assertEq(token.balanceOf(BOB), uint256(bobMint));
    }

    function testFuzzRevertsWhenNewTotalSupplyOverflows(uint256 supply, uint256 oldBalance, uint256 newBalance)
        external
    {
        supply = bound(supply, 1, type(uint256).max);
        oldBalance = bound(oldBalance, 0, supply - 1);
        newBalance = bound(newBalance, type(uint256).max - (supply - oldBalance) + 1, type(uint256).max);
        token.libSetTotalSupply(supply);

        vm.expectRevert(stdError.arithmeticError);
        token.libApplyBalanceDeltaToTotalSupply(oldBalance, newBalance);
    }

    function testFuzzRevertsWhenOldBalanceExceedsSupplyPlusNewBalance(
        uint256 supply,
        uint256 oldBalance,
        uint256 newBalance
    ) external {
        supply = bound(supply, 0, type(uint256).max - 1);
        newBalance = bound(newBalance, 0, type(uint256).max - 1 - supply);
        oldBalance = bound(oldBalance, supply + newBalance + 1, type(uint256).max);
        token.libSetTotalSupply(supply);

        vm.expectRevert(stdError.arithmeticError);
        token.libApplyBalanceDeltaToTotalSupply(oldBalance, newBalance);
    }
}
