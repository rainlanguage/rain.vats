// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {TestERC20} from "./TestERC20.sol";
import {ERC20_STORAGE_LOCATION} from "src/lib/LibERC20Storage.sol";

contract LibERC20StorageGetStorageTest is Test {
    TestERC20 internal token;

    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);

    function setUp() public {
        token = new TestERC20();
    }

    function testGetStorageIsRootedAtErc20StorageLocation() external view {
        assertEq(token.libStorageSlot(), ERC20_STORAGE_LOCATION);
    }

    function testGetStorageFieldsMatchOzViews() external {
        token.mint(ALICE, 1000);
        token.mint(BOB, 500);
        vm.prank(ALICE);
        token.approve(BOB, 77);

        assertEq(token.libStorageBalance(ALICE), token.balanceOf(ALICE));
        assertEq(token.libStorageBalance(BOB), token.balanceOf(BOB));
        assertEq(token.libStorageAllowance(ALICE, BOB), token.allowance(ALICE, BOB));
        assertEq(token.libStorageAllowance(ALICE, BOB), 77);
        assertEq(token.libStorageTotalSupply(), token.totalSupply());
        assertEq(token.libStorageName(), token.name());
        assertEq(token.libStorageName(), "Test");
        assertEq(token.libStorageSymbol(), token.symbol());
        assertEq(token.libStorageSymbol(), "TST");
    }

    /// Fuzzed lengths cover both short in-slot and long out-of-slot string encodings.
    function testFuzzGetStorageNameWriteVisibleToOzName(string calldata newName) external {
        token.mint(ALICE, 1000);

        token.libStorageSetName(newName);

        assertEq(token.name(), newName);
        assertEq(token.symbol(), "TST");
        assertEq(token.balanceOf(ALICE), 1000);
        assertEq(token.totalSupply(), 1000);
    }

    function testFuzzGetStorageSymbolWriteVisibleToOzSymbol(string calldata newSymbol) external {
        token.mint(ALICE, 1000);

        token.libStorageSetSymbol(newSymbol);

        assertEq(token.symbol(), newSymbol);
        assertEq(token.name(), "Test");
        assertEq(token.balanceOf(ALICE), 1000);
        assertEq(token.totalSupply(), 1000);
    }
}
