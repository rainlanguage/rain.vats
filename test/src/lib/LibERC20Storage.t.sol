// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {TestERC20} from "./TestERC20.sol";

/// @dev Regression / drift-detection tests for `LibERC20Storage`. The library
/// reads and writes OZ `ERC20Upgradeable` storage at hardcoded ERC-7201 slot
/// offsets (`_balances` at +0, `_totalSupply` at +2). If a future
/// `forge soldeer update` of `openzeppelin-contracts-upgradeable` reorders the
/// struct or moves the namespace, every assertion in this file diverges.
contract LibERC20StorageTest is Test {
    TestERC20 internal token;

    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);

    function setUp() public {
        token = new TestERC20();
    }

    /// LibERC20Storage.underlyingBalance reads the same value as ERC20Upgradeable.balanceOf.
    function testGetBalanceMatchesOzBalanceOf() external {
        token.mint(ALICE, 1234);
        assertEq(token.libBalanceOf(ALICE), token.balanceOf(ALICE));
        assertEq(token.libBalanceOf(BOB), 0);
        assertEq(token.balanceOf(BOB), 0);
    }

    /// LibERC20Storage.underlyingTotalSupply reads the same value as ERC20Upgradeable.totalSupply.
    function testGetTotalSupplyMatchesOzTotalSupply() external {
        token.mint(ALICE, 1000);
        token.mint(BOB, 500);
        assertEq(token.libTotalSupply(), token.totalSupply());
        assertEq(token.libTotalSupply(), 1500);
    }

    /// LibERC20Storage.setUnderlyingBalance writes a value that ERC20Upgradeable.balanceOf observes.
    function testSetBalanceVisibleToOzBalanceOf() external {
        token.mint(ALICE, 100);
        token.libSetBalance(ALICE, 999);
        assertEq(token.balanceOf(ALICE), 999, "OZ balanceOf must reflect the direct write");
    }

    /// Round trip: write via OZ, read via Lib, write via Lib, read via OZ —
    /// at every step the two views agree.
    function testFuzzRoundTrip(uint128 mintAmount, uint128 directWrite) external {
        token.mint(ALICE, uint256(mintAmount));
        assertEq(token.libBalanceOf(ALICE), token.balanceOf(ALICE));

        token.libSetBalance(ALICE, uint256(directWrite));
        assertEq(token.balanceOf(ALICE), uint256(directWrite));
        assertEq(token.libBalanceOf(ALICE), uint256(directWrite));
    }

    /// Multiple accounts: each account's slot is correctly keyed by address.
    function testMultipleAccountsIndependentSlots() external {
        token.mint(ALICE, 100);
        token.mint(BOB, 200);

        assertEq(token.libBalanceOf(ALICE), 100);
        assertEq(token.libBalanceOf(BOB), 200);

        token.libSetBalance(ALICE, 555);
        assertEq(token.balanceOf(ALICE), 555, "Alice's slot updated");
        assertEq(token.balanceOf(BOB), 200, "Bob's slot untouched");
    }

    /// Burning via OZ updates both balanceOf and totalSupply, observable via Lib.
    function testBurnObservedByLib() external {
        token.mint(ALICE, 1000);
        token.burn(ALICE, 300);
        assertEq(token.libBalanceOf(ALICE), 700);
        assertEq(token.libTotalSupply(), 700);
    }

    /// Fuzz: randomized account address and balance — Lib read matches OZ read
    /// after mint.
    function testFuzzRandomAccountBalance(address account, uint128 amount) external {
        vm.assume(account != address(0));
        token.mint(account, uint256(amount));
        assertEq(token.libBalanceOf(account), token.balanceOf(account), "Lib must match OZ after mint");
        assertEq(token.libBalanceOf(account), uint256(amount));
    }

    /// Fuzz: randomized setBalance followed by OZ read.
    function testFuzzRandomSetBalance(address account, uint128 mintAmount, uint256 newBalance) external {
        vm.assume(account != address(0));
        token.mint(account, uint256(mintAmount));
        token.libSetBalance(account, newBalance);
        assertEq(token.balanceOf(account), newBalance, "OZ must reflect Lib write");
        assertEq(token.libBalanceOf(account), newBalance, "Lib read must match Lib write");
    }

    /// Fuzz: two randomized accounts — writing to one never affects the other.
    function testFuzzTwoAccountSlotIsolation(address a, address b, uint128 amountA, uint128 amountB, uint256 writeA)
        external
    {
        vm.assume(a != address(0) && b != address(0) && a != b);
        token.mint(a, uint256(amountA));
        token.mint(b, uint256(amountB));
        token.libSetBalance(a, writeA);
        assertEq(token.balanceOf(a), writeA, "account a updated");
        assertEq(token.balanceOf(b), uint256(amountB), "account b untouched");
        assertEq(token.libBalanceOf(b), uint256(amountB), "Lib read of b untouched");
    }

    /// LibERC20Storage.setUnderlyingTotalSupply writes a value that
    /// ERC20Upgradeable.totalSupply observes. Pins the `+2` offset in the write
    /// direction — `underlyingTotalSupply` alone only pins it for reads.
    function testSetTotalSupplyVisibleToOzTotalSupply() external {
        token.mint(ALICE, 100);
        token.libSetTotalSupply(999);
        assertEq(token.totalSupply(), 999, "OZ totalSupply must reflect the direct write");
        assertEq(token.libTotalSupply(), 999, "Lib read must match Lib write");
    }

    /// Writing `_totalSupply` must not disturb any `_balances` slot — i.e. the
    /// `+2` offset really is a distinct slot from the balances mapping base.
    function testSetTotalSupplyLeavesBalancesUntouched() external {
        token.mint(ALICE, 100);
        token.mint(BOB, 200);
        token.libSetTotalSupply(12345);
        assertEq(token.balanceOf(ALICE), 100, "Alice's balance untouched");
        assertEq(token.balanceOf(BOB), 200, "Bob's balance untouched");
        assertEq(token.totalSupply(), 12345, "only totalSupply moved");
    }

    /// Round trip: write via OZ, read via Lib, write via Lib, read via OZ.
    function testFuzzTotalSupplyRoundTrip(uint128 mintAmount, uint256 directWrite) external {
        token.mint(ALICE, uint256(mintAmount));
        assertEq(token.libTotalSupply(), token.totalSupply());

        token.libSetTotalSupply(directWrite);
        assertEq(token.totalSupply(), directWrite, "OZ must reflect Lib write");
        assertEq(token.libTotalSupply(), directWrite, "Lib read must match Lib write");
    }

    /// Fuzz: totalSupply reflects multiple mints across randomized accounts.
    function testFuzzTotalSupplyMultipleAccounts(address a, address b, uint64 amountA, uint64 amountB) external {
        vm.assume(a != address(0) && b != address(0));
        token.mint(a, uint256(amountA));
        token.mint(b, uint256(amountB));
        assertEq(token.libTotalSupply(), token.totalSupply(), "Lib totalSupply must match OZ");
        assertEq(token.libTotalSupply(), uint256(amountA) + uint256(amountB));
    }
}
