// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultRegistryTest} from "../../../abstract/OffchainAssetReceiptVaultRegistryTest.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV3,
    AuthorizerIndexOutOfRange,
    NonCanonicalConfig,
    UnknownConfigVersion,
    VaultNotBeaconProxy,
    ReceiptBeaconOwnerMismatch,
    ZeroReceiptBeacon,
    ReceiptMetadataReverts,
    UnexpectedCloneFactoryCodeHash,
    CONFIG_REGISTRY_RBAC_MIN_AGE
} from "../../../../src/abstract/OffchainAssetReceiptVault.sol";
import {
    OffchainAssetReceiptVaultRbacV1,
    NonCanonicalRbac
} from "../../../../src/lib/LibOffchainAssetReceiptVaultRbac.sol";
import {
    IncompatibleAuthorizer,
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV2
} from "../../../../src/abstract/OffchainAssetReceiptVault.sol";
import {OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V3_TAG} from "../../../../src/interface/IOffchainAssetReceiptVaultV1.sol";
import {ReceiptVaultConfigV2} from "../../../../src/abstract/ReceiptVault.sol";
import {BeaconProxy} from "@openzeppelin-contracts-5.7.0/proxy/beacon/BeaconProxy.sol";
import {ZeroInitialAdmin} from "../../../../src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {InitializationFailed} from "rain-factory-0.2.4/src/lib/LibICloneableFactoryV5.sol";
import {IAuthorizeV1} from "../../../../src/interface/IAuthorizeV1.sol";
import {Receipt as ReceiptContract} from "../../../../src/concrete/receipt/Receipt.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {IBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/IBeacon.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.7.0/proxy/utils/Initializable.sol";
import {LibConfigRegistry} from "rain-deploy-0.1.21/src/lib/LibConfigRegistry.sol";
import {LibConfigRegistryDeploy} from "rain-deploy-0.1.21/src/lib/LibConfigRegistryDeploy.sol";
import {IConfigRegistryV3} from "rain-deploy-0.1.21/src/interface/IConfigRegistryV3.sol";
import {FailingInitializeReceipt} from "../../../concrete/FailingInitializeReceipt.sol";
import {OwnerlessBeacon} from "../../../concrete/OwnerlessBeacon.sol";
import {IOffchainAssetReceiptVaultV1} from "../../../../src/interface/IOffchainAssetReceiptVaultV1.sol";
import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {Clones} from "@openzeppelin-contracts-5.7.0/proxy/Clones.sol";
import {LibCloneFactoryDeploy} from "rain-factory-deploy-0.2.1/src/lib/LibCloneFactoryDeploy.sol";

contract OffchainAssetReceiptVaultRegistryInitializeTest is OffchainAssetReceiptVaultRegistryTest {
    function testInitializeWiresRolesFromRegistry(uint8 index) external {
        IAuthorizeV1[] memory authorizers = twoAuthorizers();
        uint256 authorizerIndex = uint256(index) % authorizers.length;
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: authorizers
            })
        );
        OffchainAssetReceiptVaultConfigV3 memory vaultConfig = config(authorizerIndex);

        address predicted =
            iFactory.predictBeaconProxyAddressOpenSalt(address(iVaultBeacon), encodeConfig(vaultConfig), 0);
        vm.expectEmit(predicted);
        emit IOffchainAssetReceiptVaultV1.OffchainAssetReceiptVaultInitializedV3(
            address(iFactory), vaultConfig, OWNER, authorizers[authorizerIndex]
        );
        OffchainAssetReceiptVault vault = deploy(vaultConfig, 0);

        assertEq(address(vault), predicted);
        assertEq(vault.owner(), OWNER);
        assertEq(address(vault.authorizer()), address(authorizers[authorizerIndex]));
        assertEq(vault.name(), vaultConfig.name);
        assertEq(vault.symbol(), vaultConfig.symbol);
        assertEq(vault.asset(), address(0));
        assertEq(address(vault.receipt()), receiptOf(address(vault), address(iReceiptBeacon)));
        assertEq(ReceiptContract(address(vault.receipt())).manager(), address(vault));
    }

    function testInitializeTwice() external {
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        OffchainAssetReceiptVault vault = deploy(config(0), 0);
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        vault.initialize(encodeConfig(config(0)));
    }

    /// Anything but the pinned clone factory at its address is refused before
    /// the receipt is made through it.
    function testInitializeUnexpectedCloneFactoryCodeHash() external {
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        OffchainAssetReceiptVault vault =
            OffchainAssetReceiptVault(payable(address(new BeaconProxy(address(iVaultBeacon), ""))));
        vm.etch(LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS, hex"00");
        vm.expectRevert(abi.encodeWithSelector(UnexpectedCloneFactoryCodeHash.selector, keccak256(hex"00")));
        vault.initialize(encodeConfig(config(0)));
    }

    /// An initialized vault cannot be initialized again, with its own config
    /// or any other.
    function testInitializeTwiceReverts() external {
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        OffchainAssetReceiptVault vault = deploy(config(0), 0);
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        vault.initialize(encodeConfig(config(0)));
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        vault.initialize(encodeConfig(config(1)));
    }

    function testInitializeBindingTooFresh(uint256 age) external {
        age = bound(age, 0, CONFIG_REGISTRY_RBAC_MIN_AGE);
        bind(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
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
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        OffchainAssetReceiptVaultConfigV3 memory vaultConfig = config(0);
        vaultConfig.rbacName = name;
        vm.expectRevert(abi.encodeWithSelector(IConfigRegistryV3.NameNotRegistered.selector, AUTHORITY, name));
        deploy(vaultConfig, 0);
    }

    function testInitializeOtherAuthority(address authority) external {
        vm.assume(authority != AUTHORITY);
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        OffchainAssetReceiptVaultConfigV3 memory vaultConfig = config(0);
        vaultConfig.authority = authority;
        vm.expectRevert(abi.encodeWithSelector(IConfigRegistryV3.NameNotRegistered.selector, authority, RBAC_NAME));
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
                abi.encode(
                    OffchainAssetReceiptVaultRbacV1({
                        owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
                    })
                ),
                trailing
            )
        );
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalRbac.selector, AUTHORITY, RBAC_NAME));
        deploy(config(0), 0);
    }

    function testInitializeAuthorizerIndexOutOfRange(uint256 index) external {
        index = bound(index, 2, type(uint256).max);
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        vm.expectRevert(abi.encodeWithSelector(AuthorizerIndexOutOfRange.selector, index, 2));
        deploy(config(index), 0);
    }

    function testInitializeNoAuthorizers() external {
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: new IAuthorizeV1[](0)
            })
        );
        vm.expectRevert(abi.encodeWithSelector(AuthorizerIndexOutOfRange.selector, 0, 0));
        deploy(config(0), 0);
    }

    function testInitializeZeroOwner() external {
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: address(0), receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        vm.expectRevert(abi.encodeWithSelector(ZeroInitialAdmin.selector));
        deploy(config(0), 0);
    }

    function testInitializeIncompatibleAuthorizer() external {
        IAuthorizeV1[] memory authorizers = twoAuthorizers();
        authorizers[1] = IAuthorizeV1(address(iReceiptImplementation));
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: authorizers
            })
        );
        vm.expectRevert(abi.encodeWithSelector(IncompatibleAuthorizer.selector));
        deploy(config(1), 0);
    }

    function testInitializeReceiptFailed() external {
        UpgradeableBeacon receiptBeacon = new UpgradeableBeacon(address(new FailingInitializeReceipt()), address(this));
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(receiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        vm.expectRevert(abi.encodeWithSelector(InitializationFailed.selector));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), encodeConfig(config(0)), 0);
    }

    /// A rebind after deploy moves nothing already deployed.
    function testRebindAfterDeploy() external {
        IAuthorizeV1[] memory authorizers = twoAuthorizers();
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: authorizers
            })
        );
        OffchainAssetReceiptVault vault = deploy(config(0), 0);

        address otherOwner = address(uint160(uint256(keccak256("other owner"))));
        IAuthorizeV1[] memory otherAuthorizers = twoAuthorizers();
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: otherOwner, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: otherAuthorizers
            })
        );

        assertEq(vault.owner(), OWNER);
        assertEq(address(vault.authorizer()), address(authorizers[0]));

        OffchainAssetReceiptVault next = deploy(config(0), bytes32(uint256(1)));
        assertEq(next.owner(), otherOwner);
        assertEq(address(next.authorizer()), address(otherAuthorizers[0]));
    }

    /// A binding shorter than the canonical encoding that still decodes: the
    /// array offset 0x40 points at its own head word, so that word is also
    /// the array length (64). The canonical encoding is one word longer.
    function testInitializeNonCanonicalOverlappingOffset(address owner) external {
        vm.assume(owner != address(0));
        bytes memory value = abi.encodePacked(
            uint256(0x20), uint256(uint160(owner)), uint256(uint160(address(iReceiptBeacon))), uint256(0x40)
        );
        for (uint256 i = 0; i < 64; i++) {
            value = bytes.concat(value, abi.encode(address(newAuthorizer(OWNER))));
        }
        OffchainAssetReceiptVaultRbacV1 memory decoded = abi.decode(value, (OffchainAssetReceiptVaultRbacV1));
        assertEq(decoded.owner, owner);
        assertEq(address(decoded.receiptBeacon), address(iReceiptBeacon));
        assertEq(decoded.authorizers.length, 64);
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
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: authorizers
            })
        );
        OffchainAssetReceiptVaultConfigV3 memory vaultConfig = config(secondAuthorizer ? 1 : 0);
        IAuthorizeV1 selected = authorizers[vaultConfig.authorizerIndex];
        address vault = address(new BeaconProxy(address(iVaultBeacon), ""));

        vm.recordLogs();
        vm.prank(caller);
        OffchainAssetReceiptVault(payable(vault)).initialize(encodeConfig(vaultConfig));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32[4] memory topics = [
            IAuthorizeV1.AuthorizerSet.selector,
            OffchainAssetReceiptVault.OffchainAssetReceiptVaultInitializedV2.selector,
            IAuthorizeV1.AuthorizerSet.selector,
            IOffchainAssetReceiptVaultV1.OffchainAssetReceiptVaultInitializedV3.selector
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
                        receipt: receiptOf(vault, address(iReceiptBeacon))
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
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        bytes memory data = bytes.concat(encodeConfig(config(0)), trailing);
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalConfig.selector));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), data, 0);
    }

    /// Data leading with any word but the V1 tag reverts before it is decoded,
    /// naming that word: data written for another config version is never
    /// read as V1.
    function testInitializeUnknownConfigVersion(bytes32 version) external {
        vm.assume(version != OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V3_TAG);
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        vm.expectRevert(abi.encodeWithSelector(UnknownConfigVersion.selector, version));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), abi.encode(version, config(0)), 0);
    }

    /// The bare V1 config without its tag reverts: its first word, the tuple
    /// offset, is not the tag.
    function testInitializeUntaggedConfig() external {
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
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
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        bytes memory data = encodeConfig(config(0));
        // Word 0 is the version tag, word 1 the tuple offset, words 2-7 the
        // head, word 8 the name length and word 9 the name, whose 14 bytes
        // leave its last byte as padding.
        assertEq(bytes(config(0).name).length, 14);
        data[10 * 32 - 1] = bytes1(dirt);
        (bytes32 version, OffchainAssetReceiptVaultConfigV3 memory decoded) =
            abi.decode(data, (bytes32, OffchainAssetReceiptVaultConfigV3));
        assertEq(abi.encode(version, decoded), encodeConfig(config(0)));
        assertEq(abi.encode(version, decoded).length, data.length);
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalConfig.selector));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), data, 0);
    }

    /// A clone of the implementation has no beacon to check the receipt
    /// beacon's owner against, so it cannot initialize.
    function testInitializeNotBeaconProxy() external {
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        OffchainAssetReceiptVault vault = OffchainAssetReceiptVault(payable(Clones.clone(address(iImplementation))));
        vm.expectRevert(abi.encodeWithSelector(VaultNotBeaconProxy.selector));
        vault.initialize(encodeConfig(config(0)));
    }

    /// An RBAC binding without a receipt beacon reverts.
    function testInitializeZeroReceiptBeacon() external {
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(0)), authorizers: twoAuthorizers()
            })
        );
        vm.expectRevert(abi.encodeWithSelector(ZeroReceiptBeacon.selector));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), encodeConfig(config(0)), 0);
    }

    /// Each vault's receipt is a proxy of the receipt beacon its RBAC binding
    /// names, so two bindings on one vault implementation give two receipt
    /// beacons.
    function testInitializeReceiptBeaconIsTheBindings() external {
        UpgradeableBeacon otherReceiptBeacon = new UpgradeableBeacon(address(iReceiptImplementation), address(this));
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(otherReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        OffchainAssetReceiptVault vault = deploy(config(0), 0);
        assertEq(address(vault.receipt()), receiptOf(address(vault), address(otherReceiptBeacon)));
        assertTrue(address(vault.receipt()) != receiptOf(address(vault), address(iReceiptBeacon)));
    }

    /// A receipt beacon owned by anyone but the vault beacon's owner reverts,
    /// whichever of the two moved.
    function testInitializeReceiptBeaconOwnerMismatch(address other, bool moveVaultBeacon) external {
        vm.assume(other != address(this) && other != address(0));
        UpgradeableBeacon receiptBeacon =
            new UpgradeableBeacon(address(iReceiptImplementation), moveVaultBeacon ? address(this) : other);
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(receiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        UpgradeableBeacon vaultBeacon =
            new UpgradeableBeacon(address(iImplementation), moveVaultBeacon ? other : address(this));
        (address vaultBeaconOwner, address receiptBeaconOwner) =
            moveVaultBeacon ? (other, address(this)) : (address(this), other);
        vm.expectRevert(
            abi.encodeWithSelector(ReceiptBeaconOwnerMismatch.selector, vaultBeaconOwner, receiptBeaconOwner)
        );
        iFactory.beaconProxyDeterministicOpenSalt(address(vaultBeacon), encodeConfig(config(0)), 0);
    }

    /// A vault beacon without `owner` reverts without data.
    function testInitializeVaultBeaconWithoutOwner() external {
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        OwnerlessBeacon vaultBeacon = new OwnerlessBeacon(address(iImplementation));
        OffchainAssetReceiptVault vault =
            OffchainAssetReceiptVault(payable(address(new BeaconProxy(address(vaultBeacon), ""))));
        vm.expectRevert(bytes(""));
        vault.initialize(encodeConfig(config(0)));
    }

    /// A receipt beacon without `owner` reverts without data.
    function testInitializeReceiptBeaconWithoutOwner() external {
        OwnerlessBeacon receiptBeacon = new OwnerlessBeacon(address(iReceiptImplementation));
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(receiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        OffchainAssetReceiptVault vault =
            OffchainAssetReceiptVault(payable(address(new BeaconProxy(address(iVaultBeacon), ""))));
        vm.expectRevert(bytes(""));
        vault.initialize(encodeConfig(config(0)));
    }

    /// The generic `Receipt`, whose `uri` reads the vault's `address(0)`
    /// asset, reverts.
    function testInitializeGenericReceiptMetadataReverts() external {
        UpgradeableBeacon receiptBeacon = new UpgradeableBeacon(address(new ReceiptContract()), address(this));
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(receiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        address vault = iFactory.predictBeaconProxyAddressOpenSalt(address(iVaultBeacon), encodeConfig(config(0)), 0);
        vm.expectRevert(
            abi.encodeWithSelector(ReceiptMetadataReverts.selector, receiptOf(vault, address(receiptBeacon)))
        );
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), encodeConfig(config(0)), 0);
    }

    /// The fixture's receipt metadata resolves once initialized.
    function testInitializeReceiptMetadata() external {
        bindAged(
            AUTHORITY,
            RBAC_NAME,
            OffchainAssetReceiptVaultRbacV1({
                owner: OWNER, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: twoAuthorizers()
            })
        );
        OffchainAssetReceiptVault vault = deploy(config(0), 0);
        ReceiptContract receipt = ReceiptContract(address(vault.receipt()));
        assertEq(receipt.name(), "tTSLA Receipt");
        assertGt(bytes(receipt.uri(0)).length, 0);
    }
}
