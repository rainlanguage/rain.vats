// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {
    ERC20PriceOracleReceiptVaultCloneDeployer,
    ERC20PriceOracleReceiptVaultCloneDeployerConfig
} from "src/concrete/deploy/ERC20PriceOracleReceiptVaultCloneDeployer.sol";
import {
    IERC20PriceOracleReceiptVaultCloneDeployerV2
} from "src/interface/IERC20PriceOracleReceiptVaultCloneDeployerV2.sol";
import {ZeroReceiptImplementation, ZeroVaultImplementation} from "src/error/ErrDeployer.sol";

contract ERC20PriceOracleReceiptVaultCloneDeployerConstructTest is Test {
    function testERC20PriceOracleReceiptVaultCloneDeployerConstructZeroReceiptImplementation(address erc20PriceOracleReceiptVaultImplementation)
        external
    {
        vm.assume(erc20PriceOracleReceiptVaultImplementation != address(0));
        vm.expectRevert(abi.encodeWithSelector(ZeroReceiptImplementation.selector));
        new ERC20PriceOracleReceiptVaultCloneDeployer(
            ERC20PriceOracleReceiptVaultCloneDeployerConfig({
                receiptImplementation: address(0),
                erc20PriceOracleReceiptVaultImplementation: erc20PriceOracleReceiptVaultImplementation
            })
        );
    }

    function testERC20PriceOracleReceiptVaultCloneDeployerConstructZeroVaultImplementation(address receiptImplementation)
        external
    {
        vm.assume(receiptImplementation != address(0));
        vm.expectRevert(abi.encodeWithSelector(ZeroVaultImplementation.selector));
        new ERC20PriceOracleReceiptVaultCloneDeployer(
            ERC20PriceOracleReceiptVaultCloneDeployerConfig({
                receiptImplementation: receiptImplementation, erc20PriceOracleReceiptVaultImplementation: address(0)
            })
        );
    }

    function testERC20PriceOracleReceiptVaultCloneDeployerConstruct(ERC20PriceOracleReceiptVaultCloneDeployerConfig memory config)
        external
    {
        vm.assume(config.receiptImplementation != address(0));
        vm.assume(config.erc20PriceOracleReceiptVaultImplementation != address(0));

        ERC20PriceOracleReceiptVaultCloneDeployer deployer = new ERC20PriceOracleReceiptVaultCloneDeployer(config);

        IERC20PriceOracleReceiptVaultCloneDeployerV2 iDeployer =
            IERC20PriceOracleReceiptVaultCloneDeployerV2(address(deployer));
        vm.assertEq(iDeployer.iReceiptImplementation(), config.receiptImplementation);
        vm.assertEq(
            iDeployer.iErc20PriceOracleReceiptVaultImplementation(), config.erc20PriceOracleReceiptVaultImplementation
        );
    }
}
