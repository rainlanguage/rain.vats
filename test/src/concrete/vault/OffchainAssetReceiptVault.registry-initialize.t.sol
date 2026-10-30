// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultRegistryTest} from "../../../abstract/OffchainAssetReceiptVaultRegistryTest.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV3,
    NonCanonicalConfig,
    UnknownConfigVersion,
    VaultNotBeaconProxy,
    ReceiptBeaconOwnerMismatch,
    ZeroReceiptBeacon,
    ReceiptMetadataReverts,
    UnexpectedCloneFactoryCodeHash
} from "../../../../src/abstract/OffchainAssetReceiptVault.sol";
import {
    OffchainAssetReceiptVaultRbacV1,
    NonCanonicalRbac,
    OFFCHAIN_ASSET_RECEIPT_VAULT_RBAC_V1_VALUE_TYPE
} from "../../../../src/lib/LibOffchainAssetReceiptVaultRbac.sol";
import {
    IncompatibleAuthorizer,
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV2
} from "../../../../src/abstract/OffchainAssetReceiptVault.sol";
import {OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V3_TAG} from "../../../../src/interface/IOffchainAssetReceiptVaultV1.sol";
import {ReceiptVaultConfigV2} from "../../../../src/abstract/ReceiptVault.sol";
import {BeaconProxy} from "@openzeppelin-contracts-5.7.0/proxy/beacon/BeaconProxy.sol";
import {ERC1967Utils} from "@openzeppelin-contracts-5.7.0/proxy/ERC1967/ERC1967Utils.sol";
import {ZeroInitialAdmin} from "../../../../src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {InitializationFailed} from "rain-factory-0.2.6/src/lib/LibICloneableFactoryV5.sol";
import {IAuthorizeV1} from "../../../../src/interface/IAuthorizeV1.sol";
import {Receipt as ReceiptContract} from "../../../../src/concrete/receipt/Receipt.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {IBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/IBeacon.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.7.0/proxy/utils/Initializable.sol";
import {LibConfigRegistry} from "rain-deploy-0.1.29/src/lib/LibConfigRegistry.sol";
import {LibConfigRegistryDeploy} from "rain-deploy-0.1.29/src/lib/LibConfigRegistryDeploy.sol";
import {IConfigRegistryV4} from "rain-deploy-0.1.29/src/interface/IConfigRegistryV4.sol";
import {FailingInitializeReceipt} from "../../../concrete/FailingInitializeReceipt.sol";
import {OwnerlessBeacon} from "../../../concrete/OwnerlessBeacon.sol";
import {IOffchainAssetReceiptVaultV1} from "../../../../src/interface/IOffchainAssetReceiptVaultV1.sol";
import {Vm} from "forge-std-1.17.0/src/Vm.sol";
import {Clones} from "@openzeppelin-contracts-5.7.0/proxy/Clones.sol";
import {LibCloneFactoryDeploy} from "rain-factory-deploy-0.2.4/src/lib/LibCloneFactoryDeploy.sol";
import {ICloneableFactoryV7} from "rain-factory-0.2.6/src/interface/ICloneableFactoryV7.sol";
import {
    DEPLOYED_ADDRESS as CLONE_FACTORY_ADDRESS
} from "rain-factory-deploy-0.2.4/src/generated/0_2_4/CloneFactory.sol";
import {DEPLOYED_ADDRESS as CONFIG_REGISTRY_ADDRESS} from "rain-deploy-0.1.29/src/generated/0_1_26/ConfigRegistry.sol";

contract OffchainAssetReceiptVaultRegistryInitializeTest is OffchainAssetReceiptVaultRegistryTest {
    function testInitializeWiresRolesFromRegistry() external {
        IAuthorizeV1 authorizer = newAuthorizer(OWNER);
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: authorizer}));
        OffchainAssetReceiptVaultConfigV3 memory vaultConfig = config();

        address predicted = vaultOf(vaultConfig, 0);
        vm.expectEmit(predicted);
        emit IOffchainAssetReceiptVaultV1.OffchainAssetReceiptVaultInitializedV3(
            address(iFactory), vaultConfig, OWNER, authorizer
        );
        OffchainAssetReceiptVault vault = deploy(vaultConfig, 0);

        assertEq(address(vault), predicted);
        assertEq(vault.owner(), OWNER);
        assertEq(address(vault.authorizer()), address(authorizer));
        assertEq(vault.name(), vaultConfig.name);
        assertEq(vault.symbol(), vaultConfig.symbol);
        assertEq(vault.asset(), address(0));
        assertEq(address(vault.receipt()), receiptOf(address(vault)));
        assertEq(ReceiptContract(address(vault.receipt())).manager(), address(vault));
    }

    function testInitializeTwice() external {
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        OffchainAssetReceiptVault vault = deploy(config(), 0);
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        vault.initialize(encodeConfig(config()));
    }

    /// Anything but the pinned clone factory at its address is refused before
    /// the receipt is made through it.
    function testInitializeUnexpectedCloneFactoryCodeHash() external {
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        OffchainAssetReceiptVault vault =
            OffchainAssetReceiptVault(payable(address(new BeaconProxy(address(iVaultBeacon), ""))));
        vm.etch(LibCloneFactoryDeploy.CLONE_FACTORY_DEPLOYED_ADDRESS, hex"00");
        vm.expectRevert(abi.encodeWithSelector(UnexpectedCloneFactoryCodeHash.selector, keccak256(hex"00")));
        vault.initialize(encodeConfig(config()));
    }

    /// An initialized vault cannot be initialized again, with its own config
    /// or any other.
    function testInitializeTwiceReverts() external {
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        OffchainAssetReceiptVault vault = deploy(config(), 0);
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        vault.initialize(encodeConfig(config()));
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        vault.initialize(encodeConfig(config()));
    }

    function testInitializeUnboundName(bytes32 name) external {
        vm.assume(name != RBAC_NAME && name != VAULT_BEACON_NAME && name != RECEIPT_BEACON_NAME);
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        OffchainAssetReceiptVaultConfigV3 memory vaultConfig = config();
        vaultConfig.rbacName = name;
        vm.expectRevert(abi.encodeWithSelector(IConfigRegistryV4.NameNotRegistered.selector, AUTHORITY, name));
        deploy(vaultConfig, 0);
    }

    function testInitializeOtherAuthority(address authority) external {
        vm.assume(authority != AUTHORITY);
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        OffchainAssetReceiptVaultConfigV3 memory vaultConfig = config();
        vaultConfig.authority = authority;
        vm.expectRevert(abi.encodeWithSelector(IConfigRegistryV4.NameNotRegistered.selector, authority, RBAC_NAME));
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
        // Not through `deploy`: the registry beacon proxy would fail resolving
        // its beacon before the vault could check the registry.
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), encodeConfig(config()), 0);
    }

    function testInitializeNonCanonicalRbac(bytes memory trailing) external {
        vm.assume(trailing.length > 0);
        bindValue(
            AUTHORITY,
            RBAC_NAME,
            OFFCHAIN_ASSET_RECEIPT_VAULT_RBAC_V1_VALUE_TYPE,
            bytes.concat(
                abi.encode(OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)})), trailing
            )
        );
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalRbac.selector, AUTHORITY, RBAC_NAME));
        deploy(config(), 0);
    }

    function testInitializeRbacValueTypeMismatch(string memory valueType) external {
        vm.assume(bytes(valueType).length > 0);
        vm.assume(keccak256(bytes(valueType)) != keccak256("(address,address)"));
        bindValue(
            AUTHORITY,
            RBAC_NAME,
            valueType,
            abi.encode(OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                LibConfigRegistry.ValueTypeMismatch.selector,
                AUTHORITY,
                RBAC_NAME,
                keccak256("(address,address)"),
                keccak256(bytes(valueType))
            )
        );
        deploy(config(), 0);
    }

    function testInitializeZeroOwner() external {
        bind(
            AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: address(0), authorizer: newAuthorizer(OWNER)})
        );
        vm.expectRevert(abi.encodeWithSelector(ZeroInitialAdmin.selector));
        deploy(config(), 0);
    }

    function testInitializeIncompatibleAuthorizer() external {
        IAuthorizeV1 authorizer = IAuthorizeV1(address(iReceiptImplementation));
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: authorizer}));
        vm.expectRevert(abi.encodeWithSelector(IncompatibleAuthorizer.selector));
        deploy(config(), 0);
    }

    function testInitializeReceiptFailed() external {
        UpgradeableBeacon receiptBeacon = new UpgradeableBeacon(address(new FailingInitializeReceipt()), address(this));
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        bindValue(AUTHORITY, RECEIPT_BEACON_NAME, "address", abi.encode(address(receiptBeacon)));
        vm.expectRevert(abi.encodeWithSelector(InitializationFailed.selector));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), encodeConfig(config()), 0);
    }

    /// A rebind after deploy moves nothing already deployed.
    function testRebindAfterDeploy() external {
        IAuthorizeV1 authorizer = newAuthorizer(OWNER);
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: authorizer}));
        OffchainAssetReceiptVault vault = deploy(config(), 0);

        address otherOwner = address(uint160(uint256(keccak256("other owner"))));
        IAuthorizeV1 otherAuthorizer = newAuthorizer(OWNER);
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: otherOwner, authorizer: otherAuthorizer}));

        assertEq(vault.owner(), OWNER);
        assertEq(address(vault.authorizer()), address(authorizer));

        OffchainAssetReceiptVault next = deploy(config(), bytes32(uint256(1)));
        assertEq(next.owner(), otherOwner);
        assertEq(address(next.authorizer()), address(otherAuthorizer));
    }

    /// Initialized directly on a raw proxy, so `sender` is the caller. The
    /// vault emits, in order and exactly once each: `AuthorizerSet` to
    /// itself, the base `OffchainAssetReceiptVaultInitializedV2`,
    /// `AuthorizerSet` to the selected authorizer, then the registry event.
    function testInitializeEventsDirect(address caller) external {
        IAuthorizeV1 selected = newAuthorizer(OWNER);
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: selected}));
        OffchainAssetReceiptVaultConfigV3 memory vaultConfig = config();
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
                        asset: address(0), name: vaultConfig.name, symbol: vaultConfig.symbol, receipt: receiptOf(vault)
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
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        bytes memory data = bytes.concat(encodeConfig(config()), trailing);
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalConfig.selector));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), data, 0);
    }

    /// Data leading with any word but the V1 tag reverts before it is decoded,
    /// naming that word: data written for another config version is never
    /// read as V1.
    function testInitializeUnknownConfigVersion(bytes32 version) external {
        vm.assume(version != OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V3_TAG);
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        vm.expectRevert(abi.encodeWithSelector(UnknownConfigVersion.selector, version));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), abi.encode(version, config()), 0);
    }

    /// The bare V1 config without its tag reverts: its first word, the tuple
    /// offset, is not the tag.
    function testInitializeUntaggedConfig() external {
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        vm.expectRevert(abi.encodeWithSelector(UnknownConfigVersion.selector, bytes32(uint256(0x20))));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), abi.encode(config()), 0);
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
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        bytes memory data = encodeConfig(config());
        // Word 0 is the version tag, word 1 the tuple offset, words 2-7 the
        // head, word 8 the name length and word 9 the name, whose 14 bytes
        // leave its last byte as padding.
        assertEq(bytes(config().name).length, 14);
        data[10 * 32 - 1] = bytes1(dirt);
        (bytes32 version, OffchainAssetReceiptVaultConfigV3 memory decoded) =
            abi.decode(data, (bytes32, OffchainAssetReceiptVaultConfigV3));
        assertEq(abi.encode(version, decoded), encodeConfig(config()));
        assertEq(abi.encode(version, decoded).length, data.length);
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalConfig.selector));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), data, 0);
    }

    /// A clone of the implementation has no beacon to check the receipt
    /// beacon's owner against, so it cannot initialize.
    function testInitializeNotBeaconProxy() external {
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        OffchainAssetReceiptVault vault = OffchainAssetReceiptVault(payable(Clones.clone(address(iImplementation))));
        vm.expectRevert(abi.encodeWithSelector(VaultNotBeaconProxy.selector));
        vault.initialize(encodeConfig(config()));
    }

    /// An RBAC binding without a receipt beacon reverts.
    function testInitializeZeroReceiptBeacon() external {
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        bindValue(AUTHORITY, RECEIPT_BEACON_NAME, "address", abi.encode(address(0)));
        vm.expectRevert(abi.encodeWithSelector(ZeroReceiptBeacon.selector));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), encodeConfig(config()), 0);
    }

    /// The receipt is a proxy of whatever `receiptBeaconName` is bound to,
    /// at an address that does not depend on it.
    function testInitializeReceiptBeaconIsTheBindings() external {
        UpgradeableBeacon otherReceiptBeacon = new UpgradeableBeacon(address(iReceiptImplementation), address(this));
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        bindValue(AUTHORITY, RECEIPT_BEACON_NAME, "address", abi.encode(address(otherReceiptBeacon)));
        OffchainAssetReceiptVault vault = deploy(config(), 0);
        assertEq(address(vault.receipt()), receiptOf(address(vault)));
        assertEq(
            address(uint160(uint256(vm.load(address(vault.receipt()), ERC1967Utils.BEACON_SLOT)))),
            address(otherReceiptBeacon)
        );
    }

    /// A receipt beacon owned by anyone but the vault beacon's owner reverts,
    /// whichever of the two moved.
    function testInitializeReceiptBeaconOwnerMismatch(address other, bool moveVaultBeacon) external {
        vm.assume(other != address(this) && other != address(0));
        UpgradeableBeacon receiptBeacon =
            new UpgradeableBeacon(address(iReceiptImplementation), moveVaultBeacon ? address(this) : other);
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        bindValue(AUTHORITY, RECEIPT_BEACON_NAME, "address", abi.encode(address(receiptBeacon)));
        UpgradeableBeacon vaultBeacon =
            new UpgradeableBeacon(address(iImplementation), moveVaultBeacon ? other : address(this));
        (address vaultBeaconOwner, address receiptBeaconOwner) =
            moveVaultBeacon ? (other, address(this)) : (address(this), other);
        vm.expectRevert(
            abi.encodeWithSelector(ReceiptBeaconOwnerMismatch.selector, vaultBeaconOwner, receiptBeaconOwner)
        );
        iFactory.beaconProxyDeterministicOpenSalt(address(vaultBeacon), encodeConfig(config()), 0);
    }

    /// A vault beacon without `owner` reverts without data.
    function testInitializeVaultBeaconWithoutOwner() external {
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        OwnerlessBeacon vaultBeacon = new OwnerlessBeacon(address(iImplementation));
        OffchainAssetReceiptVault vault =
            OffchainAssetReceiptVault(payable(address(new BeaconProxy(address(vaultBeacon), ""))));
        vm.expectRevert(bytes(""));
        vault.initialize(encodeConfig(config()));
    }

    /// A receipt beacon without `owner` reverts without data.
    function testInitializeReceiptBeaconWithoutOwner() external {
        OwnerlessBeacon receiptBeacon = new OwnerlessBeacon(address(iReceiptImplementation));
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        bindValue(AUTHORITY, RECEIPT_BEACON_NAME, "address", abi.encode(address(receiptBeacon)));
        OffchainAssetReceiptVault vault =
            OffchainAssetReceiptVault(payable(address(new BeaconProxy(address(iVaultBeacon), ""))));
        vm.expectRevert(bytes(""));
        vault.initialize(encodeConfig(config()));
    }

    /// The generic `Receipt`, whose `uri` reads the vault's `address(0)`
    /// asset, reverts.
    function testInitializeGenericReceiptMetadataReverts() external {
        UpgradeableBeacon receiptBeacon = new UpgradeableBeacon(address(new ReceiptContract()), address(this));
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        bindValue(AUTHORITY, RECEIPT_BEACON_NAME, "address", abi.encode(address(receiptBeacon)));
        address vault = iFactory.predictBeaconProxyAddressOpenSalt(address(iVaultBeacon), encodeConfig(config()), 0);
        vm.expectRevert(abi.encodeWithSelector(ReceiptMetadataReverts.selector, receiptOf(vault)));
        iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), encodeConfig(config()), 0);
    }

    /// The fixture's receipt metadata resolves once initialized.
    function testInitializeReceiptMetadata() external {
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: newAuthorizer(OWNER)}));
        OffchainAssetReceiptVault vault = deploy(config(), 0);
        ReceiptContract receipt = ReceiptContract(address(vault.receipt()));
        assertEq(receipt.name(), "tTSLA Receipt");
        assertGt(bytes(receipt.uri(0)).length, 0);
    }

    /// A receipt someone made first at this vault's receipt address is
    /// adopted, so front-running the receipt cannot block the vault.
    function testInitializeAdoptsFrontRunReceipt(address frontRunner) external {
        vm.assume(frontRunner != address(0));
        IAuthorizeV1 authorizer = newAuthorizer(OWNER);
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizer: authorizer}));
        address vaultAddress = vaultOf(config(), 0);
        vm.prank(frontRunner);
        address frontRun = ICloneableFactoryV7(CLONE_FACTORY_ADDRESS)
            .registryBeaconProxy(CONFIG_REGISTRY_ADDRESS, AUTHORITY, RECEIPT_BEACON_NAME, abi.encode(vaultAddress), 0);
        assertEq(frontRun, receiptOf(vaultAddress));

        OffchainAssetReceiptVault vault = deploy(config(), 0);

        assertEq(address(vault), vaultAddress);
        assertEq(address(vault.receipt()), frontRun);
        assertEq(ReceiptContract(frontRun).manager(), address(vault));
        assertEq(vault.owner(), OWNER);
        assertEq(address(vault.authorizer()), address(authorizer));
    }
}
