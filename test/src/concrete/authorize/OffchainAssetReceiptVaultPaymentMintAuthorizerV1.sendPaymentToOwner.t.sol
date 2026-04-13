// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultAuthorizerV1Test} from "test/abstract/OffchainAssetReceiptVaultAuthorizerV1Test.sol";

import {TestErc20} from "test/concrete/TestErc20.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1
} from "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config
} from "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {VerifyAlwaysApproved} from "rain.verify.interface/concrete/VerifyAlwaysApproved.sol";

contract OffchainAssetReceiptVaultPaymentMintAuthorizerV1IERC165Test is OffchainAssetReceiptVaultAuthorizerV1Test {
    function newAuthorizer(
        address receiptVault,
        address owner,
        address paymentToken,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply
    ) internal returns (OffchainAssetReceiptVaultPaymentMintAuthorizerV1) {
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
        vm.mockCall(
            paymentToken, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(paymentTokenDecimals)
        );
        return OffchainAssetReceiptVaultPaymentMintAuthorizerV1(factory.clone(address(implementation), initData));
    }

    function testSendPaymentToOwner(address receiptVault, address alice, address bob, address anon) external {
        vm.assume(alice != address(0) && bob != address(0) && alice != bob);
        vm.assume(receiptVault != address(0));

        vm.prank(bob);
        TestErc20 paymentToken = new TestErc20();
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, alice, address(paymentToken), 18, 1000e18);

        assertEq(authorizer.owner(), alice, "Owner should be set to Alice");

        assertEq(0, paymentToken.balanceOf(alice), "Alice should have no tokens initially");
        assertEq(1e27, paymentToken.balanceOf(bob), "Bob should have no tokens initially");
        assertEq(0, paymentToken.balanceOf(address(authorizer)), "Authorizer should have no tokens initially");

        vm.prank(anon);
        authorizer.sendPaymentToOwner();
        assertEq(0, paymentToken.balanceOf(alice), "Alice should still have no tokens after sendPaymentToOwner");
        assertEq(1e27, paymentToken.balanceOf(bob), "Bob should still have no tokens after sendPaymentToOwner");
        assertEq(
            0,
            paymentToken.balanceOf(address(authorizer)),
            "Authorizer should still have no tokens after sendPaymentToOwner"
        );

        vm.prank(bob);
        assertTrue(paymentToken.transfer(address(authorizer), 1e18));

        assertEq(0, paymentToken.balanceOf(alice), "Alice should still have no tokens after transfer to authorizer");
        assertEq(
            1e27 - 1e18, paymentToken.balanceOf(bob), "Bob should have 1e18 less tokens after transfer to authorizer"
        );
        assertEq(
            1e18,
            paymentToken.balanceOf(address(authorizer)),
            "Authorizer should have 1e18 tokens after transfer to authorizer"
        );

        vm.prank(anon);
        authorizer.sendPaymentToOwner();

        assertEq(1e18, paymentToken.balanceOf(alice), "Alice should have 1e18 tokens after sendPaymentToOwner");
        assertEq(
            1e27 - 1e18,
            paymentToken.balanceOf(bob),
            "Bob should still have 1e27 - 1e18 tokens after sendPaymentToOwner"
        );
        assertEq(
            0, paymentToken.balanceOf(address(authorizer)), "Authorizer should have no tokens after sendPaymentToOwner"
        );

        vm.prank(alice);

        authorizer.transferOwnership(bob);

        assertEq(bob, authorizer.owner(), "Owner should be transferred to Bob");
        assertEq(1e18, paymentToken.balanceOf(alice), "Alice should still have 1e18 tokens after transferOwnership");
        assertEq(
            1e27 - 1e18, paymentToken.balanceOf(bob), "Bob should still have 1e27 - 1e18 tokens after transferOwnership"
        );
        assertEq(
            0,
            paymentToken.balanceOf(address(authorizer)),
            "Authorizer should still have no tokens after transferOwnership"
        );

        vm.prank(alice);
        assertTrue(paymentToken.transfer(address(authorizer), 0.5e18));

        assertEq(0.5e18, paymentToken.balanceOf(alice), "Alice should have 0.5e18 tokens after transfer to authorizer");
        assertEq(
            1e27 - 1e18, paymentToken.balanceOf(bob), "Bob should have 1e18 less tokens after transfer to authorizer"
        );
        assertEq(
            0.5e18,
            paymentToken.balanceOf(address(authorizer)),
            "Authorizer should have 0.5e18 tokens after transfer to authorizer"
        );

        vm.prank(anon);
        authorizer.sendPaymentToOwner();

        assertEq(0.5e18, paymentToken.balanceOf(alice), "Alice should have 0.5e18 tokens after sendPaymentToOwner 2");
        assertEq(
            1e27 - 0.5e18,
            paymentToken.balanceOf(bob),
            "Bob should have 1e27 - 0.5e18 tokens after sendPaymentToOwner 2"
        );
        assertEq(
            0,
            paymentToken.balanceOf(address(authorizer)),
            "Authorizer should have no tokens after sendPaymentToOwner 2"
        );
    }
}
