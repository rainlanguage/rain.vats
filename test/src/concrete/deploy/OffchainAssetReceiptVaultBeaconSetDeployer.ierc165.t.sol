// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {
    OffchainAssetReceiptVaultBeaconSetDeployer,
    OffchainAssetReceiptVaultBeaconSetDeployerConfig
} from "src/concrete/deploy/OffchainAssetReceiptVaultBeaconSetDeployer.sol";
import {
    IOffchainAssetReceiptVaultBeaconSetDeployerV2
} from "src/interface/IOffchainAssetReceiptVaultBeaconSetDeployerV2.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";

contract OffchainAssetReceiptVaultBeaconSetDeployerIERC165Test is Test {
    function testOffchainAssetReceiptVaultBeaconSetDeployerIERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(IOffchainAssetReceiptVaultBeaconSetDeployerV2).interfaceId);

        OffchainAssetReceiptVaultBeaconSetDeployer deployer = new OffchainAssetReceiptVaultBeaconSetDeployer(
            OffchainAssetReceiptVaultBeaconSetDeployerConfig({
                initialOwner: address(this),
                initialReceiptImplementation: address(new ReceiptContract()),
                initialOffchainAssetReceiptVaultImplementation: address(new OffchainAssetReceiptVault())
            })
        );

        assertTrue(deployer.supportsInterface(type(IERC165).interfaceId));
        assertTrue(deployer.supportsInterface(type(IOffchainAssetReceiptVaultBeaconSetDeployerV2).interfaceId));
        assertFalse(deployer.supportsInterface(badInterfaceId));
    }
}
