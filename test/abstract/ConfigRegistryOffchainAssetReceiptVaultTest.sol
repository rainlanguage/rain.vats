// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICloneableFactoryV5} from "rain-factory-0.2.4/src/interface/ICloneableFactoryV5.sol";
import {
    DEPLOYED_ADDRESS as CLONE_FACTORY_ADDRESS,
    RUNTIME_CODE as CLONE_FACTORY_RUNTIME_CODE
} from "rain-factory-deploy-0.2.1/src/generated/candidate/CloneFactory.sol";
import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    ConfigRegistryOffchainAssetReceiptVault,
    ConfigRegistryOffchainAssetReceiptVaultConfigV1,
    CONFIG_REGISTRY_RBAC_MIN_AGE
} from "../../src/concrete/vault/ConfigRegistryOffchainAssetReceiptVault.sol";
import {
    CONFIG_REGISTRY_OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V1_TAG
} from "../../src/interface/IConfigRegistryOffchainAssetReceiptVaultV1.sol";
import {OffchainAssetReceiptVaultRbacV1} from "../../src/lib/LibOffchainAssetReceiptVaultRbac.sol";
import {TestOffchainAssetReceipt} from "../concrete/TestOffchainAssetReceipt.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    OffchainAssetReceiptVaultAuthorizerV1Config
} from "../../src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {IAuthorizeV1} from "../../src/interface/IAuthorizeV1.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {IBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/IBeacon.sol";
import {Clones} from "@openzeppelin-contracts-5.7.0/proxy/Clones.sol";
import {IConfigRegistryV2} from "rain-deploy-0.1.20/src/interface/IConfigRegistryV2.sol";
import {
    DEPLOYED_ADDRESS as CONFIG_REGISTRY_ADDRESS,
    RUNTIME_CODE as CONFIG_REGISTRY_RUNTIME_CODE
} from "rain-deploy-0.1.20/src/generated/candidate/ConfigRegistry.sol";
import {TestCloneFactory} from "rain-factory-0.2.4/src/test/TestCloneFactory.sol";

/// Shared fixture: the pinned `ConfigRegistry` runtime code at its pinned
/// address, a vault beacon and a receipt beacon, a V5 factory, and two
/// authorizers.
abstract contract ConfigRegistryOffchainAssetReceiptVaultTest is Test {
    bytes32 internal constant RBAC_NAME = "st0x.rbac.v1";
    address internal constant AUTHORITY = address(uint160(uint256(keccak256("authority"))));
    address internal constant OWNER = address(uint160(uint256(keccak256("owner"))));

    TestOffchainAssetReceipt internal immutable iReceiptImplementation;
    UpgradeableBeacon internal immutable iReceiptBeacon;
    ConfigRegistryOffchainAssetReceiptVault internal immutable iImplementation;
    UpgradeableBeacon internal immutable iVaultBeacon;
    TestCloneFactory internal immutable iFactory;
    OffchainAssetReceiptVaultAuthorizerV1 internal immutable iAuthorizerImplementation;

    constructor() {
        iReceiptImplementation = new TestOffchainAssetReceipt();
        iReceiptBeacon = new UpgradeableBeacon(address(iReceiptImplementation), address(this));
        iImplementation = new ConfigRegistryOffchainAssetReceiptVault();
        iVaultBeacon = new UpgradeableBeacon(address(iImplementation), address(this));
        iFactory = new TestCloneFactory();
        iAuthorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();
    }

    function setUp() public virtual {
        vm.etch(CONFIG_REGISTRY_ADDRESS, CONFIG_REGISTRY_RUNTIME_CODE);
        vm.etch(CLONE_FACTORY_ADDRESS, CLONE_FACTORY_RUNTIME_CODE);
        vm.warp(1_000_000_000);
    }

    function newAuthorizer(address admin) internal returns (IAuthorizeV1) {
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(Clones.clone(address(iAuthorizerImplementation)));
        authorizer.initialize(abi.encode(OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: admin})));
        return authorizer;
    }

    function twoAuthorizers() internal returns (IAuthorizeV1[] memory authorizers) {
        authorizers = new IAuthorizeV1[](2);
        authorizers[0] = newAuthorizer(OWNER);
        authorizers[1] = newAuthorizer(OWNER);
    }

    /// The receipt the pinned factory deploys for `vault` over `receiptBeacon`,
    /// as the factory itself predicts it.
    function receiptOf(address vault, address receiptBeacon) internal view returns (address) {
        return ICloneableFactoryV5(CLONE_FACTORY_ADDRESS)
            .predictBeaconProxyAddressOpenSalt(receiptBeacon, abi.encode(vault), bytes32(0));
    }

    function bindValue(address authority, bytes32 name, bytes memory value) internal {
        vm.prank(authority);
        IConfigRegistryV2(CONFIG_REGISTRY_ADDRESS).registerV2(authority, name, value);
    }

    function bind(address authority, bytes32 name, OffchainAssetReceiptVaultRbacV1 memory rbac) internal {
        bindValue(authority, name, abi.encode(rbac));
    }

    /// Binds `value` and warps past `CONFIG_REGISTRY_RBAC_MIN_AGE`.
    function bindAged(address authority, bytes32 name, bytes memory value) internal {
        bindValue(authority, name, value);
        vm.warp(block.timestamp + CONFIG_REGISTRY_RBAC_MIN_AGE + 1);
    }

    /// Binds `rbac` and warps past `CONFIG_REGISTRY_RBAC_MIN_AGE`.
    function bindAged(address authority, bytes32 name, OffchainAssetReceiptVaultRbacV1 memory rbac) internal {
        bindAged(authority, name, abi.encode(rbac));
    }

    function config(uint256 authorizerIndex)
        internal
        pure
        returns (ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory)
    {
        return ConfigRegistryOffchainAssetReceiptVaultConfigV1({
            name: "Tesla Inc ST0x",
            symbol: "tTSLA",
            authority: AUTHORITY,
            rbacName: RBAC_NAME,
            authorizerIndex: authorizerIndex,
            metadata: abi.encode("TSLA", "Tesla Inc")
        });
    }

    /// The `initialize` data for `vaultConfig`: the V1 tag, then the config.
    function encodeConfig(ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory vaultConfig)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(CONFIG_REGISTRY_OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V1_TAG, vaultConfig);
    }

    function deploy(ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory vaultConfig, bytes32 salt)
        internal
        returns (ConfigRegistryOffchainAssetReceiptVault)
    {
        return ConfigRegistryOffchainAssetReceiptVault(
            payable(iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), encodeConfig(vaultConfig), salt))
        );
    }
}
