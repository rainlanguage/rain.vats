// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";

import {
    OffchainAssetReceiptVaultBeaconSetDeployer,
    OffchainAssetReceiptVaultBeaconSetDeployerConfig,
    OffchainAssetReceiptVaultConfigV2
} from "src/concrete/deploy/OffchainAssetReceiptVaultBeaconSetDeployer.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {OffchainAssetReceiptVault, ReceiptVaultConfigV2} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {InitializeNonZeroReceipt, ZeroInitialAdmin} from "src/error/ErrDeployer.sol";

contract OffchainAssetReceiptVaultBeaconSetDeployerNewOffchainAssetReceiptVaultTest is Test {
    function testNewOffchainAssetReceiptVaultNonZeroReceipt(OffchainAssetReceiptVaultConfigV2 memory config) external {
        vm.assume(config.receiptVaultConfig.receipt != address(0));
        vm.assume(config.initialAdmin != address(0));

        ReceiptContract receiptImplementation = new ReceiptContract();
        OffchainAssetReceiptVault offchainAssetReceiptVaultImplementation = new OffchainAssetReceiptVault();
        OffchainAssetReceiptVaultBeaconSetDeployer deployer = new OffchainAssetReceiptVaultBeaconSetDeployer(
            OffchainAssetReceiptVaultBeaconSetDeployerConfig({
                initialOwner: address(this),
                initialReceiptImplementation: address(receiptImplementation),
                initialOffchainAssetReceiptVaultImplementation: address(offchainAssetReceiptVaultImplementation)
            })
        );
        vm.expectRevert(abi.encodeWithSelector(InitializeNonZeroReceipt.selector, config.receiptVaultConfig.receipt));
        deployer.newOffchainAssetReceiptVault(config);
    }

    function testNewOffchainAssetReceiptVaultZeroInitialAdmin(OffchainAssetReceiptVaultConfigV2 memory config)
        external
    {
        config.receiptVaultConfig.receipt = address(0);
        config.initialAdmin = address(0);

        ReceiptContract receiptImplementation = new ReceiptContract();
        OffchainAssetReceiptVault offchainAssetReceiptVaultImplementation = new OffchainAssetReceiptVault();
        OffchainAssetReceiptVaultBeaconSetDeployer deployer = new OffchainAssetReceiptVaultBeaconSetDeployer(
            OffchainAssetReceiptVaultBeaconSetDeployerConfig({
                initialOwner: address(this),
                initialReceiptImplementation: address(receiptImplementation),
                initialOffchainAssetReceiptVaultImplementation: address(offchainAssetReceiptVaultImplementation)
            })
        );
        vm.expectRevert(abi.encodeWithSelector(ZeroInitialAdmin.selector));
        deployer.newOffchainAssetReceiptVault(config);
    }

    function testNewOffchainAssetReceiptVault(address alice, OffchainAssetReceiptVaultConfigV2 memory config) external {
        vm.assume(alice.code.length == 0);
        vm.assume(config.initialAdmin != address(0));
        config.receiptVaultConfig.receipt = address(0);
        config.receiptVaultConfig.asset = address(0);

        ReceiptContract receiptImplementation = new ReceiptContract();
        OffchainAssetReceiptVault offchainAssetReceiptVaultImplementation = new OffchainAssetReceiptVault();
        OffchainAssetReceiptVaultBeaconSetDeployer deployer = new OffchainAssetReceiptVaultBeaconSetDeployer(
            OffchainAssetReceiptVaultBeaconSetDeployerConfig({
                initialOwner: address(this),
                initialReceiptImplementation: address(receiptImplementation),
                initialOffchainAssetReceiptVaultImplementation: address(offchainAssetReceiptVaultImplementation)
            })
        );

        vm.startPrank(alice);
        vm.recordLogs();
        OffchainAssetReceiptVault offchainAssetReceiptVault = deployer.newOffchainAssetReceiptVault(config);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        vm.stopPrank();

        bool eventFound = false;
        bytes32 eventTopic = keccak256("Deployment(address,address,address)");
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
        assertTrue(eventFound, "OffchainAssetReceiptVaultBeaconSetDeployerDeployment event log not found");
        assertEq(eventSender, alice);
        assertEq(eventVault, address(offchainAssetReceiptVault));
        assertEq(eventReceipt, address(offchainAssetReceiptVault.receipt()));

        assertEq(
            address(OffchainAssetReceiptVault(payable(offchainAssetReceiptVault)).receipt().manager()),
            address(offchainAssetReceiptVault)
        );
    }
}
