// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultAuthorizerV1Test} from "test/abstract/OffchainAssetReceiptVaultAuthorizerV1Test.sol";
import {OffchainAssetReceiptVault, CERTIFY} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultAuthorizerV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1,
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config
} from "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {CloneFactory} from "rain-factory-0.1.5/src/concrete/CloneFactory.sol";
import {VerifyAlwaysApproved} from "rain-verify-interface-0.1.0/src/concrete/VerifyAlwaysApproved.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts-5.6.1/utils/ReentrancyGuard.sol";
import {ReentrantAsset, IReentrantAssetVault} from "test/concrete/ReentrantAsset.sol";

/// @notice Row 19 regression: the payment-mint authorizer pulls the payment
/// ERC20 (`paymentToken.safeTransferFrom`) from inside `_afterDeposit`'s
/// `authorize(DEPOSIT)` call, which runs while the `_deposit` `nonReentrant`
/// guard is held. A REAL, hooked, reentrant payment token re-enters
/// `vault.deposit` during that pull; the nested deposit reverts on the guard and
/// SafeERC20 bubbles it out, reverting the whole mint. No shares are minted, so
/// the supply cap cannot be bypassed by reentrancy.
contract OffchainAssetReceiptVaultPaymentMintReentrantTest is OffchainAssetReceiptVaultAuthorizerV1Test {
    function newAuthorizer(address receiptVault, address owner, address paymentToken, uint256 maxSharesSupply)
        internal
        returns (OffchainAssetReceiptVaultPaymentMintAuthorizerV1)
    {
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 implementation =
            new OffchainAssetReceiptVaultPaymentMintAuthorizerV1();
        CloneFactory factory = new CloneFactory();
        bytes memory initData = abi.encode(
            OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config({
                receiptVault: receiptVault,
                verify: address(new VerifyAlwaysApproved()),
                owner: owner,
                paymentToken: paymentToken,
                maxSharesSupply: maxSharesSupply
            })
        );
        return OffchainAssetReceiptVaultPaymentMintAuthorizerV1(
            factory.cloneDeterministic(address(implementation), initData, bytes32(0))
        );
    }

    function testPaymentMintReentrantPaymentTokenGuardFires(
        uint256 shares,
        string memory shareName,
        string memory shareSymbol
    ) external {
        shares = bound(shares, 1, 1e24);

        address admin = makeAddr("admin");
        address payer = makeAddr("payer");

        OffchainAssetReceiptVault vault = createVault(admin, shareName, shareSymbol);

        // The payment token is a REAL reentrant ERC20.
        ReentrantAsset paymentToken = new ReentrantAsset();
        paymentToken.mint(payer, type(uint128).max);

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 paymentAuth =
            newAuthorizer(address(vault), admin, address(paymentToken), 1e27);

        // Install the payment-mint authorizer and certify so share/receipt
        // transfers are permitted during the mint.
        vm.startPrank(admin);
        vault.setAuthorizer(paymentAuth);
        paymentAuth.grantRole(CERTIFY, admin);
        vault.certify(block.timestamp + 1000, false, "");
        vm.stopPrank();

        // Payer funds and approves the authorizer for the payment pull.
        vm.prank(payer);
        paymentToken.approve(address(paymentAuth), type(uint256).max);

        // Arm the payment token to re-enter the vault during the payment pull.
        paymentToken.setVault(IReentrantAssetVault(address(vault)));
        paymentToken.armTransferFrom();

        vm.prank(payer);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        vault.mint(shares, payer, 0, "");

        // The whole mint rolled back: no shares, so the supply cap is intact.
        assertEq(vault.totalSupply(), 0, "no shares minted under reentrancy");
    }
}
