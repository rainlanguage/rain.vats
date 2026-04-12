// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultAuthorizerV1Test} from "test/abstract/OffchainAssetReceiptVaultAuthorizerV1Test.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1,
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config
} from "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {DepositStateChange, DEPOSIT} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {VerifyAlwaysApproved} from "rain.verify.interface/concrete/VerifyAlwaysApproved.sol";
import {TestErc20} from "test/concrete/TestErc20.sol";

contract OffchainAssetReceiptVaultPaymentMintAuthorizerV1RecipientNotOwnerTest is
    OffchainAssetReceiptVaultAuthorizerV1Test
{
    function newAuthorizer(address receiptVault, address owner, address paymentToken)
        internal
        returns (OffchainAssetReceiptVaultPaymentMintAuthorizerV1)
    {
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 implementation =
            new OffchainAssetReceiptVaultPaymentMintAuthorizerV1();
        CloneFactory factory = new CloneFactory();
        return OffchainAssetReceiptVaultPaymentMintAuthorizerV1(
            factory.clone(
                address(implementation),
                abi.encode(
                    OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config({
                        receiptVault: receiptVault,
                        verify: address(new VerifyAlwaysApproved()),
                        owner: owner,
                        paymentToken: paymentToken,
                        maxSharesSupply: 1e27
                    })
                )
            )
        );
    }

    /// Owner pays for a deposit where receiver is a different address. Payment
    /// is taken from the owner, not the receiver.
    function testRecipientNotOwnerPaymentFromOwner(address owner, address receiver, uint256 shares) external {
        vm.assume(owner != address(0) && receiver != address(0) && owner != receiver);
        vm.assume(uint160(owner) > type(uint160).max / 2);

        address receiptVault = address(uint160(uint256(keccak256("RECEIPT_VAULT.RECIPIENT"))));

        shares = bound(shares, 1, 1e24);

        vm.prank(owner);
        TestErc20 paymentToken = new TestErc20();

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, address(this), address(paymentToken));

        vm.mockCall(receiptVault, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(0));

        vm.prank(owner);
        paymentToken.approve(address(authorizer), shares);

        uint256 ownerBalanceBefore = paymentToken.balanceOf(owner);

        vm.prank(receiptVault);
        authorizer.authorize(
            owner,
            DEPOSIT,
            abi.encode(
                DepositStateChange({
                    owner: owner,
                    receiver: receiver,
                    id: 1,
                    assetsDeposited: shares,
                    sharesMinted: shares,
                    data: ""
                })
            )
        );

        assertEq(paymentToken.balanceOf(owner), ownerBalanceBefore - shares, "payment taken from owner");
        assertEq(paymentToken.balanceOf(receiver), 0, "receiver pays nothing");
        assertEq(paymentToken.balanceOf(address(authorizer)), shares, "authorizer holds payment");
    }
}
