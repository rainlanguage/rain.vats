// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.0;

import {IBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";
import {OffchainAssetReceiptVault, OffchainAssetReceiptVaultConfigV2} from "../concrete/vault/OffchainAssetReceiptVault.sol";

/// @title IOffchainAssetReceiptVaultBeaconSetDeployerV1
/// @notice V1 interface for the OffchainAssetReceiptVaultBeaconSetDeployer.
/// Uses the original I_ naming convention for public immutables. Deployed
/// contracts on-chain have this ABI.
interface IOffchainAssetReceiptVaultBeaconSetDeployerV1 {
    /// @return The beacon for the Receipt implementation contracts.
    // Matches deployed on-chain ABI.
    //slither-disable-next-line naming-convention
    function I_RECEIPT_BEACON() external view returns (IBeacon);

    /// @return The beacon for the OffchainAssetReceiptVault implementation
    /// contracts.
    // Matches deployed on-chain ABI.
    //slither-disable-next-line naming-convention
    function I_OFFCHAIN_ASSET_RECEIPT_VAULT_BEACON() external view returns (IBeacon);

    /// @notice Deploy a new OffchainAssetReceiptVault with its Receipt.
    function newOffchainAssetReceiptVault(OffchainAssetReceiptVaultConfigV2 memory config)
        external
        returns (OffchainAssetReceiptVault);
}
