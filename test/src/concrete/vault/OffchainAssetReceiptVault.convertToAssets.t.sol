// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract OffchainAssetReceiptVaultConvertToAssetsTest is OffchainAssetReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test convertToAssets
    function testConvertToAssets(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 shares,
        uint256 id
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        id = bound(id, 1, type(uint256).max);
        shares = bound(shares, 1, type(uint128).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        uint256 expectedAssets = shares;

        uint256 resultAssets = vault.convertToAssets(shares, id);

        assertEqUint(expectedAssets, resultAssets);
    }

    /// Test convertToAssets shows no variations based on caller
    function testConvertToAssetsDifferentCaller(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 shares,
        uint256 id
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        id = bound(id, 1, type(uint256).max);
        shares = bound(shares, 1, type(uint64).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        vm.startPrank(alice);
        uint256 resultAssetsAlice = vault.convertToAssets(shares, id);
        vm.stopPrank();

        vm.startPrank(bob);

        uint256 resultAssetsBob = vault.convertToAssets(shares, id);

        assertEqUint(resultAssetsAlice, shares);
        assertEqUint(resultAssetsAlice, resultAssetsBob);
    }
}
