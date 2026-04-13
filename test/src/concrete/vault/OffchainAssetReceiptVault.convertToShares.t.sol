// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract OffchainAssetReceiptVaultConvertToSharesTest is OffchainAssetReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test convertToShares
    function testConvertToShares(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 id
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        id = bound(id, 0, type(uint128).max);
        assets = bound(assets, 1, type(uint128).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        uint256 expectedShares = assets;

        vm.startPrank(alice);
        uint256 resultShares = vault.convertToShares(assets, id);

        assertEqUint(expectedShares, resultShares);
    }

    /// Test convertToShares
    function testConvertToSharesDifferentCaller(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 id
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        // Bound the ID to a range that could actually be a price.
        id = bound(id, 0.001e18, 100e18);
        assets = bound(assets, 1, type(uint128).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        vm.startPrank(alice);
        uint256 resultSharesAlice = vault.convertToShares(assets, id);
        vm.stopPrank();

        vm.startPrank(bob);

        uint256 resultSharesBob = vault.convertToShares(assets, id);

        assertEqUint(resultSharesAlice, assets);
        assertEqUint(resultSharesAlice, resultSharesBob);
    }
}
