// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";

contract ERC20PriceOracleReceiptVaultAssetTest is ERC20PriceOracleReceiptVaultTest {
    function testVaultAsset(string memory shareName, string memory shareSymbol) external {
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);
        assertEq(vault.asset(), address(iAsset));
    }
}
