// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault, WITHDRAW} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {OffchainAssetReceiptVaultAuthorizerV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";

contract OffchainAssetReceiptVaultPreviewWithdrawTest is OffchainAssetReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    function testPreviewWithdrawNoRole(
        uint256 aliceSeed,
        uint256 assets,
        string memory shareName,
        string memory shareSymbol,
        uint256 id
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        // Assume that assets is not 0
        assets = bound(assets, 1, type(uint256).max);
        id = bound(id, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Call withdraw function
        uint256 shares = vault.previewWithdraw(assets, id);

        assertEq(shares, assets);
        // Stop the prank
        vm.stopPrank();
    }

    function testPreviewWithdrawWithRole(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 assets,
        string memory shareName,
        string memory shareSymbol,
        uint256 id
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        // Assume that assets is not 0
        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        // Prank as Alice to grant role
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(WITHDRAW, bob);

        // Prank as Bob for transaction
        vm.startPrank(bob);

        // Call withdraw function
        uint256 shares = vault.previewWithdraw(assets, id);

        assertEq(shares, assets);
        // Stop the prank
        vm.stopPrank();
    }

    receive() external payable {}

    fallback() external payable {}
}
