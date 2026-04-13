// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {
    ERC20PriceOracleReceiptVaultCloneDeployer,
    ERC20PriceOracleReceiptVaultCloneDeployerConfig
} from "src/concrete/deploy/ERC20PriceOracleReceiptVaultCloneDeployer.sol";
import {
    IERC20PriceOracleReceiptVaultCloneDeployerV2
} from "src/interface/IERC20PriceOracleReceiptVaultCloneDeployerV2.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";

contract ERC20PriceOracleReceiptVaultCloneDeployerIERC165Test is Test {
    function testERC20PriceOracleReceiptVaultCloneDeployerIERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(IERC20PriceOracleReceiptVaultCloneDeployerV2).interfaceId);

        ERC20PriceOracleReceiptVaultCloneDeployer deployer = new ERC20PriceOracleReceiptVaultCloneDeployer(
            ERC20PriceOracleReceiptVaultCloneDeployerConfig({
                receiptImplementation: address(new ReceiptContract()),
                erc20PriceOracleReceiptVaultImplementation: address(new ERC20PriceOracleReceiptVault())
            })
        );

        assertTrue(deployer.supportsInterface(type(IERC165).interfaceId));
        assertTrue(deployer.supportsInterface(type(IERC20PriceOracleReceiptVaultCloneDeployerV2).interfaceId));
        assertFalse(deployer.supportsInterface(badInterfaceId));
    }
}
