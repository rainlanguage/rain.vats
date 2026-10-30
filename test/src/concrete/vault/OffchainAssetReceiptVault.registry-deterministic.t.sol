// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {ERC1967Utils} from "@openzeppelin-contracts-5.7.0/proxy/ERC1967/ERC1967Utils.sol";
import {OffchainAssetReceiptVaultRegistryTest} from "../../../abstract/OffchainAssetReceiptVaultRegistryTest.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV3
} from "../../../../src/abstract/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultRbacV1} from "../../../../src/lib/LibOffchainAssetReceiptVaultRbac.sol";
import {IAuthorizeV1} from "../../../../src/interface/IAuthorizeV1.sol";
import {REGISTRY_BEACON_PROXY_CREATION_CODE} from "rain-factory-0.2.7/src/generated/RegistryBeaconProxy.sol";
import {DEPLOYED_ADDRESS as CONFIG_REGISTRY_ADDRESS} from "rain-deploy-0.1.29/src/generated/candidate/ConfigRegistry.sol";

/// What one chain deployed.
struct ChainDeployment {
    OffchainAssetReceiptVault vault;
    IAuthorizeV1 authorizer;
    address vaultBeacon;
    address receiptBeacon;
}

contract OffchainAssetReceiptVaultRegistryDeterministicTest is OffchainAssetReceiptVaultRegistryTest {
    /// The vault address from first principles: CREATE2 over the registry
    /// beacon proxy's creation code and arguments, behind the V6 domain.
    function expectedAddress(OffchainAssetReceiptVaultConfigV3 memory vaultConfig, bytes32 salt)
        internal
        view
        returns (address)
    {
        bytes32 derivedSalt = keccak256(
            abi.encode(keccak256("rain.factory.registrybeaconproxy"), salt, keccak256(encodeConfig(vaultConfig)))
        );
        bytes memory creationCode = abi.encodePacked(
            REGISTRY_BEACON_PROXY_CREATION_CODE, abi.encode(CONFIG_REGISTRY_ADDRESS, AUTHORITY, VAULT_BEACON_NAME)
        );
        return vm.computeCreate2Address(derivedSalt, keccak256(creationCode), address(iFactory));
    }

    function beaconOf(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967Utils.BEACON_SLOT))));
    }

    /// One chain: its own vault and receipt beacons and its own RBAC binding,
    /// then the vault.
    function deployOnChain(uint256 chainId, address owner, address caller, bytes32 salt)
        internal
        returns (ChainDeployment memory d)
    {
        vm.chainId(chainId);
        d.vaultBeacon = address(new UpgradeableBeacon(address(iImplementation), address(this)));
        d.receiptBeacon = address(new UpgradeableBeacon(address(iReceiptImplementation), address(this)));
        bindValue(AUTHORITY, VAULT_BEACON_NAME, "address", abi.encode(d.vaultBeacon));
        bindValue(AUTHORITY, RECEIPT_BEACON_NAME, "address", abi.encode(d.receiptBeacon));
        d.authorizer = newAuthorizer(OWNER);
        bind(AUTHORITY, RBAC_NAME, OffchainAssetReceiptVaultRbacV1({owner: owner, authorizer: d.authorizer}));
        vm.prank(caller);
        d.vault = deploy(config(), salt);
    }

    /// The same config is the same vault and receipt address on every chain,
    /// whoever deploys it, though each chain binds its own beacons and RBAC.
    function testSameConfigSameAddressAcrossChains(
        uint64 chainA,
        uint64 chainB,
        address ownerA,
        address ownerB,
        address callerA,
        address callerB,
        bytes32 salt
    ) external {
        vm.assume(chainA != chainB);
        vm.assume(ownerA != address(0) && ownerB != address(0) && ownerA != ownerB);
        address expected = expectedAddress(config(), salt);

        uint256 snapshot = vm.snapshotState();
        ChainDeployment memory a = deployOnChain(chainA, ownerA, callerA, salt);
        address receiptA = address(a.vault.receipt());
        assertEq(a.vault.owner(), ownerA);
        assertEq(address(a.vault.authorizer()), address(a.authorizer));
        assertEq(beaconOf(address(a.vault)), a.vaultBeacon);
        assertEq(beaconOf(receiptA), a.receiptBeacon);
        vm.revertToState(snapshot);
        // Moves this contract's nonce, so chain B's beacons land elsewhere.
        new UpgradeableBeacon(address(iImplementation), address(this));
        ChainDeployment memory b = deployOnChain(chainB, ownerB, callerB, salt);

        assertTrue(a.vaultBeacon != b.vaultBeacon);
        assertTrue(a.receiptBeacon != b.receiptBeacon);
        assertEq(address(a.vault), expected);
        assertEq(address(b.vault), expected);
        assertEq(address(b.vault.receipt()), receiptA);
        assertEq(beaconOf(address(b.vault)), b.vaultBeacon);
        assertEq(beaconOf(receiptA), b.receiptBeacon);
        assertEq(b.vault.owner(), ownerB);
        assertEq(address(b.vault.authorizer()), address(b.authorizer));
    }

    /// Every config field moves the address.
    function testEveryConfigFieldMovesAddress() external view {
        OffchainAssetReceiptVaultConfigV3 memory base = config();
        address baseAddress = expectedAddress(base, 0);
        assertEq(
            iFactory.predictRegistryBeaconProxyAddress(
                CONFIG_REGISTRY_ADDRESS, AUTHORITY, VAULT_BEACON_NAME, encodeConfig(base), 0
            ),
            baseAddress
        );

        OffchainAssetReceiptVaultConfigV3 memory vaultConfig = config();
        vaultConfig.name = "x";
        assertTrue(expectedAddress(vaultConfig, 0) != baseAddress);
        vaultConfig = config();
        vaultConfig.symbol = "x";
        assertTrue(expectedAddress(vaultConfig, 0) != baseAddress);
        vaultConfig = config();
        vaultConfig.authority = address(1);
        assertTrue(expectedAddress(vaultConfig, 0) != baseAddress);
        vaultConfig = config();
        vaultConfig.rbacName = "x";
        assertTrue(expectedAddress(vaultConfig, 0) != baseAddress);
        vaultConfig = config();
        vaultConfig.receiptBeaconName = "x";
        assertTrue(expectedAddress(vaultConfig, 0) != baseAddress);
        vaultConfig = config();
        vaultConfig.metadata = "x";
        assertTrue(expectedAddress(vaultConfig, 0) != baseAddress);
    }
}
