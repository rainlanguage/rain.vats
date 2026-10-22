// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.17.0/src/Test.sol";
import {ReceiptVaultConfigV2} from "src/abstract/ReceiptVault.sol";
import {
    OffchainAssetReceiptVaultConfigV2,
    ZeroInitialAdmin,
    NonZeroAsset
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {CorruptedEnvironmentBlockTimestampZero} from "src/abstract/OwnerFreezable.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {BeaconProxy} from "@openzeppelin-contracts-5.7.0/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin-contracts-5.7.0/proxy/beacon/UpgradeableBeacon.sol";
import {IAuthorizeV1} from "../../../../src/interface/IAuthorizeV1.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.7.0/proxy/utils/Initializable.sol";
import {
    ExposedInitializeOffchainAssetReceiptVault
} from "../../../concrete/ExposedInitializeOffchainAssetReceiptVault.sol";

/// @title OffChainAssetReceiptVaultInitializeTest
/// `_initialize`, the vault setup `initialize` runs once it has resolved the
/// registry, driven directly through a proxy of an exposing harness.
contract OffChainAssetReceiptVaultInitializeTest is Test {
    UpgradeableBeacon internal immutable iVaultBeacon;
    UpgradeableBeacon internal immutable iReceiptBeacon;

    constructor() {
        iVaultBeacon = new UpgradeableBeacon(address(new ExposedInitializeOffchainAssetReceiptVault()), address(this));
        iReceiptBeacon = new UpgradeableBeacon(address(new ReceiptContract()), address(this));
    }

    /// A vault proxy and a receipt proxy managed by it.
    function pair() internal returns (ExposedInitializeOffchainAssetReceiptVault, address) {
        ExposedInitializeOffchainAssetReceiptVault vault =
            ExposedInitializeOffchainAssetReceiptVault(payable(address(new BeaconProxy(address(iVaultBeacon), ""))));
        ReceiptContract receipt = ReceiptContract(address(new BeaconProxy(address(iReceiptBeacon), "")));
        receipt.initialize(abi.encode(vault));
        return (vault, address(receipt));
    }

    function config(address initialAdmin, address asset, address receipt)
        internal
        pure
        returns (OffchainAssetReceiptVaultConfigV2 memory)
    {
        return OffchainAssetReceiptVaultConfigV2({
            initialAdmin: initialAdmin,
            receiptVaultConfig: ReceiptVaultConfigV2({asset: asset, name: "a", symbol: "b", receipt: receipt})
        });
    }

    /// Inclusive timestamp comparisons in `OwnerFreezable` treat the stored 0
    /// sentinel as an active deadline at `block.timestamp == 0`, so
    /// `_initialize` reverts there rather than land in that state.
    function testInitAtGenesisTimestampReverts() external {
        (ExposedInitializeOffchainAssetReceiptVault vault, address receipt) = pair();
        vm.warp(0);
        vm.expectRevert(CorruptedEnvironmentBlockTimestampZero.selector);
        vault.exposedInitializeAsInitializer(config(address(1), address(0), receipt));
    }

    /// The owner must not be the zero address.
    function testZeroInitialAdmin() external {
        (ExposedInitializeOffchainAssetReceiptVault vault, address receipt) = pair();
        vm.expectRevert(abi.encodeWithSelector(ZeroInitialAdmin.selector));
        vault.exposedInitializeAsInitializer(config(address(0), address(0), receipt));
    }

    /// The asset is off-chain, so a non-zero asset reverts.
    function testNonZeroAsset(address asset) external {
        vm.assume(asset != address(0));
        (ExposedInitializeOffchainAssetReceiptVault vault, address receipt) = pair();
        vm.expectRevert(abi.encodeWithSelector(NonZeroAsset.selector));
        vault.exposedInitializeAsInitializer(config(address(1), asset, receipt));
    }

    /// `_initialize` makes the vault its own authorizer and the admin its
    /// owner.
    function testInitializeSelfAuthorizer(address initialAdmin) external {
        vm.assume(initialAdmin != address(0));
        (ExposedInitializeOffchainAssetReceiptVault vault, address receipt) = pair();
        vm.expectEmit(address(vault));
        emit IAuthorizeV1.AuthorizerSet(address(this), IAuthorizeV1(address(vault)));
        vault.exposedInitializeAsInitializer(config(initialAdmin, address(0), receipt));
        assertEq(address(vault.authorizer()), address(vault));
        assertEq(vault.owner(), initialAdmin);
    }

    /// `_initialize` refuses to run outside an initializer before it checks
    /// anything else, so even a zero timestamp reverts `NotInitializing`.
    function testInternalInitializeOutsideInitializer(address initialAdmin) external {
        ExposedInitializeOffchainAssetReceiptVault vault = new ExposedInitializeOffchainAssetReceiptVault();
        vm.warp(0);
        vm.expectRevert(abi.encodeWithSelector(Initializable.NotInitializing.selector));
        vault.exposedInitialize(config(initialAdmin, address(0), address(0)));
    }
}
