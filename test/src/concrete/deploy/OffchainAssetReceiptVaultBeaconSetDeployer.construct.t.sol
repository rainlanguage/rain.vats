// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {
    OffchainAssetReceiptVaultBeaconSetDeployer,
    OffchainAssetReceiptVaultBeaconSetDeployerConfig
} from "src/concrete/deploy/OffchainAssetReceiptVaultBeaconSetDeployer.sol";
import {
    IOffchainAssetReceiptVaultBeaconSetDeployerV2
} from "src/interface/IOffchainAssetReceiptVaultBeaconSetDeployerV2.sol";
import {ZeroReceiptImplementation, ZeroVaultImplementation, ZeroBeaconOwner} from "src/error/ErrDeployer.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";

contract OffchainAssetReceiptVaultBeaconSetDeployerConstructTest is Test {
    function testOffchainAssetReceiptVaultBeaconSetDeployerConstructZeroReceiptImplementation(
        address initialOffchainAssetReceiptVaultImplementation,
        address initialOwner
    ) external {
        vm.assume(initialOffchainAssetReceiptVaultImplementation != address(0));
        vm.assume(initialOwner != address(0));
        vm.expectRevert(abi.encodeWithSelector(ZeroReceiptImplementation.selector));
        new OffchainAssetReceiptVaultBeaconSetDeployer(
            OffchainAssetReceiptVaultBeaconSetDeployerConfig({
                initialOwner: initialOwner,
                initialReceiptImplementation: address(0),
                initialOffchainAssetReceiptVaultImplementation: initialOffchainAssetReceiptVaultImplementation
            })
        );
    }

    function testOffchainAssetReceiptVaultBeaconSetDeployerConstructZeroVaultImplementation(
        address initialReceiptImplementation,
        address initialOwner
    ) external {
        vm.assume(initialReceiptImplementation != address(0));
        vm.assume(initialOwner != address(0));
        vm.expectRevert(abi.encodeWithSelector(ZeroVaultImplementation.selector));
        new OffchainAssetReceiptVaultBeaconSetDeployer(
            OffchainAssetReceiptVaultBeaconSetDeployerConfig({
                initialOwner: initialOwner,
                initialReceiptImplementation: initialReceiptImplementation,
                initialOffchainAssetReceiptVaultImplementation: address(0)
            })
        );
    }

    function testOffchainAssetReceiptVaultBeaconSetDeployerConstructZeroBeaconOwner(
        address initialReceiptImplementation,
        address initialOffchainAssetReceiptVaultImplementation
    ) external {
        vm.assume(initialReceiptImplementation != address(0));
        vm.assume(initialOffchainAssetReceiptVaultImplementation != address(0));
        vm.expectRevert(abi.encodeWithSelector(ZeroBeaconOwner.selector));
        new OffchainAssetReceiptVaultBeaconSetDeployer(
            OffchainAssetReceiptVaultBeaconSetDeployerConfig({
                initialOwner: address(0),
                initialReceiptImplementation: initialReceiptImplementation,
                initialOffchainAssetReceiptVaultImplementation: initialOffchainAssetReceiptVaultImplementation
            })
        );
    }

    function testOffchainAssetReceiptVaultBeaconSetDeployerConstructSuccess(address initialOwner) external {
        vm.assume(initialOwner != address(0));
        ReceiptContract initialReceiptImplementation = new ReceiptContract();
        OffchainAssetReceiptVault initialOffchainAssetReceiptVaultImplementation = new OffchainAssetReceiptVault();

        OffchainAssetReceiptVaultBeaconSetDeployer deployer = new OffchainAssetReceiptVaultBeaconSetDeployer(
            OffchainAssetReceiptVaultBeaconSetDeployerConfig({
                initialOwner: initialOwner,
                initialReceiptImplementation: address(initialReceiptImplementation),
                initialOffchainAssetReceiptVaultImplementation: address(initialOffchainAssetReceiptVaultImplementation)
            })
        );

        IOffchainAssetReceiptVaultBeaconSetDeployerV2 iDeployer =
            IOffchainAssetReceiptVaultBeaconSetDeployerV2(address(deployer));
        vm.assertEq(address(iDeployer.iReceiptBeacon().implementation()), address(initialReceiptImplementation));
        vm.assertEq(
            address(iDeployer.iOffchainAssetReceiptVaultBeacon().implementation()),
            address(initialOffchainAssetReceiptVaultImplementation)
        );
    }
}
