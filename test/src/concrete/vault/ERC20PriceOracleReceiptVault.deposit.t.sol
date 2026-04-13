// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {MinShareRatio, ZeroAssetsAmount, ZeroSharesAmount, ZeroReceiver} from "src/abstract/ReceiptVault.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IReceiptVaultV1} from "src/interface/IReceiptVaultV3.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {IReceiptV3} from "src/interface/IReceiptV3.sol";

contract ERC20PriceOracleReceiptVaultDepositTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    address constant ALICE = address(uint160(uint256(keccak256("ALICE"))));

    function checkDeposit(
        ERC20PriceOracleReceiptVault vault,
        address owner,
        address receiver,
        uint256 oraclePrice,
        uint256 assets,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        bytes memory err
    ) internal {
        uint256 expectedShares = assets.fixedPointMul(oraclePrice, Math.Rounding.Floor);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(owner);
        vm.recordLogs();
        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, owner, address(vault), assets),
            abi.encode(true)
        );

        uint256 startingShares = vault.balanceOf(receiver);
        uint256 startingReceiptBalance = receiver == address(0) ? 0 : vault.receipt().balanceOf(receiver, oraclePrice);
        uint256 totalSupplyBefore = vault.totalSupply();

        if (expectedShares == 0 && err.length == 0) {
            err = abi.encodeWithSelector(ZeroSharesAmount.selector);
        }

        if (err.length > 1) {
            vm.expectRevert(err);
            expectedShares = 0;
        } else {
            vm.expectEmit(false, false, false, true);
            emit IReceiptVaultV1.Deposit(owner, receiver, assets, expectedShares, oraclePrice, receiptInformation);
            if (receiptInformation.length > 0) {
                vm.expectEmit(false, false, false, true);
                emit IReceiptV3.ReceiptInformation(owner, oraclePrice, receiptInformation);
            }
        }

        uint256 actualShares = vault.deposit(assets, receiver, minShareRatio, receiptInformation);
        assertEqUint(actualShares, expectedShares);
        assertEqUint(vault.totalSupply(), totalSupplyBefore + expectedShares);

        if (err.length > 1) {
            assertEqUint(vault.balanceOf(receiver), startingShares);
            // Reading balance of address 0 is an error in ERC1155.
            if (receiver != address(0)) {
                assertEqUint(vault.receipt().balanceOf(receiver, oraclePrice), startingReceiptBalance);
            }
        } else {
            assertEqUint(vault.balanceOf(receiver), startingShares + expectedShares);
            assertEqUint(vault.receipt().balanceOf(receiver, oraclePrice), startingReceiptBalance + expectedShares);
        }
    }

    /// Test deposit function
    function testDepositBasic(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 oraclePrice,
        bytes memory data
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        assets = bound(assets, 1, type(uint128).max);

        checkDeposit(
            createVault(iVaultOracle, shareName, shareSymbol), alice, alice, oraclePrice, assets, 0, data, bytes("")
        );
    }

    /// Test multiple deposits under the different oracle prices.
    function testMultipleDeposits(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets1,
        uint256 assets2,
        uint256 oraclePrice1,
        uint256 oraclePrice2,
        uint256 minShareRatio1,
        uint256 minShareRatio2,
        bytes memory data1,
        bytes memory data2
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        oraclePrice1 = bound(oraclePrice1, 0.01e18, 100e18);
        minShareRatio1 = bound(minShareRatio1, 0, oraclePrice1);
        assets1 = bound(assets1, 1, type(uint128).max);
        checkDeposit(
            createVault(iVaultOracle, shareName, shareSymbol),
            alice,
            alice,
            oraclePrice1,
            assets1,
            minShareRatio1,
            data1,
            bytes("")
        );

        oraclePrice2 = bound(oraclePrice2, 0.01e18, 100e18);
        minShareRatio2 = bound(minShareRatio2, 0, oraclePrice2);
        assets2 = bound(assets2, 1, type(uint128).max);
        checkDeposit(
            createVault(iVaultOracle, shareName, shareSymbol),
            alice,
            alice,
            oraclePrice2,
            assets2,
            minShareRatio2,
            data2,
            bytes("")
        );
    }

    /// Test deposit to someone else
    function testDepositSomeoneElse(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 assets,
        uint256 oraclePrice,
        uint256 minShareRatio,
        bytes memory data
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        minShareRatio = bound(minShareRatio, 0, oraclePrice);
        assets = bound(assets, 1, type(uint128).max);

        checkDeposit(
            createVault(iVaultOracle, shareName, shareSymbol),
            alice,
            bob,
            oraclePrice,
            assets,
            minShareRatio,
            data,
            bytes("")
        );
    }

    /// Test deposit function with zero assets
    function testDepositWithZeroAssets(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        bytes memory data,
        uint256 oraclePrice,
        uint256 minShareRatio
    ) external {
        minShareRatio = bound(minShareRatio, 0, oraclePrice);
        checkDeposit(
            createVault(iVaultOracle, shareName, shareSymbol),
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed),
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed),
            oraclePrice,
            0,
            minShareRatio,
            data,
            abi.encodeWithSelector(ZeroAssetsAmount.selector)
        );
    }

    /// Test to check deposit reverts with MinShareRatio
    function testDepositMinShareRatio(
        uint256 aliceSeed,
        string memory shareName,
        string memory shareSymbol,
        bytes memory data,
        uint256 assets,
        uint256 oraclePrice,
        uint256 minShareRatio
    ) external {
        oraclePrice = bound(oraclePrice, 1, 1e50);
        minShareRatio = bound(minShareRatio, oraclePrice + 1, type(uint256).max);
        assets = bound(assets, 1, type(uint128).max);

        checkDeposit(
            createVault(iVaultOracle, shareName, shareSymbol),
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed),
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed),
            oraclePrice,
            assets,
            minShareRatio,
            data,
            abi.encodeWithSelector(MinShareRatio.selector, minShareRatio, oraclePrice)
        );
    }

    /// Test deposit reverts with zero receiver
    function testDepositWithZeroReceiver(
        string memory shareName,
        string memory shareSymbol,
        bytes memory data,
        uint256 assets,
        uint256 oraclePrice,
        uint256 minShareRatio
    ) external {
        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        minShareRatio = bound(minShareRatio, 0, oraclePrice);
        assets = bound(assets, 1, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);
        checkDeposit(
            createVault(iVaultOracle, shareName, shareSymbol),
            ALICE,
            address(0),
            oraclePrice,
            assets,
            minShareRatio,
            data,
            abi.encodeWithSelector(ZeroReceiver.selector)
        );
    }

    fallback() external {}

    receive() external payable {}
}
