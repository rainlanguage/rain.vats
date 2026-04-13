// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    ERC20PriceOracleReceiptVault,
    ERC20PriceOracleReceiptVaultConfigV2
} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest, Vm} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {IPriceOracleV2} from "src/interface/IPriceOracleV2.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract ERC20PriceOracleReceiptVaultInitializeTest is ERC20PriceOracleReceiptVaultTest {
    /// Test ERC20PriceOracleReceiptVault is initialized
    function testERC20PriceOracleReceiptVaultInitializedV2Event(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);
        bytes32 eventTopic =
            keccak256("ERC20PriceOracleReceiptVaultInitializedV2(address,(address,(address,string,string,address)))");

        IPriceOracleV2 vaultPriceOracle =
            IPriceOracleV2(payable(address(uint160(uint256(keccak256("twoPriceOracle"))))));
        vm.startPrank(alice);

        // Start recording logs
        vm.recordLogs();

        ERC20PriceOracleReceiptVault vault = createVault(vaultPriceOracle, shareName, shareSymbol);
        // Get the logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Note: To use vm.expectEmit receipt address is needed to be known.
        // Find the OffchainAssetReceiptVaultInitialized event log
        address msgSender;

        ERC20PriceOracleReceiptVaultConfigV2 memory config;

        bool eventFound = false; // Flag to indicate whether the event log was found
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventTopic) {
                // Decode the event data
                (msgSender, config) = abi.decode(logs[i].data, (address, ERC20PriceOracleReceiptVaultConfigV2));
                eventFound = true; // Set the flag to true since event log was found
                break;
            }
        }
        // Assert that the event log was found
        assertTrue(eventFound, "ERC20PriceOracleReceiptVaultInitializedV2 event log not found");

        assertEq(msgSender, address(iDeployer));
        assert(address(vault) != address(0));

        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(config.receiptVaultConfig.name)));
        assertEq(config.receiptVaultConfig.name, shareName);

        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(config.receiptVaultConfig.symbol)));
        assertEq(config.receiptVaultConfig.symbol, shareSymbol);

        assertEq(address(config.receiptVaultConfig.asset), address(iAsset));

        assertTrue(address(config.receiptVaultConfig.receipt) != address(0));
        assertEq(address(config.receiptVaultConfig.receipt), address(vault.receipt()));

        assertEq(address(config.priceOracle), address(vaultPriceOracle));
        assertTrue(address(vault) != address(0));

        // Check the receipt manager is the vault.
        assertEq(address(vault), vault.receipt().manager());
    }

    /// Test creating several different vaults
    function testCreatingSeveralVaults(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        string memory shareNameTwo,
        string memory shareSymbolTwo
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        // Simulate transaction from alice
        vm.prank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);

        assert(address(vault) != address(0));
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(shareName)));
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(shareSymbol)));

        // Simulate transaction from alice
        vm.prank(bob);

        ERC20PriceOracleReceiptVault vaultTwo = createVault(iVaultOracle, shareNameTwo, shareSymbolTwo);

        assert(address(vaultTwo) != address(0));
        assertEq(keccak256(bytes(vaultTwo.name())), keccak256(bytes(shareNameTwo)));
        assertEq(keccak256(bytes(vaultTwo.symbol())), keccak256(bytes(shareSymbolTwo)));
    }
}
