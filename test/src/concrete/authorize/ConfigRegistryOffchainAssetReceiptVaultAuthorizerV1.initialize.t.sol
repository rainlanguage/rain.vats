// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.7.0/proxy/utils/Initializable.sol";
import {TestCloneFactory} from "rain-factory-0.2.4/src/test/TestCloneFactory.sol";
import {IConfigRegistryV3} from "rain-deploy-0.1.21/src/interface/IConfigRegistryV3.sol";
import {LibConfigRegistry} from "rain-deploy-0.1.21/src/lib/LibConfigRegistry.sol";
import {LibConfigRegistryDeploy} from "rain-deploy-0.1.21/src/lib/LibConfigRegistryDeploy.sol";
import {
    RUNTIME_CODE as CONFIG_REGISTRY_RUNTIME_CODE
} from "rain-deploy-0.1.21/src/generated/candidate/ConfigRegistry.sol";

import {
    CERTIFY_ADMIN,
    CONFISCATE_SHARES_ADMIN,
    CONFISCATE_RECEIPT_ADMIN,
    DEPOSIT_ADMIN,
    WITHDRAW_ADMIN,
    ZeroInitialAdmin
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {
    ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1,
    ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1Config
} from "src/concrete/authorize/ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1.sol";

contract ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1InitializeTest is Test {
    address internal constant AUTHORITY = address(uint160(uint256(keccak256("authority"))));
    bytes32 internal constant ADMIN_NAME = keccak256("authorizer-admin");
    bytes32 internal constant SALT = keccak256("salt");

    ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1 internal implementation;
    TestCloneFactory internal factory;

    function setUp() external {
        vm.etch(LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_ADDRESS, CONFIG_REGISTRY_RUNTIME_CODE);
        implementation = new ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1();
        factory = new TestCloneFactory();
        vm.warp(1_000_000_000);
    }

    function initData() internal pure returns (bytes memory) {
        return abi.encode(
            ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1Config({authority: AUTHORITY, adminName: ADMIN_NAME})
        );
    }

    function bind(address authority, bytes32 name, bytes memory value) internal {
        vm.prank(authority);
        IConfigRegistryV3(LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_ADDRESS).registerV3(authority, name, value);
    }

    function clone() internal returns (ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1) {
        return ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1(
            factory.cloneDeterministicOpenSalt(address(implementation), initData(), SALT)
        );
    }

    function assertAdmin(ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1 authorizer, address admin, bool held)
        internal
        view
    {
        assertEq(authorizer.hasRole(CERTIFY_ADMIN, admin), held);
        assertEq(authorizer.hasRole(CONFISCATE_SHARES_ADMIN, admin), held);
        assertEq(authorizer.hasRole(CONFISCATE_RECEIPT_ADMIN, admin), held);
        assertEq(authorizer.hasRole(DEPOSIT_ADMIN, admin), held);
        assertEq(authorizer.hasRole(WITHDRAW_ADMIN, admin), held);
    }

    function testInitializeGrantsTheBoundAdmin(address admin) external {
        vm.assume(admin != address(0));
        bind(AUTHORITY, ADMIN_NAME, abi.encode(admin));
        assertAdmin(clone(), admin, true);
    }

    function testInitializeReadsTheBindingOnce(address admin, address rebound) external {
        vm.assume(admin != address(0) && rebound != admin);
        bind(AUTHORITY, ADMIN_NAME, abi.encode(admin));
        ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1 authorizer = clone();
        vm.warp(block.timestamp + 1);
        bind(AUTHORITY, ADMIN_NAME, abi.encode(rebound));
        assertAdmin(authorizer, admin, true);
        assertAdmin(authorizer, rebound, false);
    }

    function testInitializeOneAddressForEveryAdmin(address a, address b) external {
        vm.assume(a != address(0) && b != address(0) && a != b);
        uint256 snapshot = vm.snapshotState();
        bind(AUTHORITY, ADMIN_NAME, abi.encode(a));
        ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1 first = clone();
        assertAdmin(first, a, true);
        vm.revertToState(snapshot);
        bind(AUTHORITY, ADMIN_NAME, abi.encode(b));
        ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1 second = clone();
        assertAdmin(second, b, true);
        assertEq(address(first), address(second));
    }

    function testInitializeUnboundReverts() external {
        vm.expectRevert(abi.encodeWithSelector(IConfigRegistryV3.NameNotRegistered.selector, AUTHORITY, ADMIN_NAME));
        clone();
    }

    function testInitializeOtherAuthorityReverts(address other, address admin) external {
        vm.assume(other != AUTHORITY && other != address(0));
        vm.assume(admin != address(0));
        bind(other, ADMIN_NAME, abi.encode(admin));
        vm.expectRevert(abi.encodeWithSelector(IConfigRegistryV3.NameNotRegistered.selector, AUTHORITY, ADMIN_NAME));
        clone();
    }

    function testInitializeOtherNameReverts(bytes32 other, address admin) external {
        vm.assume(other != ADMIN_NAME);
        vm.assume(admin != address(0));
        bind(AUTHORITY, other, abi.encode(admin));
        vm.expectRevert(abi.encodeWithSelector(IConfigRegistryV3.NameNotRegistered.selector, AUTHORITY, ADMIN_NAME));
        clone();
    }

    function testInitializeZeroAdminReverts() external {
        bind(AUTHORITY, ADMIN_NAME, abi.encode(address(0)));
        vm.expectRevert(abi.encodeWithSelector(ZeroInitialAdmin.selector));
        clone();
    }

    function testInitializeUnexpectedRegistryReverts(address admin) external {
        vm.assume(admin != address(0));
        bind(AUTHORITY, ADMIN_NAME, abi.encode(admin));
        vm.etch(LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_ADDRESS, hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                LibConfigRegistry.UnexpectedConfigRegistryCodeHash.selector,
                LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_CODEHASH,
                keccak256(hex"00")
            )
        );
        clone();
    }

    function testInitializeTwiceReverts(address admin) external {
        vm.assume(admin != address(0));
        bind(AUTHORITY, ADMIN_NAME, abi.encode(admin));
        ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1 authorizer = clone();
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        authorizer.initialize(initData());
    }

    function testImplementationCannotInitialize(address admin) external {
        vm.assume(admin != address(0));
        bind(AUTHORITY, ADMIN_NAME, abi.encode(admin));
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        implementation.initialize(initData());
    }
}
