// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {TestERC1155} from "./TestERC1155.sol";
import {ERC1155_STORAGE_LOCATION} from "src/lib/LibERC1155Storage.sol";

/// @dev Drift-detection tests for `LibERC1155Storage`. Every assertion is
/// grounded against `ERC1155Upgradeable` running on the same test contract:
/// if OZ reorders the `ERC1155Storage` struct or renames the ERC-7201
/// namespace, the slot derivations stop matching the OZ reads and every
/// assertion in this file fails.
contract LibERC1155StorageTest is Test {
    TestERC1155 internal token;

    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);

    uint256 internal constant ID_A = 1;
    uint256 internal constant ID_B = 2;

    function setUp() public {
        token = new TestERC1155();
    }

    /// The hardcoded ERC-7201 slot constant matches the documented derivation.
    function testErc1155SlotConstantMatchesDerivation() external pure {
        bytes32 expected =
            keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC1155")) - 1)) & ~bytes32(uint256(0xff));
        assertEq(ERC1155_STORAGE_LOCATION, expected, "ERC1155_STORAGE_LOCATION drift from spec formula");
    }

    /// LibERC1155Storage.underlyingBalance matches ERC1155Upgradeable.balanceOf across
    /// multiple ids and multiple accounts.
    function testGetBalanceMatchesOzBalanceOf() external {
        token.mint(ALICE, ID_A, 1234);
        token.mint(ALICE, ID_B, 4321);
        token.mint(BOB, ID_A, 99);

        assertEq(token.libBalanceOf(ALICE, ID_A), token.balanceOf(ALICE, ID_A));
        assertEq(token.libBalanceOf(ALICE, ID_A), 1234);

        assertEq(token.libBalanceOf(ALICE, ID_B), token.balanceOf(ALICE, ID_B));
        assertEq(token.libBalanceOf(ALICE, ID_B), 4321);

        assertEq(token.libBalanceOf(BOB, ID_A), token.balanceOf(BOB, ID_A));
        assertEq(token.libBalanceOf(BOB, ID_A), 99);

        // Uninhabited (account, id) pairs read as zero.
        assertEq(token.libBalanceOf(BOB, ID_B), 0);
    }

    /// LibERC1155Storage.setUnderlyingBalance writes a value that ERC1155Upgradeable.balanceOf observes.
    function testSetBalanceVisibleToOzBalanceOf() external {
        token.mint(ALICE, ID_A, 100);
        token.libSetBalance(ALICE, ID_A, 999);
        assertEq(token.balanceOf(ALICE, ID_A), 999, "OZ balanceOf must reflect the direct write");
    }

    /// Round trip: OZ mint → Lib read → Lib write → OZ read. Every step the
    /// two views agree.
    function testFuzzRoundTripSingleId(uint128 mintAmount, uint128 directWrite) external {
        token.mint(ALICE, ID_A, uint256(mintAmount));
        assertEq(token.libBalanceOf(ALICE, ID_A), token.balanceOf(ALICE, ID_A));

        token.libSetBalance(ALICE, ID_A, uint256(directWrite));
        assertEq(token.balanceOf(ALICE, ID_A), uint256(directWrite));
        assertEq(token.libBalanceOf(ALICE, ID_A), uint256(directWrite));
    }

    /// Each `(account, id)` pair lives in its own slot. Writing to (ALICE, A)
    /// must not touch (ALICE, B), (BOB, A), or (BOB, B).
    function testPerIdAndPerAccountSlotIsolation() external {
        token.mint(ALICE, ID_A, 100);
        token.mint(ALICE, ID_B, 200);
        token.mint(BOB, ID_A, 300);
        token.mint(BOB, ID_B, 400);

        token.libSetBalance(ALICE, ID_A, 555);

        assertEq(token.balanceOf(ALICE, ID_A), 555, "(ALICE, A) updated");
        assertEq(token.balanceOf(ALICE, ID_B), 200, "(ALICE, B) untouched");
        assertEq(token.balanceOf(BOB, ID_A), 300, "(BOB, A) untouched");
        assertEq(token.balanceOf(BOB, ID_B), 400, "(BOB, B) untouched");
    }

    /// Fuzz: many ids + many accounts survive round-trip.
    function testFuzzMultipleIdsMultipleAccounts(uint8 idSeed, uint64 amount) external {
        uint256 id1 = uint256(idSeed) % 100;
        uint256 id2 = (uint256(idSeed) % 100) + 1000;
        token.mint(ALICE, id1, uint256(amount));
        token.mint(BOB, id2, uint256(amount) * 2);

        assertEq(token.libBalanceOf(ALICE, id1), token.balanceOf(ALICE, id1));
        assertEq(token.libBalanceOf(BOB, id2), token.balanceOf(BOB, id2));
        assertEq(token.libBalanceOf(ALICE, id2), 0);
        assertEq(token.libBalanceOf(BOB, id1), 0);
    }

    /// OZ burns are visible to the library accessor.
    function testBurnObservedByLib() external {
        token.mint(ALICE, ID_A, 1000);
        token.burn(ALICE, ID_A, 300);
        assertEq(token.libBalanceOf(ALICE, ID_A), 700);
    }

    /// Large id values (near uint256 max) still derive the correct slot.
    function testLargeIdValues() external {
        uint256 hugeId = type(uint256).max - 1;
        token.mint(ALICE, hugeId, 777);
        assertEq(token.libBalanceOf(ALICE, hugeId), 777);
        assertEq(token.libBalanceOf(ALICE, hugeId - 1), 0);
    }

    /// Fuzz: randomized account, id, and balance — Lib read matches OZ read.
    function testFuzzRandomAccountIdBalance(address account, uint256 id, uint128 amount) external {
        vm.assume(account != address(0) && account.code.length == 0);
        token.mint(account, id, uint256(amount));
        assertEq(token.libBalanceOf(account, id), token.balanceOf(account, id), "Lib must match OZ after mint");
        assertEq(token.libBalanceOf(account, id), uint256(amount));
    }

    /// Fuzz: randomized setBalance followed by OZ read.
    function testFuzzRandomSetBalance(address account, uint256 id, uint128 mintAmount, uint256 newBalance) external {
        vm.assume(account != address(0) && account.code.length == 0);
        token.mint(account, id, uint256(mintAmount));
        token.libSetBalance(account, id, newBalance);
        assertEq(token.balanceOf(account, id), newBalance, "OZ must reflect Lib write");
        assertEq(token.libBalanceOf(account, id), newBalance, "Lib read must match Lib write");
    }

    /// Fuzz: two randomized (account, id) pairs — writing to one never affects
    /// the other.
    function testFuzzTwoPairSlotIsolation(
        address a,
        address b,
        uint256 idA,
        uint256 idB,
        uint64 amountA,
        uint64 amountB,
        uint256 writeA
    ) external {
        vm.assume(a != address(0) && b != address(0));
        vm.assume(a != b || idA != idB);
        vm.assume(a.code.length == 0 && b.code.length == 0);
        token.mint(a, idA, uint256(amountA));
        token.mint(b, idB, uint256(amountB));
        token.libSetBalance(a, idA, writeA);
        assertEq(token.balanceOf(a, idA), writeA, "(a, idA) updated");
        assertEq(token.balanceOf(b, idB), uint256(amountB), "(b, idB) untouched");
    }

    /// Fuzz: same account, different ids — writing to one id does not affect another.
    function testFuzzSameAccountDifferentIdIsolation(
        address account,
        uint256 id1,
        uint256 id2,
        uint64 amount1,
        uint64 amount2,
        uint256 write1
    ) external {
        vm.assume(account != address(0) && id1 != id2 && account.code.length == 0);
        token.mint(account, id1, uint256(amount1));
        token.mint(account, id2, uint256(amount2));
        token.libSetBalance(account, id1, write1);
        assertEq(token.balanceOf(account, id1), write1, "id1 updated");
        assertEq(token.balanceOf(account, id2), uint256(amount2), "id2 untouched");
        assertEq(token.libBalanceOf(account, id2), uint256(amount2), "Lib read of id2 untouched");
    }
}
