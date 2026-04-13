// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {
    ERC20PriceOracleReceiptVault,
    ERC20PriceOracleReceiptVaultConfigV2,
    ReceiptVaultConfigV2
} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {Receipt as ReceiptContract} from "../../src/concrete/receipt/Receipt.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPriceOracleV2} from "../../src/interface/IPriceOracleV2.sol";
import {
    ERC20PriceOracleReceiptVaultCloneDeployer,
    ERC20PriceOracleReceiptVaultCloneDeployerConfig
} from "../../src/concrete/deploy/ERC20PriceOracleReceiptVaultCloneDeployer.sol";

contract ERC20PriceOracleReceiptVaultTest is Test {
    ERC20PriceOracleReceiptVault internal immutable iImplementation;
    ReceiptContract internal immutable iReceiptImplementation;
    IERC20 immutable iAsset;
    IPriceOracleV2 immutable iVaultOracle;
    ERC20PriceOracleReceiptVaultCloneDeployer internal immutable iDeployer;

    constructor() {
        iReceiptImplementation = new ReceiptContract();
        iImplementation = new ERC20PriceOracleReceiptVault();
        iAsset = IERC20(address(uint160(uint256(keccak256("asset.test")))));
        iVaultOracle = IPriceOracleV2(payable(address(uint160(uint256(keccak256("vault.oracle"))))));
        iDeployer = new ERC20PriceOracleReceiptVaultCloneDeployer(
            ERC20PriceOracleReceiptVaultCloneDeployerConfig({
                receiptImplementation: address(iReceiptImplementation),
                erc20PriceOracleReceiptVaultImplementation: address(iImplementation)
            })
        );
    }

    function setVaultOraclePrice(uint256 oraclePrice) internal {
        vm.mockCall(
            address(iVaultOracle), abi.encodeWithSelector(IPriceOracleV2.price.selector), abi.encode(oraclePrice)
        );
    }

    function createVault(IPriceOracleV2 priceOracle, string memory name, string memory symbol)
        internal
        returns (ERC20PriceOracleReceiptVault)
    {
        return iDeployer.newERC20PriceOracleReceiptVault(
            ERC20PriceOracleReceiptVaultConfigV2({
                receiptVaultConfig: ReceiptVaultConfigV2({
                    asset: address(iAsset),
                    name: name,
                    symbol: symbol,
                    receipt: address(0)
                }),
                priceOracle: priceOracle
            })
        );
    }

    /// Get Receipt from event
    function getReceipt() internal view returns (ReceiptContract) {
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the event log
        address receiptAddress = address(0);
        bool eventFound = false; // Flag to indicate whether the event log was found
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == ERC20PriceOracleReceiptVault.ERC20PriceOracleReceiptVaultInitializedV2.selector) {
                // Decode the event data
                (, ERC20PriceOracleReceiptVaultConfigV2 memory config) =
                    abi.decode(logs[i].data, (address, ERC20PriceOracleReceiptVaultConfigV2));
                receiptAddress = config.receiptVaultConfig.receipt;
                eventFound = true; // Set the flag to true since event log was found
                break;
            }
        }
        // Assert that the event log was found
        assertTrue(eventFound, "ERC20PriceOracleReceiptVaultInitializedV2 event log not found");
        // Return an receipt contract
        return ReceiptContract(receiptAddress);
    }
}
