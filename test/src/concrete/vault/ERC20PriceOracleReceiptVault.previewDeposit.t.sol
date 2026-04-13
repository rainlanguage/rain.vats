// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";

contract ERC20PriceOracleReceiptVaultPreviewDepositTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test PreviewDeposit returns correct shares
    function testPreviewDepositReturnedShares(
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 oraclePrice
    ) external {
        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        assets = bound(assets, 1, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);

        uint256 expectedShares = assets.fixedPointMul(oraclePrice, Math.Rounding.Floor);

        uint256 shares = vault.previewDeposit(assets, 0);

        assertEqUint(shares, expectedShares);

        vm.stopPrank();
    }

    receive() external payable {}

    fallback() external payable {}
}
