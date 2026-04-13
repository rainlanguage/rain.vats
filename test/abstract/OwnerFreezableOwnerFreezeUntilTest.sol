// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IOwnerFreezableV1} from "src/abstract/OwnerFreezable.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {
    OwnableUpgradeable as Ownable
} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {OffchainAssetReceiptVaultTest} from "./OffchainAssetReceiptVaultTest.sol";

abstract contract OwnerFreezableOwnerFreezeUntilTest is OffchainAssetReceiptVaultTest {
    using Math for uint256;

    IOwnerFreezableV1 internal sOwnerFreezable;
    address internal sAlice;
    address internal sBob;

    function checkOwnerFreezeUntil(uint256 freezeUntil, uint256 expectedFreeze) internal {
        vm.prank(sAlice);
        vm.expectEmit(true, true, true, true);
        emit IOwnerFreezableV1.OwnerFrozenUntil(sAlice, freezeUntil, expectedFreeze);
        sOwnerFreezable.ownerFreezeUntil(freezeUntil);
        assertEq(sOwnerFreezable.ownerFrozenUntil(), expectedFreeze);
    }

    function checkOwnerFreezeAlwaysAllowFrom(address from, uint256 protectUntil, uint256 expectedProtect) internal {
        vm.prank(sAlice);
        vm.expectEmit(true, true, true, true);
        emit IOwnerFreezableV1.OwnerFreezeAlwaysAllowedFrom(sAlice, from, protectUntil, expectedProtect);
        sOwnerFreezable.ownerFreezeAlwaysAllowFrom(from, protectUntil);
        assertEq(sOwnerFreezable.ownerFreezeAlwaysAllowedFrom(from), expectedProtect);
    }

    function checkOwnerFreezeStopAlwaysAllowingFrom(address from) internal {
        uint256 time = sOwnerFreezable.ownerFreezeAlwaysAllowedFrom(from);
        time = bound(time, time, type(uint256).max);
        vm.warp(time);
        vm.prank(sAlice);
        vm.expectEmit(true, true, true, true);
        emit IOwnerFreezableV1.OwnerFreezeAlwaysAllowedFrom(sAlice, from, 0, 0);
        sOwnerFreezable.ownerFreezeStopAlwaysAllowingFrom(from);
        assertEq(sOwnerFreezable.ownerFreezeAlwaysAllowedFrom(from), 0);
    }

    function checkOwnerFreezeAlwaysAllowTo(address to, uint256 protectUntil, uint256 expectedProtect) internal {
        vm.prank(sAlice);
        vm.expectEmit(true, true, true, true);
        emit IOwnerFreezableV1.OwnerFreezeAlwaysAllowedTo(sAlice, to, protectUntil, expectedProtect);
        sOwnerFreezable.ownerFreezeAlwaysAllowTo(to, protectUntil);
        assertEq(sOwnerFreezable.ownerFreezeAlwaysAllowedTo(to), expectedProtect);
    }

    function checkOwnerFreezeStopAlwaysAllowingTo(address to) internal {
        uint256 time = sOwnerFreezable.ownerFreezeAlwaysAllowedTo(to);
        time = bound(time, time, type(uint256).max);
        vm.warp(time);
        vm.prank(sAlice);
        vm.expectEmit(true, true, true, true);
        emit IOwnerFreezableV1.OwnerFreezeAlwaysAllowedTo(sAlice, to, 0, 0);
        sOwnerFreezable.ownerFreezeStopAlwaysAllowingTo(to);
        assertEq(sOwnerFreezable.ownerFreezeAlwaysAllowedTo(to), 0);
    }

    function testOwnerIsAlice() external view {
        assertEq(sOwnerFreezable.owner(), sAlice);
    }

    function testOwnerFreezableOnlyOwnerCanFreeze(uint256 freezeUntil) external {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sBob));
        vm.prank(sBob);
        sOwnerFreezable.ownerFreezeUntil(freezeUntil);
        assertEq(sOwnerFreezable.ownerFrozenUntil(), 0);

        vm.prank(sAlice);
        vm.expectEmit(true, true, true, true);
        emit IOwnerFreezableV1.OwnerFrozenUntil(sAlice, freezeUntil, freezeUntil);
        sOwnerFreezable.ownerFreezeUntil(freezeUntil);
        assertEq(sOwnerFreezable.ownerFrozenUntil(), freezeUntil);
    }

    /// Freezing the contract emits an event.
    function testOwnerFreezableFreezingEmitsEvent(uint256 freezeUntil) external {
        checkOwnerFreezeUntil(freezeUntil, freezeUntil);
    }

    /// Freezing twice increases the freeze until time if the second time is equal
    /// or greater than the first.
    function testOwnerFreezableFreezingIncrement(uint256 a, uint256 b) external {
        b = bound(b, a, type(uint256).max);
        checkOwnerFreezeUntil(a, a);
        checkOwnerFreezeUntil(b, b);
    }

    /// Freezing twice is a noop if the second time is less than or equal to the first.
    function testOwnerFreezableFreezingDecrement(uint256 a, uint256 b) external {
        b = bound(b, 0, a);
        checkOwnerFreezeUntil(a, a);
        checkOwnerFreezeUntil(b, a);
    }

    /// Freezing many times works if all times increase.
    function testOwnerFreezableFreezingManyIncreasing(uint32[] memory times) external {
        uint256 freezeUntil = 0;
        for (uint256 i; i < times.length; i++) {
            freezeUntil += times[i];
            checkOwnerFreezeUntil(freezeUntil, freezeUntil);
        }
    }

    /// Freezing times in the past are noops.
    function testOwnerFreezableFreezingMany(uint256[] memory freezeUntils) external {
        uint256 highwater = 0;
        for (uint256 i; i < freezeUntils.length; i++) {
            highwater = freezeUntils[i].max(highwater);
            checkOwnerFreezeUntil(freezeUntils[i], highwater);
        }
    }

    /// Only owner can call ownerFreezeAlwaysAllowFrom.
    function testOwnerFreezableOnlyOwnerCanFreezeAlwaysAllowFrom(address from, uint256 protectUntil) external {
        vm.assume(protectUntil != 0);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sBob));
        vm.prank(sBob);
        sOwnerFreezable.ownerFreezeAlwaysAllowFrom(from, protectUntil);
        assertEq(sOwnerFreezable.ownerFreezeAlwaysAllowedFrom(from), 0);

        checkOwnerFreezeAlwaysAllowFrom(from, protectUntil, protectUntil);

        checkOwnerFreezeStopAlwaysAllowingFrom(from);
    }

    /// Calling ownerFreezeAlwaysAllowFrom with a zero protectUntil reverts.
    function testOwnerFreezableZeroProtectUntilReverts(address from) external {
        vm.expectRevert(abi.encodeWithSelector(IOwnerFreezableV1.OwnerFreezeAlwaysAllowedFromZero.selector, from));
        vm.prank(sAlice);
        sOwnerFreezable.ownerFreezeAlwaysAllowFrom(from, 0);
    }

    /// Calling ownerFreezeAlwaysAllowFrom twice with increasing times always uses newer times.
    function testOwnerFreezableAlwaysAllowFromIncrement(address from, uint256 a, uint256 b) external {
        vm.assume(a != 0);
        b = bound(b, a, type(uint256).max);

        checkOwnerFreezeAlwaysAllowFrom(from, a, a);
        checkOwnerFreezeAlwaysAllowFrom(from, b, b);

        checkOwnerFreezeStopAlwaysAllowingFrom(from);
    }

    /// Calling ownerFreezeAlwaysAllowFrom twice with decreasing times retains the first time.
    function testOwnerFreezableAlwaysAllowFromDecrement(address from, uint256 a, uint256 b) external {
        vm.assume(a != 0);
        b = bound(b, 1, a);

        checkOwnerFreezeAlwaysAllowFrom(from, a, a);
        checkOwnerFreezeAlwaysAllowFrom(from, b, a);

        checkOwnerFreezeStopAlwaysAllowingFrom(from);
    }

    /// Calling ownerFreezeAlwaysAllowFrom many times with all times increasing.
    function testOwnerFreezableAlwaysAllowFromManyIncreasing(address from, uint32[] memory times) external {
        uint256 expected = 1;
        for (uint256 i; i < times.length; i++) {
            expected += times[i];
            checkOwnerFreezeAlwaysAllowFrom(from, expected, expected);
        }

        checkOwnerFreezeStopAlwaysAllowingFrom(from);
    }

    /// Calling ownerFreezeAlwaysAllowFrom many times.
    function testOwnerFreezableAlwaysAllowFromMany(address from, uint256[] memory times) external {
        uint256 highwater = 0;
        for (uint256 i; i < times.length; i++) {
            times[i] = times[i].max(1);
            highwater = highwater.max(times[i]);
            checkOwnerFreezeAlwaysAllowFrom(from, times[i], highwater);
        }

        checkOwnerFreezeStopAlwaysAllowingFrom(from);
    }

    /// Calling ownerFreezeAlwaysAllowFrom with different `from`.
    function testOwnerFreezableAlwaysAllowFromDifferentFrom(
        address from1,
        address from2,
        uint256 protectUntil1a,
        uint256 protectUntil1b,
        uint256 protectUntil2a,
        uint256 protectUntil2b
    ) external {
        vm.assume(from1 != from2);
        vm.assume(protectUntil1a != 0);
        vm.assume(protectUntil1b != 0);
        vm.assume(protectUntil2a != 0);
        vm.assume(protectUntil2b != 0);

        checkOwnerFreezeAlwaysAllowFrom(from1, protectUntil1a, protectUntil1a);
        checkOwnerFreezeAlwaysAllowFrom(from1, protectUntil1b, protectUntil1b.max(protectUntil1a));
        checkOwnerFreezeAlwaysAllowFrom(from2, protectUntil2a, protectUntil2a);
        checkOwnerFreezeAlwaysAllowFrom(from2, protectUntil2b, protectUntil2b.max(protectUntil2a));

        checkOwnerFreezeStopAlwaysAllowingFrom(from1);
        checkOwnerFreezeStopAlwaysAllowingFrom(from2);
    }

    /// Calling ownerFreezeStopAlwaysAllowingFrom before the protected time reverts.
    function testOwnerFreezableAlwaysAllowFromProtectedReverts(address from, uint256 protectUntil, uint256 time)
        external
    {
        vm.assume(from != address(0));
        vm.assume(protectUntil != 0);
        time = bound(time, 0, protectUntil - 1);
        checkOwnerFreezeAlwaysAllowFrom(from, protectUntil, protectUntil);

        vm.warp(time);
        vm.prank(sAlice);
        vm.expectRevert(
            abi.encodeWithSelector(IOwnerFreezableV1.OwnerFreezeAlwaysAllowedFromProtected.selector, from, protectUntil)
        );
        sOwnerFreezable.ownerFreezeStopAlwaysAllowingFrom(from);
    }

    /// Only owner can call ownerFreezeAlwaysAllowTo.
    function testOwnerFreezableOnlyOwnerCanFreezeAlwaysAllowTo(address to, uint256 protectUntil) external {
        vm.assume(protectUntil != 0);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sBob));
        vm.prank(sBob);
        sOwnerFreezable.ownerFreezeAlwaysAllowTo(to, protectUntil);
        assertEq(sOwnerFreezable.ownerFreezeAlwaysAllowedTo(to), 0);

        checkOwnerFreezeAlwaysAllowTo(to, protectUntil, protectUntil);

        checkOwnerFreezeStopAlwaysAllowingTo(to);
    }

    /// Calling ownerFreezeAlwaysAllowTo with a zero protectUntil reverts.
    function testOwnerFreezableZeroProtectUntilRevertsTo(address to) external {
        vm.expectRevert(abi.encodeWithSelector(IOwnerFreezableV1.OwnerFreezeAlwaysAllowedToZero.selector, to));
        vm.prank(sAlice);
        sOwnerFreezable.ownerFreezeAlwaysAllowTo(to, 0);
    }

    /// Calling ownerFreezeAlwaysAllowTo twice with increasing times always uses newer times.
    function testOwnerFreezableAlwaysAllowToIncrement(address to, uint256 a, uint256 b) external {
        vm.assume(a != 0);
        b = bound(b, a, type(uint256).max);

        checkOwnerFreezeAlwaysAllowTo(to, a, a);
        checkOwnerFreezeAlwaysAllowTo(to, b, b);

        checkOwnerFreezeStopAlwaysAllowingTo(to);
    }

    /// Calling ownerFreezeAlwaysAllowTo twice with decreasing times retains the first time.
    function testOwnerFreezableAlwaysAllowToDecrement(address to, uint256 a, uint256 b) external {
        vm.assume(a != 0);
        b = bound(b, 1, a);

        checkOwnerFreezeAlwaysAllowTo(to, a, a);
        checkOwnerFreezeAlwaysAllowTo(to, b, a);

        checkOwnerFreezeStopAlwaysAllowingTo(to);
    }

    /// Calling ownerFreezeAlwaysAllowTo many times with all times increasing.
    function testOwnerFreezableAlwaysAllowToManyIncreasing(address to, uint32[] memory times) external {
        uint256 expected = 1;
        for (uint256 i; i < times.length; i++) {
            expected += times[i];
            checkOwnerFreezeAlwaysAllowTo(to, expected, expected);
        }

        checkOwnerFreezeStopAlwaysAllowingTo(to);
    }

    /// Calling ownerFreezeAlwaysAllowTo many times.
    function testOwnerFreezableAlwaysAllowToMany(address to, uint256[] memory times) external {
        uint256 highwater = 0;
        for (uint256 i; i < times.length; i++) {
            times[i] = times[i].max(1);
            highwater = highwater.max(times[i]);
            checkOwnerFreezeAlwaysAllowTo(to, times[i], highwater);
        }

        checkOwnerFreezeStopAlwaysAllowingTo(to);
    }

    /// Calling ownerFreezeAlwaysAllowTo with different `to`.
    function testOwnerFreezableAlwaysAllowToDifferentTo(
        address to1,
        address to2,
        uint256 protectUntil1a,
        uint256 protectUntil1b,
        uint256 protectUntil2a,
        uint256 protectUntil2b
    ) external {
        vm.assume(to1 != to2);
        vm.assume(protectUntil1a != 0);
        vm.assume(protectUntil1b != 0);
        vm.assume(protectUntil2a != 0);
        vm.assume(protectUntil2b != 0);

        checkOwnerFreezeAlwaysAllowTo(to1, protectUntil1a, protectUntil1a);
        checkOwnerFreezeAlwaysAllowTo(to1, protectUntil1b, protectUntil1b.max(protectUntil1a));
        checkOwnerFreezeAlwaysAllowTo(to2, protectUntil2a, protectUntil2a);
        checkOwnerFreezeAlwaysAllowTo(to2, protectUntil2b, protectUntil2b.max(protectUntil2a));

        checkOwnerFreezeStopAlwaysAllowingTo(to1);
        checkOwnerFreezeStopAlwaysAllowingTo(to2);
    }

    /// Calling ownerFreezeStopAlwaysAllowingTo before the protected time reverts.
    function testOwnerFreezableAlwaysAllowToProtectedReverts(address to, uint256 protectUntil, uint256 time) external {
        vm.assume(to != address(0));
        vm.assume(protectUntil != 0);
        time = bound(time, 0, protectUntil - 1);
        checkOwnerFreezeAlwaysAllowTo(to, protectUntil, protectUntil);
        vm.warp(time);
        vm.prank(sAlice);
        vm.expectRevert(
            abi.encodeWithSelector(IOwnerFreezableV1.OwnerFreezeAlwaysAllowedToProtected.selector, to, protectUntil)
        );
        sOwnerFreezable.ownerFreezeStopAlwaysAllowingTo(to);
    }
}
