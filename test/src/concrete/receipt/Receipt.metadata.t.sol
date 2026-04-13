// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ReceiptFactoryTest} from "test/abstract/ReceiptFactoryTest.sol";
import {TestReceiptManager} from "test/concrete/TestReceiptManager.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";

contract ReceiptMetadataTest is ReceiptFactoryTest {
    function testReceiptURI(uint256 id, uint8 decimalsB) external {
        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        string memory uri = receipt.uri(id);

        Metadata memory metadataJson = decodeMetadataURI(uri);

        assertEq(
            metadataJson.description,
            "1 of these receipts can be burned alongside 1 TRM to redeem TRMAsset from the vault."
        );
        assertEq(metadataJson.decimals, 18);
        assertEq(metadataJson.name, "TRM Receipt");

        testManager.setDecimals(decimalsB);

        metadataJson = decodeMetadataURI(receipt.uri(id));

        assertEq(metadataJson.decimals, decimalsB);
    }

    function testReceiptName() external {
        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        assertEq(receipt.name(), "TRM Receipt");
    }

    function testReceiptSymbol() external {
        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        assertEq(receipt.symbol(), "TRM RCPT");
    }
}
