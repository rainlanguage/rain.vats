// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    OffchainAssetReceiptVaultAuthorizerV1Config,
    OffchainAssetReceiptVaultAuthorizerV1ConfigV2,
    OFFCHAIN_ASSET_RECEIPT_VAULT_AUTHORIZER_V1_CONFIG_V2_TAG,
    UnknownAuthorizerConfigVersion,
    NonCanonicalAuthorizerConfig,
    NonCanonicalInitialAdmin,
    CERTIFY_ADMIN,
    CONFISCATE_SHARES_ADMIN,
    CONFISCATE_RECEIPT_ADMIN,
    DEPOSIT_ADMIN,
    WITHDRAW_ADMIN
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {TestCloneFactory} from "rain-factory-0.2.10/src/test/TestCloneFactory.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.7.0/proxy/utils/Initializable.sol";
import {IConfigRegistryV5} from "rain-deploy-0.1.30/src/interface/IConfigRegistryV5.sol";
import {LibConfigRegistry} from "rain-deploy-0.1.30/src/lib/LibConfigRegistry.sol";
import {LibConfigRegistryDeploy} from "rain-deploy-0.1.30/src/lib/LibConfigRegistryDeploy.sol";

contract OffchainAssetReceiptVaultAuthorizerV1InitializeTest is OffchainAssetReceiptVaultTest {
    bytes32 internal constant ADMIN_NAME = keccak256("authorizer-initial-admin");
    address internal constant ADMIN = address(uint160(uint256(keccak256("admin"))));

    TestCloneFactory internal immutable iFactory;

    constructor() {
        iFactory = new TestCloneFactory();
    }

    /// Moves the clock a second first, since the registry refuses a rebind at
    /// the moment of the binding it replaces.
    function bindAdmin(string memory valueType, bytes memory value) internal {
        vm.warp(block.timestamp + 1);
        vm.prank(VAULT_AUTHORITY);
        IConfigRegistryV5(LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_ADDRESS)
            .registerV5(VAULT_AUTHORITY, ADMIN_NAME, valueType, value, "");
    }

    function bindAdmin(address admin) internal {
        bindAdmin("address", abi.encode(admin));
    }

    function adminConfig() internal pure returns (bytes memory) {
        return encodeAuthorizerConfig(VAULT_AUTHORITY, ADMIN_NAME);
    }

    function clone(bytes memory data) internal returns (OffchainAssetReceiptVaultAuthorizerV1) {
        return OffchainAssetReceiptVaultAuthorizerV1(
            iFactory.cloneDeterministicOpenSalt(address(iAuthorizerImplementation), data, bytes32(0))
        );
    }

    function prefix(bytes memory data, uint256 length) internal pure returns (bytes memory) {
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = data[i];
        }
        return result;
    }

    function assertAdminRoles(OffchainAssetReceiptVaultAuthorizerV1 authorizer, address account, bool held)
        internal
        view
    {
        bytes32[5] memory roles =
            [CERTIFY_ADMIN, CONFISCATE_SHARES_ADMIN, CONFISCATE_RECEIPT_ADMIN, DEPOSIT_ADMIN, WITHDRAW_ADMIN];
        for (uint256 i = 0; i < roles.length; i++) {
            assertEq(authorizer.hasRole(roles[i], account), held);
        }
    }

    /// Data shorter than a word, including a cut-down tag, reverts as an
    /// unknown version zero.
    function testInitializeShortData(uint256 length) external {
        length = bound(length, 0, 0x1f);
        bindAdmin(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(UnknownAuthorizerConfigVersion.selector, bytes32(0)));
        clone(prefix(adminConfig(), length));
    }

    /// The tag with less than a whole config after it is a non-canonical
    /// config.
    function testInitializeTruncatedConfig(uint256 length) external {
        length = bound(length, 0x20, adminConfig().length - 1);
        bindAdmin(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalAuthorizerConfig.selector));
        clone(prefix(adminConfig(), length));
    }

    /// Data leading with any word but the V2 tag reverts naming that word,
    /// even when the rest is a valid config.
    function testInitializeUnknownConfigVersion(bytes32 version) external {
        vm.assume(version != OFFCHAIN_ASSET_RECEIPT_VAULT_AUTHORIZER_V1_CONFIG_V2_TAG);
        bindAdmin(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(UnknownAuthorizerConfigVersion.selector, version));
        clone(
            abi.encode(
                version,
                OffchainAssetReceiptVaultAuthorizerV1ConfigV2({
                    authority: VAULT_AUTHORITY, initialAdminName: ADMIN_NAME
                })
            )
        );
    }

    /// The V2 config without its tag reverts: its first word, the authority,
    /// is not the tag.
    function testInitializeUntaggedConfig() external {
        bindAdmin(ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(UnknownAuthorizerConfigVersion.selector, bytes32(uint256(uint160(VAULT_AUTHORITY))))
        );
        clone(
            abi.encode(
                OffchainAssetReceiptVaultAuthorizerV1ConfigV2({
                    authority: VAULT_AUTHORITY, initialAdminName: ADMIN_NAME
                })
            )
        );
    }

    /// Init data naming the admin directly, as before the registry, is never
    /// read as a binding.
    function testInitializeUnversionedAdminConfig(address admin) external {
        vm.expectRevert(
            abi.encodeWithSelector(UnknownAuthorizerConfigVersion.selector, bytes32(uint256(uint160(admin))))
        );
        clone(abi.encode(OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: admin})));
    }

    /// Trailing bytes after the canonical config revert, so one config cannot
    /// initialize clones at more than one open-salt address.
    function testInitializeTrailingConfigBytes(bytes memory trailing) external {
        vm.assume(trailing.length > 0);
        bindAdmin(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalAuthorizerConfig.selector));
        clone(bytes.concat(adminConfig(), trailing));
    }

    /// Config data as long as the canonical encoding but with dirty high bits
    /// in the authority word is a non-canonical config.
    function testInitializeDirtyAuthorityBits(uint96 dirt) external {
        vm.assume(dirt != 0);
        bindAdmin(ADMIN);
        bytes memory data = adminConfig();
        bytes12 dirtBytes = bytes12(dirt);
        for (uint256 i = 0; i < 12; i++) {
            data[0x20 + i] = dirtBytes[i];
        }
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalAuthorizerConfig.selector));
        clone(data);
    }

    /// A binding with bytes after the canonical address reverts naming the
    /// binding.
    function testInitializeNonCanonicalInitialAdminBinding(bytes memory trailing) external {
        vm.assume(trailing.length > 0);
        bindAdmin("address", bytes.concat(abi.encode(ADMIN), trailing));
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalInitialAdmin.selector, VAULT_AUTHORITY, ADMIN_NAME));
        clone(adminConfig());
    }

    /// A one-word binding with bits above the address reverts naming the
    /// binding.
    function testInitializeDirtyInitialAdminBinding(uint96 dirt) external {
        vm.assume(dirt != 0);
        bindAdmin("address", abi.encode(uint256(uint160(ADMIN)) | (uint256(dirt) << 160)));
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalInitialAdmin.selector, VAULT_AUTHORITY, ADMIN_NAME));
        clone(adminConfig());
    }

    /// A binding shorter than a word reverts naming the binding.
    function testInitializeShortInitialAdminBinding(uint256 length) external {
        length = bound(length, 1, 0x1f);
        bindAdmin("address", prefix(abi.encode(ADMIN), length));
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalInitialAdmin.selector, VAULT_AUTHORITY, ADMIN_NAME));
        clone(adminConfig());
    }

    function testInitializeUnboundInitialAdminName(bytes32 name) external {
        vm.assume(name != VAULT_BEACON_NAME && name != RECEIPT_BEACON_NAME);
        vm.expectRevert(abi.encodeWithSelector(IConfigRegistryV5.NameNotRegistered.selector, VAULT_AUTHORITY, name));
        clone(encodeAuthorizerConfig(VAULT_AUTHORITY, name));
    }

    /// The name bound under one authority is unbound under any other.
    function testInitializeOtherAuthority(address authority) external {
        vm.assume(authority != VAULT_AUTHORITY);
        bindAdmin(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(IConfigRegistryV5.NameNotRegistered.selector, authority, ADMIN_NAME));
        clone(encodeAuthorizerConfig(authority, ADMIN_NAME));
    }

    function testInitializeInitialAdminValueTypeMismatch(string memory valueType) external {
        vm.assume(bytes(valueType).length > 0);
        vm.assume(keccak256(bytes(valueType)) != keccak256("address"));
        bindAdmin(valueType, abi.encode(ADMIN));
        vm.expectRevert(
            abi.encodeWithSelector(
                LibConfigRegistry.ValueTypeMismatch.selector,
                VAULT_AUTHORITY,
                ADMIN_NAME,
                keccak256("address"),
                keccak256(bytes(valueType))
            )
        );
        clone(adminConfig());
    }

    function testInitializeNoRegistry() external {
        bindAdmin(ADMIN);
        vm.etch(LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_ADDRESS, "");
        vm.expectRevert(
            abi.encodeWithSelector(
                LibConfigRegistry.UnexpectedConfigRegistryCodeHash.selector,
                LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_CODEHASH,
                bytes32(0)
            )
        );
        clone(adminConfig());
    }

    /// The binding is read once: a rebind after initialize moves no roles.
    function testRebindAfterInitializeMovesNoRoles(address admin, address nextAdmin) external {
        vm.assume(admin != address(0) && nextAdmin != address(0) && admin != nextAdmin);
        bindAdmin(admin);
        OffchainAssetReceiptVaultAuthorizerV1 authorizer = clone(adminConfig());
        bindAdmin(nextAdmin);

        assertAdminRoles(authorizer, admin, true);
        assertAdminRoles(authorizer, nextAdmin, false);
    }

    /// The same init data puts the clone at one address whatever admin the
    /// chain binds, and each clone's admin is its own chain's binding.
    function testOneAddressAcrossInitialAdminBindings(address adminA, address adminB) external {
        vm.assume(adminA != address(0) && adminB != address(0) && adminA != adminB);
        bytes memory data = adminConfig();
        address predicted =
            iFactory.predictDeterministicAddressOpenSalt(address(iAuthorizerImplementation), data, bytes32(0));

        uint256 snapshot = vm.snapshotState();
        bindAdmin(adminA);
        OffchainAssetReceiptVaultAuthorizerV1 authorizerA = clone(data);
        assertEq(address(authorizerA), predicted);
        assertAdminRoles(authorizerA, adminA, true);
        assertAdminRoles(authorizerA, adminB, false);

        assertTrue(vm.revertToState(snapshot));
        bindAdmin(adminB);
        OffchainAssetReceiptVaultAuthorizerV1 authorizerB = clone(data);
        assertEq(address(authorizerB), predicted);
        assertAdminRoles(authorizerB, adminB, true);
        assertAdminRoles(authorizerB, adminA, false);
    }

    /// An initialized clone cannot be initialized again, with its own data or
    /// any other.
    function testInitializeTwice(bytes memory data) external {
        bindAdmin(ADMIN);
        OffchainAssetReceiptVaultAuthorizerV1 authorizer = clone(adminConfig());
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        authorizer.initialize(adminConfig());
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        authorizer.initialize(data);
    }

    function testInitializeImplementation() external {
        bindAdmin(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        iAuthorizerImplementation.initialize(adminConfig());
    }
}
