// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";

import {
    ERC20PriceOracleReceiptVaultCloneDeployer,
    ERC20PriceOracleReceiptVaultCloneDeployerConfig,
    ERC20PriceOracleReceiptVaultConfigV2
} from "src/concrete/deploy/ERC20PriceOracleReceiptVaultCloneDeployer.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {
    ERC20PriceOracleReceiptVault,
    ReceiptVaultConfigV2,
    IPriceOracleV2
} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {InitializeNonZeroReceipt} from "src/error/ErrDeployer.sol";

contract ERC20PriceOracleReceiptVaultCloneDeployerNewERC20PriceOracleReceiptVaultTest is Test {
    function testNewERC20PriceOracleReceiptVaultNonZeroReceipt(ERC20PriceOracleReceiptVaultConfigV2 memory config)
        external
    {
        vm.assume(config.receiptVaultConfig.receipt != address(0));
        ReceiptContract receiptImplementation = new ReceiptContract();
        ERC20PriceOracleReceiptVault erc20PriceOracleReceiptVaultImplementation = new ERC20PriceOracleReceiptVault();
        ERC20PriceOracleReceiptVaultCloneDeployer deployer = new ERC20PriceOracleReceiptVaultCloneDeployer(
            ERC20PriceOracleReceiptVaultCloneDeployerConfig({
                receiptImplementation: address(receiptImplementation),
                erc20PriceOracleReceiptVaultImplementation: address(erc20PriceOracleReceiptVaultImplementation)
            })
        );
        vm.expectRevert(abi.encodeWithSelector(InitializeNonZeroReceipt.selector, config.receiptVaultConfig.receipt));
        deployer.newERC20PriceOracleReceiptVault(config);
    }

    function testNewERC20PriceOracleReceiptVaultSuccess(
        address alice,
        ERC20PriceOracleReceiptVaultConfigV2 memory config
    ) external {
        vm.assume(alice.code.length == 0);
        config.receiptVaultConfig.receipt = address(0);
        ReceiptContract receiptImplementation = new ReceiptContract();
        ERC20PriceOracleReceiptVault erc20PriceOracleReceiptVaultImplementation = new ERC20PriceOracleReceiptVault();
        ERC20PriceOracleReceiptVaultCloneDeployer deployer = new ERC20PriceOracleReceiptVaultCloneDeployer(
            ERC20PriceOracleReceiptVaultCloneDeployerConfig({
                receiptImplementation: address(receiptImplementation),
                erc20PriceOracleReceiptVaultImplementation: address(erc20PriceOracleReceiptVaultImplementation)
            })
        );
        vm.startPrank(alice);
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = deployer.newERC20PriceOracleReceiptVault(config);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vm.stopPrank();

        bool eventFound = false;
        bytes32 eventTopic = keccak256("ERC20PriceOracleReceiptVaultCloneDeployerDeployment(address,address,address)");
        address eventSender;
        address eventVault;
        address eventReceipt;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventTopic) {
                (eventSender, eventVault, eventReceipt) = abi.decode(logs[i].data, (address, address, address));
                eventFound = true;
                break;
            }
        }
        assertTrue(eventFound, "ERC20PriceOracleReceiptVaultCloneDeployerDeployment event log not found");
        assertEq(eventSender, alice);
        assertEq(eventVault, address(vault));
        assertEq(eventReceipt, address(vault.receipt()));

        assert(address(vault) != address(0));
        assert(vault.asset() == config.receiptVaultConfig.asset);
    }
}
