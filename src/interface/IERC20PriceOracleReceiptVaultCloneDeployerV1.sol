// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.0;

import {
    ERC20PriceOracleReceiptVault,
    ERC20PriceOracleReceiptVaultConfigV2
} from "../concrete/vault/ERC20PriceOracleReceiptVault.sol";

/// @title IERC20PriceOracleReceiptVaultCloneDeployerV1
/// @notice V1 interface for the ERC20PriceOracleReceiptVaultCloneDeployer.
/// Uses the original I_ naming convention. Deployed contracts on-chain have
/// this ABI.
interface IERC20PriceOracleReceiptVaultCloneDeployerV1 {
    /// @return The address of the Receipt implementation contract.
    // Matches deployed on-chain ABI.
    //slither-disable-next-line naming-convention
    function I_RECEIPT_IMPLEMENTATION() external view returns (address);

    /// @return The address of the ERC20PriceOracleReceiptVault implementation.
    // Matches deployed on-chain ABI.
    //slither-disable-next-line naming-convention
    function I_ERC20_PRICE_ORACLE_RECEIPT_VAULT_IMPLEMENTATION() external view returns (address);

    /// @notice Deploy a new ERC20PriceOracleReceiptVault with its Receipt.
    function newERC20PriceOracleReceiptVault(ERC20PriceOracleReceiptVaultConfigV2 memory config)
        external
        returns (ERC20PriceOracleReceiptVault);
}
