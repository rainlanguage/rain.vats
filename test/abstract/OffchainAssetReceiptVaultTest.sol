// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {TestOffchainAssetReceiptVault} from "../concrete/TestOffchainAssetReceiptVault.sol";
import {Test, Vm} from "forge-std-1.17.0/src/Test.sol";
import {
    OffchainAssetReceiptVaultConfigV2,
    OffchainAssetReceiptVault,
    ReceiptVaultConfigV2,
    ConfigRegistryOffchainAssetReceiptVaultConfigV1,
    CONFIG_REGISTRY_RBAC_MIN_AGE
} from "src/abstract/OffchainAssetReceiptVault.sol";
import {
    CONFIG_REGISTRY_OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V1_TAG
} from "../../src/interface/IConfigRegistryOffchainAssetReceiptVaultV1.sol";
import {OffchainAssetReceiptVaultRbacV1} from "../../src/lib/LibOffchainAssetReceiptVaultRbac.sol";
import {Receipt as ReceiptContract} from "../../src/concrete/receipt/Receipt.sol";
import {TestOffchainAssetReceipt} from "../concrete/TestOffchainAssetReceipt.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    OffchainAssetReceiptVaultAuthorizerV1Config
} from "../../src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {IAuthorizeV1} from "../../src/interface/IAuthorizeV1.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {IBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/IBeacon.sol";
import {Clones} from "@openzeppelin-contracts-5.7.0/proxy/Clones.sol";
import {ICloneableFactoryV5} from "rain-factory-0.2.4/src/interface/ICloneableFactoryV5.sol";
import {
    DEPLOYED_ADDRESS as CLONE_FACTORY_ADDRESS,
    RUNTIME_CODE as CLONE_FACTORY_RUNTIME_CODE
} from "rain-factory-deploy-0.2.1/src/generated/0_2_1/CloneFactory.sol";
import {IConfigRegistryV3} from "rain-deploy-0.1.21/src/interface/IConfigRegistryV3.sol";
import {
    DEPLOYED_ADDRESS as CONFIG_REGISTRY_ADDRESS,
    RUNTIME_CODE as CONFIG_REGISTRY_RUNTIME_CODE
} from "rain-deploy-0.1.21/src/generated/0_1_21/ConfigRegistry.sol";

/// Vaults as production makes them: a factory beacon proxy over the vault
/// beacon, initialized from an RBAC binding in the pinned `ConfigRegistry`
/// that names one fresh authorizer.
contract OffchainAssetReceiptVaultTest is Test {
    address internal constant VAULT_AUTHORITY = address(uint160(uint256(keccak256("vault-authority"))));

    OffchainAssetReceiptVault internal immutable iImplementation;
    OffchainAssetReceiptVaultAuthorizerV1 internal immutable iAuthorizerImplementation;
    ReceiptContract internal immutable iReceiptImplementation;
    UpgradeableBeacon internal immutable iVaultBeacon;
    UpgradeableBeacon internal immutable iReceiptBeacon;

    /// Keys each vault's RBAC binding under its own name.
    uint256 internal sVaultCount;

    constructor() {
        iReceiptImplementation = ReceiptContract(address(new TestOffchainAssetReceipt()));
        iImplementation = new TestOffchainAssetReceiptVault();
        iAuthorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();
        iVaultBeacon = new UpgradeableBeacon(address(iImplementation), address(this));
        iReceiptBeacon = new UpgradeableBeacon(address(iReceiptImplementation), address(this));
        // In place before any test reads an address's code, so a fuzzed
        // address that excludes contracts excludes these.
        vm.etch(CONFIG_REGISTRY_ADDRESS, CONFIG_REGISTRY_RUNTIME_CODE);
        vm.etch(CLONE_FACTORY_ADDRESS, CLONE_FACTORY_RUNTIME_CODE);
    }

    /// A vault owned by `admin`, with a fresh authorizer administered by it.
    /// The clock is restored after the binding's minimum age is waited out.
    function createVault(address admin, string memory shareName, string memory shareSymbol)
        internal
        returns (OffchainAssetReceiptVault)
    {
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(Clones.clone(address(iAuthorizerImplementation)));
        authorizer.initialize(abi.encode(OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: admin})));
        IAuthorizeV1[] memory authorizers = new IAuthorizeV1[](1);
        authorizers[0] = authorizer;
        bytes32 rbacName = keccak256(abi.encode("vault-rbac", sVaultCount++));

        uint256 timestamp = block.timestamp;
        vm.prank(VAULT_AUTHORITY);
        IConfigRegistryV3(CONFIG_REGISTRY_ADDRESS)
            .registerV3(
                VAULT_AUTHORITY,
                rbacName,
                abi.encode(
                    OffchainAssetReceiptVaultRbacV1({
                    owner: admin, receiptBeacon: IBeacon(address(iReceiptBeacon)), authorizers: authorizers
                })
                )
            );
        vm.warp(timestamp + CONFIG_REGISTRY_RBAC_MIN_AGE + 1);
        OffchainAssetReceiptVault vault = OffchainAssetReceiptVault(
            payable(ICloneableFactoryV5(CLONE_FACTORY_ADDRESS)
                    .beaconProxyDeterministicOpenSalt(
                        address(iVaultBeacon),
                        abi.encode(
                            CONFIG_REGISTRY_OFFCHAIN_ASSET_RECEIPT_VAULT_CONFIG_V1_TAG,
                            ConfigRegistryOffchainAssetReceiptVaultConfigV1({
                            name: shareName,
                            symbol: shareSymbol,
                            authority: VAULT_AUTHORITY,
                            rbacName: rbacName,
                            authorizerIndex: 0,
                            metadata: ""
                        })
                        ),
                        bytes32(0)
                    ))
        );
        vm.warp(timestamp);
        return vault;
    }

    function getReceipt(Vm.Log[] memory logs) internal pure returns (ReceiptContract) {
        // Find the OffchainAssetReceiptVaultInitialized event log
        address receiptAddress = address(0);
        bool eventFound = false; // Flag to indicate whether the event log was found
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == OffchainAssetReceiptVault.OffchainAssetReceiptVaultInitializedV2.selector) {
                // Decode the event data
                (, OffchainAssetReceiptVaultConfigV2 memory config) =
                    abi.decode(logs[i].data, (address, OffchainAssetReceiptVaultConfigV2));
                receiptAddress = config.receiptVaultConfig.receipt;
                eventFound = true; // Set the flag to true since event log was found
                break;
            }
        }
        // Return an receipt contract
        return ReceiptContract(receiptAddress);
    }
}
