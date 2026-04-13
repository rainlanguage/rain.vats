// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {UnmanagedReceiptTransfer} from "src/interface/IReceiptManagerV2.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract ERC20PriceOracleReceiptVaultAuthorizeReceiptTransferTest is ERC20PriceOracleReceiptVaultTest {
    /// Test AuthorizeReceiptTransfer reverts if the caller is not the managed
    /// receipt.
    function testAuthorizeReceiptTransferNotManaged(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 timestamp,
        string memory shareName,
        string memory shareSymbol,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        // Bound timestamp from 1 to avoid potential issues with timestamp 0.
        timestamp = bound(timestamp, 1, type(uint32).max);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);

        vm.warp(timestamp);

        // Attempt to authorize receipt transfer, should NOT revert.
        vm.prank(address(vault.receipt()));
        vault.authorizeReceiptTransfer3(bob, bob, alice, ids, amounts);

        // Attempt to authorize receipt transfer as anyone else, should revert.
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(UnmanagedReceiptTransfer.selector));
        vault.authorizeReceiptTransfer3(bob, bob, alice, ids, amounts);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(UnmanagedReceiptTransfer.selector));
        vault.authorizeReceiptTransfer3(bob, bob, alice, ids, amounts);
    }
}
