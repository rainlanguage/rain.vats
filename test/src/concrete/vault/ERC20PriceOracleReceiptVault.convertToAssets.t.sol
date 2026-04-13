// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract ERC20PriceOracleReceiptVaultConvertToAssetsTest is ERC20PriceOracleReceiptVaultTest {
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

        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);

        uint256 expectedAssets = shares.fixedPointDiv(id, Math.Rounding.Floor);
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

        vm.startPrank(alice);

        uint256 expectedAssets = shares.fixedPointDiv(id, Math.Rounding.Floor);
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);

        uint256 resultAssetsAlice = vault.convertToAssets(shares, id);
        vm.stopPrank();

        vm.startPrank(bob);

        uint256 resultAssetsBob = vault.convertToAssets(shares, id);

        assertEqUint(resultAssetsAlice, resultAssetsBob);
        assertEqUint(expectedAssets, resultAssetsAlice);
    }
}
