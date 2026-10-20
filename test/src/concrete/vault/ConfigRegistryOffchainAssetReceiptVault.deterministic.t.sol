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
    CONFIG_REGISTRY_RBAC_MIN_AGE
} from "src/concrete/vault/ConfigRegistryOffchainAssetReceiptVault.sol";
import {IAuthorizeV1} from "src/interface/IAuthorizeV1.sol";
import {
    ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN
} from "rain-factory-0.1.31-pr271/src/interface/ICloneableFactoryV5.sol";
import {BEACON_PROXY_CREATION_CODE} from "rain-factory-0.1.31-pr271/src/generated/BeaconProxy.sol";

contract ConfigRegistryOffchainAssetReceiptVaultDeterministicTest is ConfigRegistryOffchainAssetReceiptVaultTest {
    function expectedAddress(ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory c, bytes32 salt)
        internal
        view
        returns (address)
    {
        bytes32 derivedSalt = keccak256(
            abi.encode(ICLONEABLE_FACTORY_V5_BEACON_PROXY_OPEN_SALT_DOMAIN, salt, keccak256(abi.encode(c)))
        );
        bytes memory creationCode =
            abi.encodePacked(BEACON_PROXY_CREATION_CODE, abi.encode(address(iVaultBeacon), bytes("")));
        return vm.computeCreate2Address(derivedSalt, keccak256(creationCode), address(iFactory));
    }

    function deployOnChain(uint256 chainId, address owner, address caller, uint256 authorizerIndex, bytes32 salt)
        internal
        returns (ConfigRegistryOffchainAssetReceiptVault vault, IAuthorizeV1 authorizer)
    {
        vm.chainId(chainId);
        IAuthorizeV1[] memory authorizers = twoAuthorizers();
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: owner, authorizers: authorizers}));
        vm.warp(block.timestamp + CONFIG_REGISTRY_RBAC_MIN_AGE + 1);
        vm.prank(caller);
        vault = deploy(config(authorizerIndex), salt);
        authorizer = authorizers[authorizerIndex];
    }

    /// The same config is the same vault address on every chain, whoever
    /// deploys it, with each chain's own binding.
    function testSameConfigSameAddressAcrossChains(
        uint64 chainA,
        uint64 chainB,
        address ownerA,
        address ownerB,
        address callerA,
        address callerB,
        bool index,
        bytes32 salt
    ) external {
        vm.assume(chainA != chainB);
        vm.assume(ownerA != address(0) && ownerB != address(0) && ownerA != ownerB);
        uint256 authorizerIndex = index ? 1 : 0;
        address expected = expectedAddress(config(authorizerIndex), salt);

        uint256 snapshot = vm.snapshotState();
        (ConfigRegistryOffchainAssetReceiptVault vaultA, IAuthorizeV1 authorizerA) =
            deployOnChain(chainA, ownerA, callerA, authorizerIndex, salt);
        address receiptA = address(vaultA.receipt());
        assertEq(vaultA.owner(), ownerA);
        assertEq(address(vaultA.authorizer()), address(authorizerA));
        vm.revertToState(snapshot);
        (ConfigRegistryOffchainAssetReceiptVault vaultB, IAuthorizeV1 authorizerB) =
            deployOnChain(chainB, ownerB, callerB, authorizerIndex, salt);

        assertEq(address(vaultA), expected);
        assertEq(address(vaultB), expected);
        assertEq(address(vaultB.receipt()), receiptA);
        assertEq(vaultB.owner(), ownerB);
        assertEq(address(vaultB.authorizer()), address(authorizerB));
    }

    /// Every config field moves the address.
    function testEveryConfigFieldMovesAddress() external view {
        ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory base = config(0);
        address baseAddress = expectedAddress(base, 0);
        assertEq(iFactory.predictBeaconProxyAddressOpenSalt(address(iVaultBeacon), abi.encode(base), 0), baseAddress);

        ConfigRegistryOffchainAssetReceiptVaultConfigV1 memory c = config(0);
        c.name = "x";
        assertTrue(expectedAddress(c, 0) != baseAddress);
        c = config(0);
        c.symbol = "x";
        assertTrue(expectedAddress(c, 0) != baseAddress);
        c = config(0);
        c.authority = address(1);
        assertTrue(expectedAddress(c, 0) != baseAddress);
        c = config(0);
        c.rbacName = bytes32("x");
        assertTrue(expectedAddress(c, 0) != baseAddress);
        c = config(1);
        assertTrue(expectedAddress(c, 0) != baseAddress);
        c = config(0);
        c.metadata = "x";
        assertTrue(expectedAddress(c, 0) != baseAddress);
    }
}
