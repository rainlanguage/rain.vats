// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultRegistryTest} from "../../../abstract/OffchainAssetReceiptVaultRegistryTest.sol";
import {
    OffchainAssetReceiptVault,
    CONFIG_REGISTRY_RBAC_MIN_AGE
} from "../../../../src/abstract/OffchainAssetReceiptVault.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.7.0/proxy/utils/Initializable.sol";

contract OffchainAssetReceiptVaultRegistryConstructTest is OffchainAssetReceiptVaultRegistryTest {
    function testMinAgeIsOneHour() external pure {
        assertEq(CONFIG_REGISTRY_RBAC_MIN_AGE, 3600);
    }

    function testImplementationInitializeDisabled() external {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        iImplementation.initialize(encodeConfig(config()));
    }
}
