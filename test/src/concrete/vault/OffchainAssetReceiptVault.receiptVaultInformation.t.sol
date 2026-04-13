// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {IReceiptVaultV1} from "src/interface/IReceiptVaultV3.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract OffchainAssetReceiptVaultReceiptVaultInformationTest is OffchainAssetReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test vault receiptVaultInformation
    function testReceiptVaultInformation(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        bytes memory information
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        vm.startPrank(alice);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.ReceiptVaultInformation(alice, information);

        vault.receiptVaultInformation(information);
    }
}
