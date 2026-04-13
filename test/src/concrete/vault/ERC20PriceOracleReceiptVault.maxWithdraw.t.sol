// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";

contract ERC20PriceOracleReceiptVaultMaxRedeemTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test vault returns correct max withdraw.
    function testMaxWithdraw(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 oraclePrice,
        uint256 otherOraclePrice,
        uint256 minShareRatio,
        bytes memory receiptInformation
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);
        assets = bound(assets, 1, type(uint128).max);
        oraclePrice = bound(oraclePrice, 1, type(uint128).max);
        otherOraclePrice = bound(otherOraclePrice, 1, type(uint128).max);
        minShareRatio = bound(minShareRatio, 0, oraclePrice);

        uint256 expectedShares = assets.fixedPointMul(oraclePrice, Math.Rounding.Floor);
        vm.assume(expectedShares > 0);
        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);

        uint256 maxWithdraw = vault.maxWithdraw(alice, oraclePrice);

        assertEqUint(maxWithdraw, 0);

        setVaultOraclePrice(oraclePrice);
        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), assets),
            abi.encode(true)
        );

        uint256 actualShares = vault.deposit(assets, alice, minShareRatio, receiptInformation);

        maxWithdraw = vault.maxWithdraw(alice, oraclePrice);

        assertEqUint(actualShares, expectedShares);
        assertTrue(maxWithdraw <= assets);

        uint256 expectedMaxWithdraw = actualShares.fixedPointDiv(oraclePrice, Math.Rounding.Floor);
        assertEqUint(maxWithdraw, expectedMaxWithdraw);

        maxWithdraw =
            vault.maxWithdraw(alice, otherOraclePrice == oraclePrice ? otherOraclePrice + 1 : otherOraclePrice);

        assertEqUint(maxWithdraw, 0);

        maxWithdraw = vault.maxWithdraw(bob, otherOraclePrice);

        assertEqUint(maxWithdraw, 0);
    }
}
