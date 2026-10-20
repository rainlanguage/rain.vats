// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    ConfigRegistryOffchainAssetReceiptVaultTest
} from "test/abstract/ConfigRegistryOffchainAssetReceiptVaultTest.sol";
import {
    ConfigRegistryOffchainAssetReceiptVault,
    ConfigRegistryOffchainAssetReceiptVaultConfigV1,
    OffchainAssetReceiptVaultRbacV1,
    NonCanonicalRbac,
    AuthorizerIndexOutOfRange,
    CONFIG_REGISTRY_RBAC_MIN_AGE
} from "src/concrete/vault/ConfigRegistryOffchainAssetReceiptVault.sol";
import {
    IncompatibleAuthorizer,
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV2
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {ReceiptVaultConfigV2} from "src/abstract/ReceiptVault.sol";
import {BeaconProxy} from "@openzeppelin-contracts-5.7.0/proxy/beacon/BeaconProxy.sol";
import {ZeroInitialAdmin} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {InitializeReceiptFailed} from "src/error/ErrDeployer.sol";
import {IAuthorizeV1} from "src/interface/IAuthorizeV1.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {IBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/IBeacon.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.7.0/proxy/utils/Initializable.sol";
import {LibConfigRegistry} from "rain-deploy-0.1.19-pr322/src/lib/LibConfigRegistry.sol";
import {LibConfigRegistryDeploy} from "rain-deploy-0.1.19-pr322/src/lib/LibConfigRegistryDeploy.sol";
import {IConfigRegistryV1} from "rain-deploy-0.1.19-pr322/src/interface/IConfigRegistryV1.sol";
import {FailingInitializeReceipt} from "../../../concrete/FailingInitializeReceipt.sol";

contract ConfigRegistryOffchainAssetReceiptVaultInitializeTest is ConfigRegistryOffchainAssetReceiptVaultTest {
    function bindAged(IAuthorizeV1[] memory authorizers) internal {
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: authorizers}));
        vm.warp(block.timestamp + CONFIG_REGISTRY_RBAC_MIN_AGE + 1);
    }

    function testInitializeWiresRolesFromRegistry(uint8 index) external {
        IAuthorizeV1[] memory authorizers = twoAuthorizers();
        uint256 authorizerIndex = uint256(index) % authorizers.length;
        bindAged(authorizers);
        ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory c = config(authorizerIndex);

        address predicted = iFactory.predictBeaconProxyAddressOpenSalt(address(iVaultBeacon), abi.encode(c), 0);
        vm.expectEmit(predicted);
        emit ConfigRegistryOffchainAssetReceiptVault.ConfigRegistryOffchainAssetReceiptVaultInitializedV1(
            address(iFactory), c, OWNER, authorizers[authorizerIndex]
        );
        ConfigRegistryOffchainAssetReceiptVault vault = deploy(c, 0);

        assertEq(address(vault), predicted);
        assertEq(vault.owner(), OWNER);
        assertEq(address(vault.authorizer()), address(authorizers[authorizerIndex]));
        assertEq(vault.name(), c.name);
        assertEq(vault.symbol(), c.symbol);
        assertEq(vault.asset(), address(0));
        assertEq(address(vault.receipt()), vm.computeCreateAddress(address(vault), 1));
        assertEq(ReceiptContract(address(vault.receipt())).manager(), address(vault));
    }

    function testInitializeTwice() external {
        bindAged(twoAuthorizers());
        ConfigRegistryOffchainAssetReceiptVault vault = deploy(config(0), 0);
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        vault.initialize(abi.encode(config(0)));
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
        bindAged(twoAuthorizers());
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        proxy.initialize(abi.encode(config(0)));
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
        bindAged(twoAuthorizers());
        ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory c = config(0);
        c.rbacName = name;
        vm.expectRevert(abi.encodeWithSelector(IConfigRegistryV1.NameNotRegistered.selector, AUTHORITY, name));
        deploy(c, 0);
    }

    function testInitializeOtherAuthority(address authority) external {
        vm.assume(authority != AUTHORITY);
        bindAged(twoAuthorizers());
        ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory c = config(0);
        c.authority = authority;
        vm.expectRevert(abi.encodeWithSelector(IConfigRegistryV1.NameNotRegistered.selector, authority, RBAC_NAME));
        deploy(c, 0);
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
        bindValue(
            AUTHORITY,
            RBAC_NAME,
            bytes.concat(
                abi.encode(OffchainAssetReceiptVaultRbacV1({owner: OWNER, authorizers: twoAuthorizers()})), trailing
            )
        );
        vm.warp(block.timestamp + CONFIG_REGISTRY_RBAC_MIN_AGE + 1);
        vm.expectRevert(abi.encodeWithSelector(NonCanonicalRbac.selector, AUTHORITY, RBAC_NAME));
        deploy(config(0), 0);
    }

    function testInitializeAuthorizerIndexOutOfRange(uint256 index) external {
        index = bound(index, 2, type(uint256).max);
        bindAged(twoAuthorizers());
        vm.expectRevert(abi.encodeWithSelector(AuthorizerIndexOutOfRange.selector, index, 2));
        deploy(config(index), 0);
    }

    function testInitializeNoAuthorizers() external {
        bindAged(new IAuthorizeV1[](0));
        vm.expectRevert(abi.encodeWithSelector(AuthorizerIndexOutOfRange.selector, 0, 0));
        deploy(config(0), 0);
    }

    function testInitializeZeroOwner() external {
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: address(0), authorizers: twoAuthorizers()}));
        vm.warp(block.timestamp + CONFIG_REGISTRY_RBAC_MIN_AGE + 1);
        vm.expectRevert(abi.encodeWithSelector(ZeroInitialAdmin.selector));
        deploy(config(0), 0);
    }

    function testInitializeIncompatibleAuthorizer() external {
        IAuthorizeV1[] memory authorizers = twoAuthorizers();
        authorizers[1] = IAuthorizeV1(address(iReceiptImplementation));
        bindAged(authorizers);
        vm.expectRevert(abi.encodeWithSelector(IncompatibleAuthorizer.selector));
        deploy(config(1), 0);
    }

    function testInitializeReceiptFailed() external {
        UpgradeableBeacon receiptBeacon = new UpgradeableBeacon(address(new FailingInitializeReceipt()), address(this));
        UpgradeableBeacon vaultBeacon = new UpgradeableBeacon(
            address(new ConfigRegistryOffchainAssetReceiptVault(IBeacon(address(receiptBeacon)))), address(this)
        );
        bindAged(twoAuthorizers());
        vm.expectRevert(abi.encodeWithSelector(InitializeReceiptFailed.selector));
        iFactory.beaconProxyDeterministicOpenSalt(address(vaultBeacon), abi.encode(config(0)), 0);
    }

    /// A rebind after deploy moves nothing already deployed.
    function testRebindAfterDeploy() external {
        IAuthorizeV1[] memory authorizers = twoAuthorizers();
        bindAged(authorizers);
        ConfigRegistryOffchainAssetReceiptVault vault = deploy(config(0), 0);

        address otherOwner = address(uint160(uint256(keccak256("other owner"))));
        IAuthorizeV1[] memory otherAuthorizers = twoAuthorizers();
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: otherOwner, authorizers: otherAuthorizers}));
        vm.warp(block.timestamp + CONFIG_REGISTRY_RBAC_MIN_AGE + 1);

        assertEq(vault.owner(), OWNER);
        assertEq(address(vault.authorizer()), address(authorizers[0]));

        ConfigRegistryOffchainAssetReceiptVault next = deploy(config(0), bytes32(uint256(1)));
        assertEq(next.owner(), otherOwner);
        assertEq(address(next.authorizer()), address(otherAuthorizers[0]));
    }
}
