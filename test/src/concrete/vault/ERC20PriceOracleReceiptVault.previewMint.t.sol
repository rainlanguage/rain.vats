// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";

contract ERC20PriceOracleReceiptVaultPreviewMintTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test PreviewMint returns correct assets
    function testPreviewMintReturnedAssets(
        string memory shareName,
        string memory shareSymbol,
        uint256 shares,
        uint256 oraclePrice
    ) external {
        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        shares = bound(shares, 1, type(uint64).max);
        vm.assume(shares.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);

        uint256 assets = shares.fixedPointDiv(oraclePrice, Math.Rounding.Ceil);

        uint256 resultAssets = vault.previewMint(shares, 0);

        assertEqUint(assets, resultAssets);

        vm.stopPrank();
    }

    receive() external payable {}

    fallback() external payable {}
}
