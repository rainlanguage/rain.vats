// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ConcreteReceiptVault} from "test/concrete/ConcreteReceiptVault.sol";
import {TestErc20} from "test/concrete/TestErc20.sol";
import {ReceiptVaultConfigV2} from "src/abstract/ReceiptVault.sol";
import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";

import {Test} from "forge-std/Test.sol";

contract ReceiptVaultDecimalsTest is Test {
    function testDecimalsWithZeroAsset() external {
        ConcreteReceiptVault receiptVault = new ConcreteReceiptVault();
        uint8 decimals = receiptVault.decimals();
        assertEq(decimals, 18);
    }

    function testDecimalsWithNonZeroAsset(uint8 assetDecimals) external {
        ReceiptContract receiptImplementation = new ReceiptContract();
        ConcreteReceiptVault receiptVaultImplementation = new ConcreteReceiptVault();
        TestErc20 asset = new TestErc20();

        ReceiptContract receipt = ReceiptContract(Clones.clone(address(receiptImplementation)));
        ConcreteReceiptVault receiptVault =
            ConcreteReceiptVault(payable(Clones.clone(address(receiptVaultImplementation))));
        receipt.initialize(abi.encode(address(receiptVault)));
        receiptVault.initialize(
            abi.encode(
                ReceiptVaultConfigV2({
                    asset: address(asset), name: "Test Vault", symbol: "TVLT", receipt: address(receipt)
                })
            )
        );

        asset.setDecimals(assetDecimals);

        assertEq(receiptVault.asset(), address(asset));

        uint8 decimals = receiptVault.decimals();
        assertEq(decimals, assetDecimals);
    }
}
