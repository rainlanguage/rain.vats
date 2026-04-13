// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    ZeroReceiptImplementation,
    ZeroVaultImplementation,
    InitializeNonZeroReceipt,
    InitializeReceiptFailed,
    InitializeVaultFailed
} from "../../error/ErrDeployer.sol";
import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IERC20PriceOracleReceiptVaultCloneDeployerV2} from "../../interface/IERC20PriceOracleReceiptVaultCloneDeployerV2.sol";
import {Receipt, ICLONEABLE_V2_SUCCESS} from "../receipt/Receipt.sol";
import {
    ERC20PriceOracleReceiptVault,
    ERC20PriceOracleReceiptVaultConfigV2
} from "../vault/ERC20PriceOracleReceiptVault.sol";

/// Configuration for the ERC20PriceOracleReceiptVaultCloneDeployer construction.
/// @param receiptImplementation The address of the Receipt implementation
/// contract to clone from.
/// @param erc20PriceOracleReceiptVaultImplementation The address of the
/// ERC20PriceOracleReceiptVault implementation contract to clone from.
//forge-lint: disable-next-line(pascal-case-struct)
struct ERC20PriceOracleReceiptVaultCloneDeployerConfig {
    address receiptImplementation;
    address erc20PriceOracleReceiptVaultImplementation;
}

/// @title ERC20PriceOracleReceiptVaultCloneDeployer
/// Deploys ERC20PriceOracleReceiptVault contracts as minimal proxy contracts
/// and handles the necessary initialization atomically.
contract ERC20PriceOracleReceiptVaultCloneDeployer is IERC165 {
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC20PriceOracleReceiptVaultCloneDeployerV2).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }
    /// Emitted when a new deployment is successfully initialized.
    /// @param sender The address that initiated the deployment.
    /// @param erc20PriceOracleReceiptVault The address of the deployed
    /// ERC20PriceOracleReceiptVault contract.
    /// @param receipt The address of the deployed Receipt contract.
    event ERC20PriceOracleReceiptVaultCloneDeployerDeployment(
        address sender, address erc20PriceOracleReceiptVault, address receipt
    );

    /// The address of the Receipt implementation contract to clone from.
    address public immutable iReceiptImplementation;

    /// The address of the ERC20PriceOracleReceiptVault implementation contract
    /// to clone from.
    address public immutable iErc20PriceOracleReceiptVaultImplementation;

    /// @param config The configuration for the deployer.
    constructor(ERC20PriceOracleReceiptVaultCloneDeployerConfig memory config) {
        if (config.receiptImplementation == address(0)) revert ZeroReceiptImplementation();
        if (config.erc20PriceOracleReceiptVaultImplementation == address(0)) revert ZeroVaultImplementation();
        iReceiptImplementation = config.receiptImplementation;
        iErc20PriceOracleReceiptVaultImplementation = config.erc20PriceOracleReceiptVaultImplementation;
    }

    /// Deploys and initializes a new ERC20PriceOracleReceiptVault contract
    /// along with its associated Receipt contract.
    /// @param config The configuration for the ERC20PriceOracleReceiptVault.
    /// @return The address of the newly deployed ERC20PriceOracleReceiptVault
    /// contract.
    // Deployer is stateless — reentrancy via initialize cannot corrupt state.
    //slither-disable-next-line reentrancy-events
    function newERC20PriceOracleReceiptVault(ERC20PriceOracleReceiptVaultConfigV2 memory config)
        external
        returns (ERC20PriceOracleReceiptVault)
    {
        if (config.receiptVaultConfig.receipt != address(0)) {
            revert InitializeNonZeroReceipt(config.receiptVaultConfig.receipt);
        }

        Receipt receipt = Receipt(Clones.clone(iReceiptImplementation));
        ERC20PriceOracleReceiptVault erc20PriceOracleReceiptVault =
            ERC20PriceOracleReceiptVault(payable(Clones.clone(iErc20PriceOracleReceiptVaultImplementation)));

        if (receipt.initialize(abi.encode(erc20PriceOracleReceiptVault)) != ICLONEABLE_V2_SUCCESS) {
            revert InitializeReceiptFailed();
        }

        config.receiptVaultConfig.receipt = address(receipt);
        if (erc20PriceOracleReceiptVault.initialize(abi.encode(config)) != ICLONEABLE_V2_SUCCESS) {
            revert InitializeVaultFailed();
        }

        emit ERC20PriceOracleReceiptVaultCloneDeployerDeployment(
            msg.sender, address(erc20PriceOracleReceiptVault), address(receipt)
        );

        return erc20PriceOracleReceiptVault;
    }
}
