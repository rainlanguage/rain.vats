// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Receipt, ICLONEABLE_V2_SUCCESS} from "../receipt/Receipt.sol";
import {OffchainAssetReceiptVault, OffchainAssetReceiptVaultConfigV2} from "../vault/OffchainAssetReceiptVault.sol";
import {IBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import {
    ZeroReceiptImplementation,
    ZeroVaultImplementation,
    ZeroBeaconOwner,
    ZeroInitialAdmin,
    InitializeNonZeroReceipt,
    InitializeReceiptFailed,
    InitializeVaultFailed
} from "../../error/ErrDeployer.sol";

/// Configuration for the OffchainAssetReceiptVaultBeaconSetDeployer
/// construction.
/// @param initialOwner The initial owner of the beacons.
/// @param initialReceiptImplementation The address of the initial Receipt
/// implementation contract.
/// @param initialOffchainAssetReceiptVaultImplementation The address of the
/// initial OffchainAssetReceiptVault implementation contract.
struct OffchainAssetReceiptVaultBeaconSetDeployerConfig {
    address initialOwner;
    address initialReceiptImplementation;
    address initialOffchainAssetReceiptVaultImplementation;
}

/// @title OffchainAssetReceiptVaultBeaconSetDeployer
/// Deploys OffchainAssetReceiptVault contracts using beacon proxies and
/// handles the necessary initialization atomically.
contract OffchainAssetReceiptVaultBeaconSetDeployer {
    /// Emitted when a new deployment is successfully initialized.
    /// @param sender The address that initiated the deployment.
    /// @param offchainAssetReceiptVault The address of the deployed
    /// OffchainAssetReceiptVault contract.
    /// @param receipt The address of the deployed Receipt contract.
    event Deployment(address sender, address offchainAssetReceiptVault, address receipt);

    /// The beacon for the Receipt implementation contracts.
    IBeacon public immutable iReceiptBeacon;

    /// The beacon for the OffchainAssetReceiptVault implementation contracts.
    IBeacon public immutable iOffchainAssetReceiptVaultBeacon;

    /// @param config The configuration for the deployer.
    constructor(OffchainAssetReceiptVaultBeaconSetDeployerConfig memory config) {
        if (address(config.initialReceiptImplementation) == address(0)) {
            revert ZeroReceiptImplementation();
        }
        if (address(config.initialOffchainAssetReceiptVaultImplementation) == address(0)) {
            revert ZeroVaultImplementation();
        }
        if (config.initialOwner == address(0)) {
            revert ZeroBeaconOwner();
        }

        iReceiptBeacon = new UpgradeableBeacon(address(config.initialReceiptImplementation), config.initialOwner);
        iOffchainAssetReceiptVaultBeacon =
            new UpgradeableBeacon(address(config.initialOffchainAssetReceiptVaultImplementation), config.initialOwner);
    }

    /// Deploys and initializes a new OffchainAssetReceiptVault contract along
    /// with its associated Receipt contract. Both are beacon proxies pointing
    /// to the respective immutable beacons.
    /// @param config The configuration for the OffchainAssetReceiptVault.
    /// @return The address of the newly deployed OffchainAssetReceiptVault
    /// contract.
    // Deployer is stateless — reentrancy via initialize cannot corrupt state.
    //slither-disable-next-line reentrancy-events
    function newOffchainAssetReceiptVault(OffchainAssetReceiptVaultConfigV2 memory config)
        external
        returns (OffchainAssetReceiptVault)
    {
        if (config.receiptVaultConfig.receipt != address(0)) {
            revert InitializeNonZeroReceipt(config.receiptVaultConfig.receipt);
        }

        if (config.initialAdmin == address(0)) revert ZeroInitialAdmin();

        Receipt receipt = Receipt(address(new BeaconProxy(address(iReceiptBeacon), "")));
        OffchainAssetReceiptVault offchainAssetReceiptVault =
            OffchainAssetReceiptVault(payable(address(new BeaconProxy(address(iOffchainAssetReceiptVaultBeacon), ""))));

        if (receipt.initialize(abi.encode(offchainAssetReceiptVault)) != ICLONEABLE_V2_SUCCESS) {
            revert InitializeReceiptFailed();
        }

        config.receiptVaultConfig.receipt = address(receipt);
        if (offchainAssetReceiptVault.initialize(abi.encode(config)) != ICLONEABLE_V2_SUCCESS) {
            revert InitializeVaultFailed();
        }

        emit Deployment(msg.sender, address(offchainAssetReceiptVault), address(receipt));

        return offchainAssetReceiptVault;
    }
}
