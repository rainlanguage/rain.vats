// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";

import {
    OffchainAssetReceiptVaultAuthorizerV1,
    OffchainAssetReceiptVaultAuthorizerV1Config,
    CERTIFY_ADMIN,
    CONFISCATE_SHARES_ADMIN,
    CONFISCATE_RECEIPT_ADMIN,
    DEPOSIT_ADMIN,
    WITHDRAW_ADMIN,
    CERTIFY,
    CONFISCATE_SHARES,
    CONFISCATE_RECEIPT,
    DEPOSIT,
    WITHDRAW,
    ZeroInitialAdmin
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {CloneFactory} from "rain-factory-0.1.5/src/concrete/CloneFactory.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.6.1/proxy/utils/Initializable.sol";

contract OffchainAssetReceiptVaultAuthorizerV1ConstructTest is Test {
    function testOffchainAssetReceiptVaultAuthorizerV1Construct(address initialAdmin) external {
        OffchainAssetReceiptVaultAuthorizerV1 authorizer = new OffchainAssetReceiptVaultAuthorizerV1();

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        authorizer.initialize(abi.encode(OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin})));
    }

    function testOffchainAssetReceiptVaultAuthorizerV1Initialize(address initialAdmin, bytes32 badRole) external {
        vm.assume(initialAdmin != address(0));
        vm.assume(badRole != CERTIFY_ADMIN);
        vm.assume(badRole != CONFISCATE_SHARES_ADMIN);
        vm.assume(badRole != CONFISCATE_RECEIPT_ADMIN);
        vm.assume(badRole != DEPOSIT_ADMIN);
        vm.assume(badRole != WITHDRAW_ADMIN);
        vm.assume(badRole != CERTIFY);
        vm.assume(badRole != CONFISCATE_SHARES);
        vm.assume(badRole != CONFISCATE_RECEIPT);
        vm.assume(badRole != DEPOSIT);
        vm.assume(badRole != WITHDRAW);

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        bytes memory initData = abi.encode(OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin}));

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        authorizerImplementation.initialize(initData);

        CloneFactory factory = new CloneFactory();

        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(factory.cloneDeterministic(address(authorizerImplementation), initData, bytes32(0)));

        vm.assertTrue(authorizer.hasRole(CERTIFY_ADMIN, initialAdmin));
        vm.assertTrue(authorizer.hasRole(CONFISCATE_SHARES_ADMIN, initialAdmin));
        vm.assertTrue(authorizer.hasRole(CONFISCATE_RECEIPT_ADMIN, initialAdmin));
        vm.assertTrue(authorizer.hasRole(DEPOSIT_ADMIN, initialAdmin));
        vm.assertTrue(authorizer.hasRole(WITHDRAW_ADMIN, initialAdmin));

        vm.assertTrue(!authorizer.hasRole(CERTIFY, initialAdmin));
        vm.assertTrue(!authorizer.hasRole(CONFISCATE_SHARES, initialAdmin));
        vm.assertTrue(!authorizer.hasRole(CONFISCATE_RECEIPT, initialAdmin));
        vm.assertTrue(!authorizer.hasRole(DEPOSIT, initialAdmin));
        vm.assertTrue(!authorizer.hasRole(WITHDRAW, initialAdmin));
        vm.assertTrue(!authorizer.hasRole(badRole, initialAdmin));
    }

    function testOffchainAssetReceiptVaultAuthorizerV1InitializeZeroAdmin() external {
        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        bytes memory initData = abi.encode(OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: address(0)}));

        CloneFactory factory = new CloneFactory();

        vm.expectRevert(ZeroInitialAdmin.selector);
        OffchainAssetReceiptVaultAuthorizerV1(factory.cloneDeterministic(address(authorizerImplementation), initData, bytes32(0)));
    }
}
