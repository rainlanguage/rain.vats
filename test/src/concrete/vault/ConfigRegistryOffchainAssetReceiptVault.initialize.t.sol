// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    ConfigRegistryOffchainAssetReceiptVaultTest
} from "../../../abstract/ConfigRegistryOffchainAssetReceiptVaultTest.sol";
import {
    ConfigRegistryOffchainAssetReceiptVault,
    ConfigRegistryOffchainAssetReceiptVaultConfigV1,
    AuthorizerIndexOutOfRange,
    NonCanonicalConfig,
    UnknownConfigVersion,
    VaultNotBeaconProxy,
    ReceiptBeaconOwnerMismatch,
    ReceiptMetadataReverts,
    CONFIG_REGISTRY_RBAC_MIN_AGE
} from "../../../../src/concrete/vault/ConfigRegistryOffchainAssetReceiptVault.sol";
import {
    OffchainAssetReceiptVaultRbacV1,
    NonCanonicalRbac
} from "../../../../src/lib/LibOffchainAssetReceiptVaultRbac.sol";
import {
    IncompatibleAuthorizer,
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV2
} from "../../../../src/concrete/vault/OffchainAssetReceiptVault.sol";
import {
    CONFIG_REGISTRY_OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V1_TAG
} from "../../../../src/interface/IConfigRegistryOffchainAssetReceiptVaultV1.sol";
import {ReceiptVaultConfigV2} from "../../../../src/abstract/ReceiptVault.sol";
import {BeaconProxy} from "@openzeppelin-contracts-5.7.0/proxy/beacon/BeaconProxy.sol";
import {ZeroInitialAdmin} from "../../../../src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {InitializeReceiptFailed} from "../../../../src/error/ErrDeployer.sol";
import {IAuthorizeV1} from "../../../../src/interface/IAuthorizeV1.sol";
import {Receipt as ReceiptContract} from "../../../../src/concrete/receipt/Receipt.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {IBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/IBeacon.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.7.0/proxy/utils/Initializable.sol";
import {LibConfigRegistry} from "rain-deploy-0.1.19-main/src/lib/LibConfigRegistry.sol";
import {LibConfigRegistryDeploy} from "rain-deploy-0.1.19-main/src/lib/LibConfigRegistryDeploy.sol";
import {IConfigRegistryV2} from "rain-deploy-0.1.19-main/src/interface/IConfigRegistryV2.sol";
import {FailingInitializeReceipt} from "../../../concrete/FailingInitializeReceipt.sol";
import {OwnerlessBeacon} from "../../../concrete/OwnerlessBeacon.sol";
import {
    IConfigRegistryOffchainAssetReceiptVaultV1
} from "../../../../src/interface/IConfigRegistryOffchainAssetReceiptVaultV1.sol";
import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {Clones} from "@openzeppelin-contracts-5.7.0/proxy/Clones.sol";

contract ConfigRegistryOffchainAssetReceiptVaultInitializeTest is ConfigRegistryOffchainAssetReceiptVaultTest {
    function testInitializeWiresRolesFromRegistry(uint8 index) external {
        IAuthorizeV1[] memory authorizers = twoAuthorizers();
        uint256 authorizerIndex = uint256(index) % authorizers.length;
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: authorizers}));
        ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory vaultConfig = config(authorizerIndex);

        address predicted =
            iFactory.predictBeaconProxyAddressOpenSalt(address(iVaultBeacon), encodeConfig(vaultConfig), 0);
        vm.expectEmit(predicted);
        emit IConfigRegistryOffchainAssetReceiptVaultV1.ConfigRegistryOffchainAssetReceiptVaultInitializedV1(
            address(iFactory), vaultConfig, OWNER, authorizers[authorizerIndex]
        );
        ConfigRegistryOffchainAssetReceiptVault vault = deploy(vaultConfig, 0);

        assertEq(address(vault), predicted);
        assertEq(vault.owner(), OWNER);
        assertEq(address(vault.authorizer()), address(authorizers[authorizerIndex]));
        assertEq(vault.name(), vaultConfig.name);
        assertEq(vault.symbol(), vaultConfig.symbol);
        assertEq(vault.asset(), address(0));
        assertEq(address(vault.receipt()), vm.computeCreateAddress(address(vault), 1));
        assertEq(ReceiptContract(address(vault.receipt())).manager(), address(vault));
    }

    function testInitializeTwice() external {
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        ConfigRegistryOffchainAssetReceiptVault vault = deploy(config(0), 0);
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        vault.initialize(encodeConfig(config(0)));
    }

    /// A proxy already initialized as a plain vault cannot be initialized
    /// again after its beacon moves to this implementation.
    function testInitializeAfterUpgradeFromPlainVault() external {
        UpgradeableBeacon vaultBeacon = new UpgradeableBeacon(address(new OffchainAssetReceiptVault()), address(this));
        OffchainAssetReceiptVault proxy =
            OffchainAssetReceiptVault(payable(address(new BeaconProxy(address(vaultBeacon), ""))));
        ReceiptContract receipt = ReceiptContract(address(new BeaconProxy(address(iReceiptBeacon), "")));
        receipt.initialize(abi.encode(proxy));
        proxy.initialize(
            abi.encode(
                OffchainAssetReceiptVaultConfigV2({
                    initialAdmin: OWNER,
                    receiptVaultConfig: ReceiptVaultConfigV2({
                        asset: address(0), name: "a", symbol: "b", receipt: address(receipt)
                    })
                })
            )
        );

        vaultBeacon.upgradeTo(address(iImplementation));
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        proxy.initialize(encodeConfig(config(0)));
    }

    /// A proxy already initialized as this vault cannot be initialized again
    /// as a plain vault after its beacon moves to the plain implementation.
    function testPlainInitializeAfterUpgradeFromConfigRegistryVault() external {
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        UpgradeableBeacon vaultBeacon = new UpgradeableBeacon(address(iImplementation), address(this));
        OffchainAssetReceiptVault proxy = OffchainAssetReceiptVault(
            payable(iFactory.beaconProxyDeterministicOpenSalt(address(vaultBeacon), encodeConfig(config(0)), 0))
        );

        vaultBeacon.upgradeTo(address(new OffchainAssetReceiptVault()));
        ReceiptContract receipt = ReceiptContract(address(new BeaconProxy(address(iReceiptBeacon), "")));
        receipt.initialize(abi.encode(proxy));
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        proxy.initialize(
            abi.encode(
                OffchainAssetReceiptVaultConfigV2({
                    initialAdmin: OWNER,
                    receiptVaultConfig: ReceiptVaultConfigV2({
                        asset: address(0), name: "a", symbol: "b", receipt: address(receipt)
                    })
                })
            )
        );
    }

    function testInitializeBindingTooFresh(uint256 age) external {
        age = bound(age, 0, CONFIG_REGISTRY_RBAC_MIN_AGE);
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        vm.warp(block.timestamp + age);
        vm.expectRevert(
            abi.encodeWithSelector(
                LibConfigRegistry.BindingTooFresh.selector, AUTHORITY, RBAC_NAME, age, CONFIG_REGISTRY_RBAC_MIN_AGE
            )
        );
        deploy(config(0), 0);
    }

    function testInitializeUnboundName(bytes32 name) external {
        vm.assume(name != RBAC_NAME);
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory vaultConfig = config(0);
        vaultConfig.rbacName = name;
        vm.expectRevert(abi.encodeWithSelector(IConfigRegistryV2.NameNotRegistered.selector, AUTHORITY, name));
        deploy(vaultConfig, 0);
    }

    function testInitializeOtherAuthority(address authority) external {
        vm.assume(authority != AUTHORITY);
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory vaultConfig = config(0);
        vaultConfig.authority = authority;
        vm.expectRevert(abi.encodeWithSelector(IConfigRegistryV2.NameNotRegistered.selector, authority, RBAC_NAME));
        deploy(vaultConfig, 0);
    }

    function testInitializeNoRegistry() external {
        vm.etch(LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_ADDRESS, "");
        vm.expectRevert(
            abi.encodeWithSelector(
                LibConfigRegistry.UnexpectedConfigRegistryCodeHash.selector,
                LibConfigRegistryDeploy.CONFIG_REGISTRY_DEPLOYED_CODEHASH,
                bytes32(0)
            )
        );
        deploy(config(0), 0);
    }

    function testInitializeNonCanonicalRbac(bytes memory trailing) external {
        vm.assume(trailing.length > 0);
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            bytes.concat(
                abi.encode(OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()})), trailing
            )
        );
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalRbac.selector, AUTHORITY, RBAC_NAME));
        deploy(config(0), 0);
    }

    function testInitializeAuthorizerIndexOutOfRange(uint256 index) external {
        index = bound(index, 2, type(uint256).max);
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        vm.expectRevert(abi.encodeWithSelector(AuthorizerIndexOutOfRange.selector, index, 2));
        deploy(config(index), 0);
    }

    function testInitializeNoAuthorizers() external {
        bindAged(
            AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: new IAuthorizeV1[](0)})
        );
        vm.expectRevert(abi.encodeWithSelector(AuthorizerIndexOutOfRange.selector, 0, 0));
        deploy(config(0), 0);
    }

    function testInitializeZeroOwner() external {
        bindAged(
            AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: address(0), authorizers: twoAuthorizers()})
        );
        vm.expectRevert(abi.encodeWithSelector(ZeroInitialAdmin.selector));
        deploy(config(0), 0);
    }

    function testInitializeIncompatibleAuthorizer() external {
        IAuthorizeV1[] memory authorizers = twoAuthorizers();
        authorizers[1] = IAuthorizeV1(address(iReceiptImplementation));
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: authorizers}));
        vm.expectRevert(abi.encodeWithSelector(IncompatibleAuthorizer.selector));
        deploy(config(1), 0);
    }

    function testInitializeReceiptFailed() external {
        UpgradeableBeacon receiptBeacon = new UpgradeableBeacon(address(new FailingInitializeReceipt()), address(this));
        UpgradeableBeacon vaultBeacon = new UpgradeableBeacon(
            address(new ConfigRegistryOffchainAssetReceiptVault(IBeacon(address(receiptBeacon)))), address(this)
        );
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        vm.expectRevert(abi.encodeWithSelector(InitializeReceiptFailed.selector));
        iFactory.beaconProxyDeterministicOpenSalt(address(vaultBeacon), encodeConfig(config(0)), 0);
    }

    /// A rebind after deploy moves nothing already deployed.
    function testRebindAfterDeploy() external {
        IAuthorizeV1[] memory authorizers = twoAuthorizers();
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: authorizers}));
        ConfigRegistryOffchainAssetReceiptVault vault = deploy(config(0), 0);

        address otherOwner = address(uint160(uint256(keccak256("other owner"))));
        IAuthorizeV1[] memory otherAuthorizers = twoAuthorizers();
        bindAged(
            AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: otherOwner, authorizers: otherAuthorizers})
        );

        assertEq(vault.owner(), OWNER);
        assertEq(address(vault.authorizer()), address(authorizers[0]));

        ConfigRegistryOffchainAssetReceiptVault next = deploy(config(0), bytes32(uint256(1)));
        assertEq(next.owner(), otherOwner);
        assertEq(address(next.authorizer()), address(otherAuthorizers[0]));
    }

    /// A binding shorter than the canonical encoding that still decodes: the
    /// array offset 0x20 points at its own head word, so that word is also
    /// the array length (32). The canonical encoding is one word longer.
    function testInitializeNonCanonicalOverlappingOffset(address owner) external {
        vm.assume(owner != address(0));
        bytes memory value = abi.encodePacked(uint256(0x20), uint256(uint160(owner)), uint256(0x20));
        for (uint256 i = 0; i < 32; i++) {
            value = bytes.concat(value, abi.encode(address(newAuthorizer(OWNER))));
        }
        OffchainAssetReceiptVaultRbacV1 memory decoded = abi.decode(value, (OffchainAssetReceiptVaultRbacV1));
        assertEq(decoded.owner, owner);
        assertEq(decoded.authorizers.length, 32);
        assertLt(value.length, abi.encode(decoded).length);

        bindAged(AUTHORITY, RBAC_NAME, value);
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalRbac.selector, AUTHORITY, RBAC_NAME));
        deploy(config(0), 0);
    }

    /// Initialized directly on a raw proxy, so `sender` is the caller. The
    /// vault emits, in order and exactly once each: `AuthorizerSet` to
    /// itself, the base `OffchainAssetReceiptVaultInitializedV2`,
    /// `AuthorizerSet` to the selected authorizer, then the registry event.
    function testInitializeEventsDirect(address caller, bool secondAuthorizer) external {
        IAuthorizeV1[] memory authorizers = twoAuthorizers();
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: authorizers}));
        ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory vaultConfig = config(secondAuthorizer ? 1 : 0);
        IAuthorizeV1 selected = authorizers[vaultConfig.authorizerIndex];
        address vault = address(new BeaconProxy(address(iVaultBeacon), ""));

        vm.recordLogs();
        vm.prank(caller);
        ConfigRegistryOffchainAssetReceiptVault(payable(vault)).initialize(encodeConfig(vaultConfig));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32[4] memory topics = [
            IAuthorizeV1.AuthorizerSet.selector,
            OffchainAssetReceiptVault.OffchainAssetReceiptVaultInitializedV2.selector,
            IAuthorizeV1.AuthorizerSet.selector,
            IConfigRegistryOffchainAssetReceiptVaultV1.ConfigRegistryOffchainAssetReceiptVaultInitializedV1.selector
        ];
        bytes[4] memory data = [
            abi.encode(caller, vault),
            abi.encode(
                caller,
                OffchainAssetReceiptVaultConfigV2({
                    initialAdmin: OWNER,
                    receiptVaultConfig: ReceiptVaultConfigV2({
                        asset: address(0),
                        name: vaultConfig.name,
                        symbol: vaultConfig.symbol,
                        receipt: vm.computeCreateAddress(vault, 1)
                    })
                })
            ),
            abi.encode(caller, selected),
            abi.encode(caller, vaultConfig, OWNER, selected)
        ];
        uint256 seen = 0;
        for (uint256 i = 0; i < logs.length; i++) {
            bytes32 topic = logs[i].topics[0];
            if (logs[i].emitter != vault || (topic != topics[0] && topic != topics[1] && topic != topics[3])) {
                continue;
            }
            assertLt(seen, 4);
            assertEq(topic, topics[seen]);
            assertEq(logs[i].topics.length, 1);
            assertEq(logs[i].data, data[seen]);
            seen++;
        }
        assertEq(seen, 4);
    }

    /// Trailing bytes after the canonical config revert, so the same config
    /// and salt cannot land at a second address.
    function testInitializeTrailingConfigBytes(bytes memory trailing) external {
        vm.assume(trailing.length > 0);
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        bytes memory data = bytes.concat(encodeConfig(config(0)), trailing);
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalConfig.selector));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), data, 0);
    }

    /// Data leading with any word but the V1 tag reverts before it is decoded,
    /// naming that word: data written for another config version is never
    /// read as V1.
    function testInitializeUnknownConfigVersion(bytes32 version) external {
        vm.assume(version != CONFIG_REGISTRY_OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V1_TAG);
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        vm.expectRevert(abi.encodeWithSelector(UnknownConfigVersion.selector, version));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), abi.encode(version, config(0)), 0);
    }

    /// The bare V1 config without its tag reverts: its first word, the tuple
    /// offset, is not the tag.
    function testInitializeUntaggedConfig() external {
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        vm.expectRevert(abi.encodeWithSelector(UnknownConfigVersion.selector, bytes32(uint256(0x20))));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), abi.encode(config(0)), 0);
    }

    /// Data shorter than a word reverts as an unknown version zero.
    function testInitializeShortConfig(bytes memory data) external {
        vm.assume(data.length < 0x20);
        vm.expectRevert(abi.encodeWithSelector(UnknownConfigVersion.selector, bytes32(0)));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), data, 0);
    }

    /// A non-canonical config exactly as long as its canonical re-encoding
    /// reverts: a dirty padding byte after the token name.
    function testInitializeSameLengthNonCanonicalConfig(uint8 dirt) external {
        vm.assume(dirt != 0);
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        bytes memory data = encodeConfig(config(0));
        // Word 0 is the version tag, word 1 the tuple offset, words 2-7 the
        // head, word 8 the name length and word 9 the name, whose 14 bytes
        // leave its last byte as padding.
        assertEq(bytes(config(0).name).length, 14);
        data[10 * 32 - 1] = bytes1(dirt);
        (bytes32 version, ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory decoded) =
            abi.decode(data, (bytes32, ConfigRegistryOffchainAssetReceiptVaultConfigV1));
        assertEq(abi.encode(version, decoded), encodeConfig(config(0)));
        assertEq(abi.encode(version, decoded).length, data.length);
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalConfig.selector));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), data, 0);
    }

    /// A clone of the implementation has no beacon to check the receipt
    /// beacon's owner against, so it cannot initialize.
    function testInitializeNotBeaconProxy() external {
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        ConfigRegistryOffchainAssetReceiptVault vault =
            ConfigRegistryOffchainAssetReceiptVault(payable(Clones.clone(address(iImplementation))));
        vm.expectRevert(abi.encodeWithSelector(VaultNotBeaconProxy.selector));
        vault.initialize(encodeConfig(config(0)));
    }

    /// A receipt beacon owned by anyone but the vault beacon's owner reverts,
    /// whichever of the two moved.
    function testInitializeReceiptBeaconOwnerMismatch(address other, bool moveVaultBeacon) external {
        vm.assume(other != address(this) && other != address(0));
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        UpgradeableBeacon receiptBeacon =
            new UpgradeableBeacon(address(iReceiptImplementation), moveVaultBeacon ? address(this) : other);
        UpgradeableBeacon vaultBeacon = new UpgradeableBeacon(
            address(new ConfigRegistryOffchainAssetReceiptVault(IBeacon(address(receiptBeacon)))),
            moveVaultBeacon ? other : address(this)
        );
        (address vaultBeaconOwner, address receiptBeaconOwner) =
            moveVaultBeacon ? (other, address(this)) : (address(this), other);
        vm.expectRevert(
            abi.encodeWithSelector(ReceiptBeaconOwnerMismatch.selector, vaultBeaconOwner, receiptBeaconOwner)
        );
        iFactory.beaconProxyDeterministicOpenSalt(address(vaultBeacon), encodeConfig(config(0)), 0);
    }

    /// A vault beacon without `owner` reverts without data.
    function testInitializeVaultBeaconWithoutOwner() external {
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        OwnerlessBeacon vaultBeacon = new OwnerlessBeacon(address(iImplementation));
        ConfigRegistryOffchainAssetReceiptVault vault =
            ConfigRegistryOffchainAssetReceiptVault(payable(address(new BeaconProxy(address(vaultBeacon), ""))));
        vm.expectRevert(bytes(""));
        vault.initialize(encodeConfig(config(0)));
    }

    /// A receipt beacon without `owner` reverts without data.
    function testInitializeReceiptBeaconWithoutOwner() external {
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        OwnerlessBeacon receiptBeacon = new OwnerlessBeacon(address(iReceiptImplementation));
        UpgradeableBeacon vaultBeacon = new UpgradeableBeacon(
            address(new ConfigRegistryOffchainAssetReceiptVault(IBeacon(address(receiptBeacon)))), address(this)
        );
        ConfigRegistryOffchainAssetReceiptVault vault =
            ConfigRegistryOffchainAssetReceiptVault(payable(address(new BeaconProxy(address(vaultBeacon), ""))));
        vm.expectRevert(bytes(""));
        vault.initialize(encodeConfig(config(0)));
    }

    /// The generic `Receipt`, whose `uri` reads the vault's `address(0)`
    /// asset, reverts.
    function testInitializeGenericReceiptMetadataReverts() external {
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        UpgradeableBeacon receiptBeacon = new UpgradeableBeacon(address(new ReceiptContract()), address(this));
        UpgradeableBeacon vaultBeacon = new UpgradeableBeacon(
            address(new ConfigRegistryOffchainAssetReceiptVault(IBeacon(address(receiptBeacon)))), address(this)
        );
        address vault = iFactory.predictBeaconProxyAddressOpenSalt(address(vaultBeacon), encodeConfig(config(0)), 0);
        vm.expectRevert(abi.encodeWithSelector(ReceiptMetadataReverts.selector, vm.computeCreateAddress(vault, 1)));
        iFactory.beaconProxyDeterministicOpenSalt(address(vaultBeacon), encodeConfig(config(0)), 0);
    }

    /// The fixture's receipt metadata resolves once initialized.
    function testInitializeReceiptMetadata() external {
        bindAged(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()}));
        ConfigRegistryOffchainAssetReceiptVault vault = deploy(config(0), 0);
        ReceiptContract receipt = ReceiptContract(address(vault.receipt()));
        assertEq(receipt.name(), "tTSLA Receipt");
        assertGt(bytes(receipt.uri(0)).length, 0);
    }
}
