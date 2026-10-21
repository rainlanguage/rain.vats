// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    ConfigRegistryOffchainAssetReceiptVaultTest
} from "../../../abstract/ConfigRegistryOffchainAssetReceiptVaultTest.sol";
import {
    ConfigRegistryOffchainAssetReceiptVault,
    ZeroReceiptBeacon,
    CONFIG_REGISTRY_RBAC_MIN_AGE
} from "../../../../src/concrete/vault/ConfigRegistryOffchainAssetReceiptVault.sol";
import {IBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/IBeacon.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.7.0/proxy/utils/Initializable.sol";

contract ConfigRegistryOffchainAssetReceiptVaultConstructTest is ConfigRegistryOffchainAssetReceiptVaultTest {
    function testMinAgeIsOneHour() external pure {
        assertEq(CONFIG_REGISTRY_RBAC_MIN_AGE, 3600);
    }

    function testConstructZeroReceiptBeacon() external {
        vm.expectRevert(abi.encodeWithSelector(ZeroReceiptBeacon.selector));
        new ConfigRegistryOffchainAssetReceiptVault(IBeacon(address(0)));
    }

    function testConstructReceiptBeacon(address receiptBeacon) external {
        vm.assume(receiptBeacon != address(0));
        ConfigRegistryOffchainAssetReceiptVault vault =
            new ConfigRegistryOffchainAssetReceiptVault(IBeacon(receiptBeacon));
        assertEq(address(vault.iReceiptBeacon()), receiptBeacon);
    }

    function testImplementationInitializeDisabled() external {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        iImplementation.initialize(encodeConfig(config(0)));
    }
}
