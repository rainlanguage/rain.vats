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

contract ERC20PriceOracleReceiptVaultPreviewWithdrawTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test PreviewWithdraw returns correct shares
    function testPreviewWithdraw(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 oraclePrice
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        assets = bound(assets, 1, type(uint64).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

        // Prank as Alice to grant role
        vm.startPrank(alice);
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);

        // Call withdraw function
        uint256 expectedShares = assets.fixedPointMul(oraclePrice, Math.Rounding.Ceil);
        uint256 shares = vault.previewWithdraw(assets, oraclePrice);

        assertEq(shares, expectedShares);
        // Stop the prank
        vm.stopPrank();
    }

    receive() external payable {}

    fallback() external payable {}
}
