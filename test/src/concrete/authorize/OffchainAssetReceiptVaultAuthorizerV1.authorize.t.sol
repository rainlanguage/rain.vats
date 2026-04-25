// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultAuthorizerV1Test} from "test/abstract/OffchainAssetReceiptVaultAuthorizerV1Test.sol";

import {
    OffchainAssetReceiptVaultAuthorizerV1,
    OffchainAssetReceiptVaultAuthorizerV1Config,
    TRANSFER_SHARES,
    TRANSFER_RECEIPT,
    CERTIFY,
    CONFISCATE_RECEIPT,
    CONFISCATE_SHARES,
    DEPOSIT,
    WITHDRAW,
    CertificationExpired
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {TransferSharesStateChange, TransferReceiptStateChange} from "src/concrete/vault/OffchainAssetReceiptVault.sol";

contract OffchainAssetReceiptVaultAuthorizerV1AuthorizeTest is OffchainAssetReceiptVaultAuthorizerV1Test {
    function newAuthorizer(address initialAdmin) internal returns (OffchainAssetReceiptVaultAuthorizerV1) {
        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        OffchainAssetReceiptVaultAuthorizerV1Config memory config =
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin});

        CloneFactory factory = new CloneFactory();
        return
            OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), abi.encode(config)));
    }

    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeUnauthorized(
        address sender,
        address initialAdmin,
        address user,
        bytes32 permission,
        bytes memory data
    ) external {
        vm.assume(initialAdmin != address(0));
        // The sender must not be the admin, otherwise they may hold roles
        // that make the authorize call succeed instead of reverting.
        vm.assume(sender != initialAdmin);
        // The user must not be the admin either — `authorize` returns early
        // when `hasRole(permission, user)` is true, and the admin holds
        // every *_ADMIN role granted in `initialize`. With user == admin
        // and a permission matching one of those admin roles, the call
        // succeeds even though the sender has no role.
        vm.assume(user != initialAdmin);
        OffchainAssetReceiptVaultAuthorizerV1 authorizer = newAuthorizer(initialAdmin);

        checkDefaultOffchainAssetReceiptVaultAuthorizerV1AuthorizeUnauthorized(
            authorizer, sender, user, permission, data
        );
    }

    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeAuthorized(
        address admin,
        address user,
        bytes memory data,
        address sender
    ) external {
        vm.assume(admin != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizer = newAuthorizer(admin);

        bytes32[] memory roles = new bytes32[](5);
        roles[0] = CERTIFY;
        roles[1] = CONFISCATE_SHARES;
        roles[2] = CONFISCATE_RECEIPT;
        roles[3] = DEPOSIT;
        roles[4] = WITHDRAW;

        checkRolesAuthorized(authorizer, admin, sender, user, data, roles);
    }

    /// When certification is NOT expired then all TRANSFER_SHARES are
    /// authorized.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferSharesCertifyNotExpired(
        address sender,
        address initialAdmin,
        address user,
        address from,
        address to,
        uint256 amount
    ) external {
        vm.assume(initialAdmin != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizer = newAuthorizer(initialAdmin);

        checkAuthorizeTransferSharesCertifyNotExpired(authorizer, sender, user, from, to, amount);
    }

    /// When certification is NOT expired then all TRANSFER_RECEIPT are
    /// authorized.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferReceiptCertifyNotExpired(
        address sender,
        address initialAdmin,
        address user,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        vm.assume(initialAdmin != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizer = newAuthorizer(initialAdmin);

        checkAuthorizeTransferReceiptCertifyNotExpired(authorizer, sender, user, from, to, ids, amounts);
    }

    /// When certification IS expired and this is not a mint or burn, and there
    /// are no other roles, then TRANSFER_SHARES is unauthorized.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferSharesCertifyExpired(
        address initialAdmin,
        address user,
        address from,
        address to,
        uint256 amount
    ) external {
        vm.assume(initialAdmin != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizer = newAuthorizer(initialAdmin);

        checkAuthorizeTransferSharesCertifyExpired(authorizer, initialAdmin, user, from, to, amount);
    }

    /// When certification IS expired and this is not a mint or burn, and there
    /// are no other roles, then TRANSFER_RECEIPT is unauthorized.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferReceiptCertifyExpired(
        address initialAdmin,
        address user,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        vm.assume(initialAdmin != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizer = newAuthorizer(initialAdmin);

        checkAuthorizeTransferReceiptCertifyExpired(authorizer, initialAdmin, user, from, to, ids, amounts);
    }

    /// If the certification is expired and this is a mint then TRANSFER_SHARES
    /// is authorized depending on the DEPOSIT role.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferSharesCertifyExpiredMintBurn(
        address initialAdmin,
        address user,
        address to,
        uint256 amount
    ) external {
        vm.assume(initialAdmin != address(0));
        vm.assume(to != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizer = newAuthorizer(initialAdmin);

        bytes memory data = abi.encode(
            TransferSharesStateChange({from: address(0), to: to, amount: amount, isCertificationExpired: true})
        );

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), to));
        authorizer.authorize(user, TRANSFER_SHARES, data);

        // Withdraw does nothing.
        vm.prank(initialAdmin);
        authorizer.grantRole(WITHDRAW, to);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), to));
        authorizer.authorize(user, TRANSFER_SHARES, data);

        vm.prank(initialAdmin);
        authorizer.grantRole(DEPOSIT, to);
        vm.stopPrank();

        authorizer.authorize(user, TRANSFER_SHARES, data);
    }

    /// If the certification is expired and this is a mint then TRANSFER_RECEIPT
    /// is authorized depending on the DEPOSIT role.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferReceiptCertifyExpiredMintBurn(
        address initialAdmin,
        address user,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        vm.assume(initialAdmin != address(0));
        vm.assume(to != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizer = newAuthorizer(initialAdmin);

        bytes memory data = abi.encode(
            TransferReceiptStateChange({
                from: address(0), to: to, ids: ids, amounts: amounts, isCertificationExpired: true
            })
        );

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), to));
        authorizer.authorize(user, TRANSFER_RECEIPT, data);

        // Withdraw does nothing.
        vm.prank(initialAdmin);
        authorizer.grantRole(WITHDRAW, to);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), to));
        authorizer.authorize(user, TRANSFER_RECEIPT, data);

        vm.prank(initialAdmin);
        authorizer.grantRole(DEPOSIT, to);
        vm.stopPrank();

        authorizer.authorize(user, TRANSFER_RECEIPT, data);
    }

    /// If the certification is expired and this is a burn then TRANSFER_SHARES
    /// is authorized depending on the WITHDRAW role.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferSharesCertifyExpiredBurn(
        address initialAdmin,
        address user,
        address from,
        uint256 amount
    ) external {
        vm.assume(initialAdmin != address(0));
        vm.assume(from != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizer = newAuthorizer(initialAdmin);

        bytes memory data = abi.encode(
            TransferSharesStateChange({from: from, to: address(0), amount: amount, isCertificationExpired: true})
        );

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, from, address(0)));
        authorizer.authorize(user, TRANSFER_SHARES, data);

        // Deposit does nothing.
        vm.prank(initialAdmin);
        authorizer.grantRole(DEPOSIT, from);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, from, address(0)));
        authorizer.authorize(user, TRANSFER_SHARES, data);

        vm.prank(initialAdmin);
        authorizer.grantRole(WITHDRAW, from);
        vm.stopPrank();

        authorizer.authorize(user, TRANSFER_SHARES, data);
    }

    /// If the certification is expired and this is a burn then TRANSFER_RECEIPT
    /// is authorized depending on the WITHDRAW role.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferReceiptCertifyExpiredBurn(
        address initialAdmin,
        address user,
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        vm.assume(initialAdmin != address(0));
        vm.assume(from != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizer = newAuthorizer(initialAdmin);

        bytes memory data = abi.encode(
            TransferReceiptStateChange({
                from: from, to: address(0), ids: ids, amounts: amounts, isCertificationExpired: true
            })
        );

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, from, address(0)));
        authorizer.authorize(user, TRANSFER_RECEIPT, data);

        // Deposit does nothing.
        vm.prank(initialAdmin);
        authorizer.grantRole(DEPOSIT, from);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, from, address(0)));
        authorizer.authorize(user, TRANSFER_RECEIPT, data);

        vm.prank(initialAdmin);
        authorizer.grantRole(WITHDRAW, from);
        vm.stopPrank();

        authorizer.authorize(user, TRANSFER_RECEIPT, data);
    }
}
