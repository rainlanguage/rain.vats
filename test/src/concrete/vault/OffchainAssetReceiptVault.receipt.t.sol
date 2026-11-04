// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault} from "src/abstract/OffchainAssetReceiptVault.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract OffchainAssetReceiptVaultReceiptTest is OffchainAssetReceiptVaultTest {
    function testVaultAsset(uint256 aliceSeed, string memory shareName, string memory shareSymbol) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);
        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        assertEq(address(vault), vault.receipt().manager());
    }
}
