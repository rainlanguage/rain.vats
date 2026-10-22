// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultRegistryTest} from "../../../abstract/OffchainAssetReceiptVaultRegistryTest.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.7.0/proxy/utils/Initializable.sol";

contract OffchainAssetReceiptVaultRegistryConstructTest is OffchainAssetReceiptVaultRegistryTest {
    function testImplementationInitializeDisabled() external {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        iImplementation.initialize(encodeConfig(config()));
    }
}
