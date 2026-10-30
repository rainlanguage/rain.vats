// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICloneableFactoryV7} from "rain-factory-0.2.7/src/interface/ICloneableFactoryV7.sol";
import {
    DEPLOYED_ADDRESS as CLONE_FACTORY_ADDRESS,
    RUNTIME_CODE as CLONE_FACTORY_RUNTIME_CODE
} from "rain-factory-deploy-0.2.4/src/generated/0_2_4/CloneFactory.sol";
import {TestOffchainAssetReceiptVault} from "../concrete/TestOffchainAssetReceiptVault.sol";
import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV3
} from "../../src/abstract/OffchainAssetReceiptVault.sol";
import {OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V3_TAG} from "../../src/interface/IOffchainAssetReceiptVaultV1.sol";
import {
    OffchainAssetReceiptVaultRbacV1,
    OFFCHAIN_ASSET_RECEIPT_VAULT_RBAC_V1_VALUE_TYPE
} from "../../src/lib/LibOffchainAssetReceiptVaultRbac.sol";
import {TestOffchainAssetReceipt} from "../concrete/TestOffchainAssetReceipt.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    OffchainAssetReceiptVaultAuthorizerV1Config
} from "../../src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {IAuthorizeV1} from "../../src/interface/IAuthorizeV1.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {Clones} from "@openzeppelin-contracts-5.7.0/proxy/Clones.sol";
import {IConfigRegistryV5} from "rain-deploy-0.1.29/src/interface/IConfigRegistryV5.sol";
import {
    DEPLOYED_ADDRESS as CONFIG_REGISTRY_ADDRESS,
    RUNTIME_CODE as CONFIG_REGISTRY_RUNTIME_CODE
} from "rain-deploy-0.1.29/src/generated/candidate/ConfigRegistry.sol";
import {TestCloneFactory} from "rain-factory-0.2.7/src/test/TestCloneFactory.sol";

/// Shared fixture: the pinned `ConfigRegistry` runtime code at its pinned
/// address, a vault beacon and a receipt beacon bound in it, a V6 factory,
/// and two authorizers.
abstract contract OffchainAssetReceiptVaultRegistryTest is Test {
    bytes32 internal constant RBAC_NAME = "st0x.rbac.v1";
    address internal constant AUTHORITY = address(uint160(uint256(keccak256("authority"))));
    address internal constant OWNER = address(uint160(uint256(keccak256("owner"))));
    bytes32 internal constant VAULT_BEACON_NAME = "st0x.vault-beacon.v1";
    bytes32 internal constant RECEIPT_BEACON_NAME = "st0x.receipt-beacon.v1";

    TestOffchainAssetReceipt internal immutable iReceiptImplementation;
    UpgradeableBeacon internal immutable iReceiptBeacon;
    OffchainAssetReceiptVault internal immutable iImplementation;
    UpgradeableBeacon internal immutable iVaultBeacon;
    TestCloneFactory internal immutable iFactory;
    OffchainAssetReceiptVaultAuthorizerV1 internal immutable iAuthorizerImplementation;

    constructor() {
        iReceiptImplementation = new TestOffchainAssetReceipt();
        iReceiptBeacon = new UpgradeableBeacon(address(iReceiptImplementation), address(this));
        iImplementation = new TestOffchainAssetReceiptVault();
        iVaultBeacon = new UpgradeableBeacon(address(iImplementation), address(this));
        iFactory = new TestCloneFactory();
        iAuthorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();
    }

    function setUp() public virtual {
        vm.etch(CONFIG_REGISTRY_ADDRESS, CONFIG_REGISTRY_RUNTIME_CODE);
        vm.etch(CLONE_FACTORY_ADDRESS, CLONE_FACTORY_RUNTIME_CODE);
        vm.warp(1_000_000_000);
        bindValue(AUTHORITY, VAULT_BEACON_NAME, "address", abi.encode(address(iVaultBeacon)));
        bindValue(AUTHORITY, RECEIPT_BEACON_NAME, "address", abi.encode(address(iReceiptBeacon)));
    }

    function newAuthorizer(address admin) internal returns (IAuthorizeV1) {
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(Clones.clone(address(iAuthorizerImplementation)));
        authorizer.initialize(abi.encode(OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: admin})));
        return authorizer;
    }

    /// The receipt the pinned factory deploys for `vault` from `config().authority`'s
    /// `RECEIPT_BEACON_NAME` binding, as the factory itself predicts it.
    function receiptOf(address vault) internal view returns (address) {
        return ICloneableFactoryV7(CLONE_FACTORY_ADDRESS)
            .predictRegistryBeaconProxyAddress(
                CONFIG_REGISTRY_ADDRESS, AUTHORITY, RECEIPT_BEACON_NAME, abi.encode(vault), bytes32(0)
            );
    }

    /// Moves the clock a second first, since the registry refuses a rebind at
    /// the moment of the binding it replaces.
    function bindValue(address authority, bytes32 name, string memory valueType, bytes memory value) internal {
        vm.warp(block.timestamp + 1);
        vm.prank(authority);
        IConfigRegistryV5(CONFIG_REGISTRY_ADDRESS).registerV5(authority, name, valueType, value, "");
    }

    function bind(address authority, bytes32 name, OffchainAssetReceiptVaultRbacV1 memory rbac) internal {
        bindValue(authority, name, OFFCHAIN_ASSET_RECEIPT_VAULT_RBAC_V1_VALUE_TYPE, abi.encode(rbac));
    }

    function config() internal pure returns (OffchainAssetReceiptVaultConfigV3 memory) {
        return OffchainAssetReceiptVaultConfigV3({
            name: "Tesla Inc ST0x",
            symbol: "tTSLA",
            authority: AUTHORITY,
            rbacName: RBAC_NAME,
            receiptBeaconName: RECEIPT_BEACON_NAME,
            metadata: abi.encode("TSLA", "Tesla Inc")
        });
    }

    /// The `initialize` data for `vaultConfig`: the V1 tag, then the config.
    function encodeConfig(OffchainAssetReceiptVaultConfigV3 memory vaultConfig) internal pure returns (bytes memory) {
        return abi.encode(OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V3_TAG, vaultConfig);
    }

    /// The address `deploy` puts `vaultConfig` at, as the factory predicts it.
    function vaultOf(OffchainAssetReceiptVaultConfigV3 memory vaultConfig, bytes32 salt)
        internal
        view
        returns (address)
    {
        return iFactory.predictRegistryBeaconProxyAddress(
            CONFIG_REGISTRY_ADDRESS, AUTHORITY, VAULT_BEACON_NAME, encodeConfig(vaultConfig), salt
        );
    }

    function deploy(OffchainAssetReceiptVaultConfigV3 memory vaultConfig, bytes32 salt)
        internal
        returns (OffchainAssetReceiptVault)
    {
        return OffchainAssetReceiptVault(
            payable(iFactory.registryBeaconProxy(
                    CONFIG_REGISTRY_ADDRESS, AUTHORITY, VAULT_BEACON_NAME, encodeConfig(vaultConfig), salt
                ))
        );
    }
}
