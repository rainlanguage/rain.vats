// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault, DEPOSIT} from "src/abstract/OffchainAssetReceiptVault.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {OffchainAssetReceiptVaultAuthorizerV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";

contract OffchainAssetReceiptVaultMaxRedeemTest is OffchainAssetReceiptVaultTest {
    /// Test vault returns correct max withdraw.
    function testMaxWithdraw(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 minShareRatio,
        uint256 otherId,
        bytes memory receiptInformation
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);
        assets = bound(assets, 1, type(uint128).max);
        minShareRatio = bound(minShareRatio, 0, 1e18);

        uint256 expectedShares = assets;
        vm.assume(expectedShares > 0);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);
        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);

        uint256 maxWithdraw = vault.maxWithdraw(alice, 1);

        assertEqUint(maxWithdraw, 0);

        uint256 actualShares = vault.deposit(assets, alice, minShareRatio, receiptInformation);

        maxWithdraw = vault.maxWithdraw(alice, 1);

        assertEqUint(actualShares, expectedShares);
        assertTrue(maxWithdraw <= assets);

        uint256 expectedMaxWithdraw = actualShares;
        assertEqUint(maxWithdraw, expectedMaxWithdraw);

        maxWithdraw = vault.maxWithdraw(alice, otherId == 1 ? 2 : otherId);

        assertEqUint(maxWithdraw, 0);

        maxWithdraw = vault.maxWithdraw(bob, otherId);

        assertEqUint(maxWithdraw, 0);
    }
}
