// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    ConfigRegistryOffchainAssetReceiptVaultTest
} from "../../../abstract/ConfigRegistryOffchainAssetReceiptVaultTest.sol";
import {
    ConfigRegistryOffchainAssetReceiptVault,
    CONFIG_REGISTRY_RBAC_MIN_AGE
} from "../../../../src/concrete/vault/ConfigRegistryOffchainAssetReceiptVault.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.7.0/proxy/utils/Initializable.sol";

contract ConfigRegistryOffchainAssetReceiptVaultConstructTest is ConfigRegistryOffchainAssetReceiptVaultTest {
    function testMinAgeIsOneHour() external pure {
        assertEq(CONFIG_REGISTRY_RBAC_MIN_AGE, 3600);
    }

    function testImplementationInitializeDisabled() external {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        iImplementation.initialize(encodeConfig(config(0)));
    }
}
