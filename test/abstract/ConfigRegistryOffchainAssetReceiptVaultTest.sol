// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {
    ConfigRegistryOffchainAssetReceiptVault,
    ConfigRegistryOffchainAssetReceiptVaultConfigV1,
    OffchainAssetReceiptVaultRbacV1
} from "src/concrete/vault/ConfigRegistryOffchainAssetReceiptVault.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    OffchainAssetReceiptVaultAuthorizerV1Config
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {IAuthorizeV1} from "src/interface/IAuthorizeV1.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {IBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/IBeacon.sol";
import {Clones} from "@openzeppelin-contracts-5.7.0/proxy/Clones.sol";
import {IConfigRegistryV1} from "rain-deploy-0.1.19-pr322/src/interface/IConfigRegistryV1.sol";
import {
    DEPLOYED_ADDRESS as CONFIG_REGISTRY_ADDRESS,
    RUNTIME_CODE as CONFIG_REGISTRY_RUNTIME_CODE
} from "rain-deploy-0.1.19-pr322/src/generated/candidate/ConfigRegistry.sol";
import {TestCloneFactory} from "../concrete/TestCloneFactory.sol";

/// Shared fixture: the pinned `ConfigRegistry` runtime code at its pinned
/// address, a vault beacon and a receipt beacon, a V5 factory, and two
/// authorizers.
abstract contract ConfigRegistryOffchainAssetReceiptVaultTest is Test {
    bytes32 internal constant RBAC_NAME = "st0x.rbac.v1";
    address internal constant AUTHORITY = address(uint160(uint256(keccak256("authority"))));
    address internal constant OWNER = address(uint160(uint256(keccak256("owner"))));

    ReceiptContract internal immutable iReceiptImplementation;
    UpgradeableBeacon internal immutable iReceiptBeacon;
    ConfigRegistryOffchainAssetReceiptVault internal immutable iImplementation;
    UpgradeableBeacon internal immutable iVaultBeacon;
    TestCloneFactory internal immutable iFactory;
    OffchainAssetReceiptVaultAuthorizerV1 internal immutable iAuthorizerImplementation;

    constructor() {
        iReceiptImplementation = new ReceiptContract();
        iReceiptBeacon = new UpgradeableBeacon(address(iReceiptImplementation), address(this));
        iImplementation = new ConfigRegistryOffchainAssetReceiptVault(IBeacon(address(iReceiptBeacon)));
        iVaultBeacon = new UpgradeableBeacon(address(iImplementation), address(this));
        iFactory = new TestCloneFactory();
        iAuthorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();
    }

    function setUp() public virtual {
        vm.etch(CONFIG_REGISTRY_ADDRESS, CONFIG_REGISTRY_RUNTIME_CODE);
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

    function bindValue(address authority, bytes32 name, bytes memory value) internal {
        vm.prank(authority);
        IConfigRegistryV1(CONFIG_REGISTRY_ADDRESS).registerV1(name, value);
    }

    function bind(address authority, bytes32 name, OffchainAssetReceiptVaultRbacV1 memory rbac) internal {
        bindValue(authority, name, abi.encode(rbac));
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

    function deploy(ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory c, bytes32 salt)
        internal
        returns (ConfigRegistryOffchainAssetReceiptVault)
    {
        return ConfigRegistryOffchainAssetReceiptVault(
            payable(iFactory.beaconProxyDeterministicOpenSalt(address(iVaultBeacon), abi.encode(c), salt))
        );
    }
}
