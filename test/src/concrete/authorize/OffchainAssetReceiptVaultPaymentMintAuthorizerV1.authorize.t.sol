// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultAuthorizerV1Test} from "test/abstract/OffchainAssetReceiptVaultAuthorizerV1Test.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1,
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config,
    Unauthorized
} from "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {
    CERTIFY,
    CONFISCATE_SHARES,
    CONFISCATE_RECEIPT,
    DEPOSIT,
    DEPOSIT_ADMIN,
    WITHDRAW_ADMIN,
    WITHDRAW
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {VerifyAlwaysApproved} from "rain.verify.interface/concrete/VerifyAlwaysApproved.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

contract OffchainAssetReceiptVaultPaymentMintAuthorizerV1IERC165Test is OffchainAssetReceiptVaultAuthorizerV1Test {
    using Strings for address;

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

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1UnauthorizedCaller(
        address receiptVault,
        address owner,
        address paymentToken,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply,
        address user,
        bytes32 permission,
        bytes calldata data,
        address caller
    ) external {
        vm.assume(receiptVault != address(0));
        vm.assume(owner != address(0));
        vm.assume(paymentToken != address(0));
        vm.assume(maxSharesSupply > 0);
        vm.assume(caller != receiptVault);
        vm.assume(uint160(caller) > type(uint160).max / 2);
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, owner, paymentToken, paymentTokenDecimals, maxSharesSupply);

        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, user, permission, data));
        vm.prank(caller);
        authorizer.authorize(user, permission, data);
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1AuthorizeUnauthorized(
        address receiptVault,
        address owner,
        address paymentToken,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply,
        address sender,
        address user,
        bytes32 permission,
        bytes memory data
    ) external {
        vm.assume(owner != address(0));
        vm.assume(receiptVault != address(0));
        vm.assume(uint160(paymentToken) > type(uint160).max / 2);
        vm.assume(maxSharesSupply > 0);
        vm.assume(uint160(sender) > type(uint160).max / 2);
        // The first check in `authorize` only reverts when sender is NOT the
        // receipt vault. With sender == receiptVault the call falls into the
        // DEPOSIT / TRANSFER_* branches; an empty `data` then trips
        // `abi.decode` and reverts without the Unauthorized error selector,
        // which fails the test's `expectRevert(Unauthorized.selector)`.
        vm.assume(sender != receiptVault);
        checkDefaultOffchainAssetReceiptVaultAuthorizerV1AuthorizeUnauthorized(
            newAuthorizer(receiptVault, owner, paymentToken, paymentTokenDecimals, maxSharesSupply),
            sender,
            user,
            permission,
            data
        );
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1RolesAuthorized(
        address receiptVault,
        address owner,
        address paymentToken,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply,
        address user,
        bytes memory data
    ) external {
        vm.assume(owner != address(0));
        vm.assume(receiptVault != address(0));
        vm.assume(uint160(paymentToken) > type(uint160).max / 2);
        vm.assume(maxSharesSupply > 0);
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, owner, paymentToken, paymentTokenDecimals, maxSharesSupply);
        bytes32[] memory roles = new bytes32[](3);
        roles[0] = CERTIFY;
        roles[1] = CONFISCATE_SHARES;
        roles[2] = CONFISCATE_RECEIPT;
        checkRolesAuthorized(authorizer, owner, receiptVault, user, data, roles);
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1AuthorizeTransferSharesCertifyNotExpired(
        address receiptVault,
        address owner,
        address paymentToken,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply,
        address user,
        address from,
        address to,
        uint256 amount
    ) external {
        vm.assume(owner != address(0));
        vm.assume(receiptVault != address(0));
        vm.assume(uint160(paymentToken) > type(uint160).max / 2);
        vm.assume(maxSharesSupply > 0);
        vm.assume(user != address(0));
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, owner, paymentToken, paymentTokenDecimals, maxSharesSupply);
        checkAuthorizeTransferSharesCertifyNotExpired(authorizer, receiptVault, user, from, to, amount);
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1AuthorizeTransferReceiptCertifyNotExpired(
        address receiptVault,
        address owner,
        address paymentToken,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply,
        address user,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        vm.assume(owner != address(0));
        vm.assume(receiptVault != address(0));
        vm.assume(uint160(paymentToken) > type(uint160).max / 2);
        vm.assume(maxSharesSupply > 0);
        vm.assume(user != address(0));
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, owner, paymentToken, paymentTokenDecimals, maxSharesSupply);
        checkAuthorizeTransferReceiptCertifyNotExpired(authorizer, receiptVault, user, from, to, ids, amounts);
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1AuthorizeTransferSharesCertifyExpired(
        address receiptVault,
        address owner,
        address paymentToken,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply,
        address user,
        address from,
        address to,
        uint256 amount
    ) external {
        vm.assume(owner != address(0));
        vm.assume(receiptVault != address(0));
        vm.assume(uint160(paymentToken) > type(uint160).max / 2);
        vm.assume(maxSharesSupply > 0);
        vm.assume(user != address(0));
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, owner, paymentToken, paymentTokenDecimals, maxSharesSupply);
        checkAuthorizeTransferSharesCertifyExpired(authorizer, receiptVault, user, from, to, amount);
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1AuthorizeTransferReceiptCertifyExpired(
        address receiptVault,
        address owner,
        address paymentToken,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply,
        address user,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        vm.assume(owner != address(0));
        vm.assume(receiptVault != address(0));
        vm.assume(uint160(paymentToken) > type(uint160).max / 2);
        vm.assume(maxSharesSupply > 0);
        vm.assume(user != address(0));
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, owner, paymentToken, paymentTokenDecimals, maxSharesSupply);
        checkAuthorizeTransferReceiptCertifyExpired(authorizer, receiptVault, user, from, to, ids, amounts);
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1AdminCannotGrantDeposit(
        address receiptVault,
        address owner,
        address paymentToken,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply,
        address user
    ) external {
        vm.assume(owner != address(0));
        vm.assume(receiptVault != address(0));
        vm.assume(uint160(paymentToken) > type(uint160).max / 2);
        vm.assume(maxSharesSupply > 0);
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, owner, paymentToken, paymentTokenDecimals, maxSharesSupply);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, owner, DEPOSIT_ADMIN, "")
        );
        authorizer.grantRole(DEPOSIT, user);
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1AdminCannotGrantWithdraw(
        address receiptVault,
        address owner,
        address paymentToken,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply,
        address user
    ) external {
        vm.assume(owner != address(0));
        vm.assume(receiptVault != address(0));
        vm.assume(uint160(paymentToken) > type(uint160).max / 2);
        vm.assume(maxSharesSupply > 0);
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, owner, paymentToken, paymentTokenDecimals, maxSharesSupply);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, owner, WITHDRAW_ADMIN, "")
        );
        authorizer.grantRole(WITHDRAW, user);
    }
}
