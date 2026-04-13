// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.0;

import {
    ERC20PriceOracleReceiptVault,
    ERC20PriceOracleReceiptVaultConfigV2
} from "../concrete/vault/ERC20PriceOracleReceiptVault.sol";

/// @title IERC20PriceOracleReceiptVaultCloneDeployerV2
/// @notice V2 interface for the ERC20PriceOracleReceiptVaultCloneDeployer.
/// Uses camelCase i prefix. New deployments use this ABI.
interface IERC20PriceOracleReceiptVaultCloneDeployerV2 {
    /// @return The address of the Receipt implementation contract.
    function iReceiptImplementation() external view returns (address);

    /// @return The address of the ERC20PriceOracleReceiptVault implementation.
    function iErc20PriceOracleReceiptVaultImplementation() external view returns (address);

    /// @notice Deploy a new ERC20PriceOracleReceiptVault with its Receipt.
    function newERC20PriceOracleReceiptVault(ERC20PriceOracleReceiptVaultConfigV2 memory config)
        external
        returns (ERC20PriceOracleReceiptVault);
}
