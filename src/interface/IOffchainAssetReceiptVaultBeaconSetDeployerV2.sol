// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.0;

import {IBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV2
} from "../concrete/vault/OffchainAssetReceiptVault.sol";

/// @title IOffchainAssetReceiptVaultBeaconSetDeployerV2
/// @notice V2 interface for the OffchainAssetReceiptVaultBeaconSetDeployer.
/// Uses camelCase i prefix for public immutables. New deployments use this ABI.
interface IOffchainAssetReceiptVaultBeaconSetDeployerV2 {
    /// @return The beacon for the Receipt implementation contracts.
    function iReceiptBeacon() external view returns (IBeacon);

    /// @return The beacon for the OffchainAssetReceiptVault implementation
    /// contracts.
    function iOffchainAssetReceiptVaultBeacon() external view returns (IBeacon);

    /// @notice Deploy a new OffchainAssetReceiptVault with its Receipt.
    function newOffchainAssetReceiptVault(OffchainAssetReceiptVaultConfigV2 memory config)
        external
        returns (OffchainAssetReceiptVault);
}
