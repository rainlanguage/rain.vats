// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault, DEPOSIT} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {OffchainAssetReceiptVaultAuthorizerV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";

contract OffchainAssetReceiptVaultMaxRedeemTest is OffchainAssetReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test vault returns correct max redeem.
    function testMaxRedeem(
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

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);

        uint256 maxRedeem = vault.maxRedeem(alice, 1);

        assertEqUint(maxRedeem, 0);

        uint256 actualShares = vault.deposit(assets, alice, minShareRatio, receiptInformation);

        maxRedeem = vault.maxRedeem(alice, 1);

        assertEqUint(maxRedeem, actualShares);

        maxRedeem = vault.maxRedeem(alice, otherId == 1 ? 2 : otherId);

        assertEqUint(maxRedeem, 0);

        maxRedeem = vault.maxRedeem(bob, otherId);

        assertEqUint(maxRedeem, 0);
    }
}
