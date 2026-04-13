// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {MinShareRatio, ZeroAssetsAmount} from "src/abstract/ReceiptVault.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {IReceiptV3} from "src/concrete/receipt/Receipt.sol";
import {IReceiptVaultV1} from "src/interface/IReceiptVaultV3.sol";

contract ERC20PriceOracleReceiptVaultMintTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    address constant ALICE = address(uint160(uint256(keccak256("ALICE"))));

    function bounds(uint256 oraclePrice, uint256 shares) internal pure returns (uint256, uint256) {
        return (bound(oraclePrice, 1, 1e50), bound(shares, 1, type(uint128).max));
    }

    function checkMint(
        ERC20PriceOracleReceiptVault vault,
        address owner,
        address receiver,
        uint256 oraclePrice,
        uint256 shares,
        uint256 minShareRatio,
        bytes memory receiptInformation,
        bytes memory err
    ) internal {
        uint256 expectedAssets = shares.fixedPointDiv(oraclePrice, Math.Rounding.Ceil);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(owner);
        vm.recordLogs();
        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, owner, address(vault), expectedAssets),
            abi.encode(true)
        );

        uint256 startingShares = vault.balanceOf(receiver);
        uint256 startingReceiptBalance = IReceiptV3(vault.receipt()).balanceOf(receiver, oraclePrice);

        if (err.length > 1) {
            vm.expectRevert(err);
            shares = 0;
            expectedAssets = 0;
        } else {
            vm.expectEmit(true, true, true, true);
            emit IReceiptVaultV1.Deposit(owner, receiver, expectedAssets, shares, oraclePrice, receiptInformation);
            if (receiptInformation.length > 0) {
                vm.expectEmit(false, false, false, true);
                emit IReceiptV3.ReceiptInformation(owner, oraclePrice, receiptInformation);
            }

            vm.expectCall(
                address(iAsset),
                abi.encodeWithSelector(IERC20.transferFrom.selector, owner, address(vault), expectedAssets)
            );
        }
        uint256 actualAssets = vault.mint(shares, receiver, minShareRatio, receiptInformation);

        // Check shares balance
        assertEqUint(vault.balanceOf(receiver), shares + startingShares);

        // Check receipt balance
        assertEqUint(IReceiptV3(vault.receipt()).balanceOf(receiver, oraclePrice), shares + startingReceiptBalance);

        assertEq(actualAssets, expectedAssets);
    }

    /// Test mint function
    function testMintBasic(
        string memory shareName,
        string memory shareSymbol,
        uint256 shares,
        uint256 oraclePrice,
        bytes memory receiptInformation
    ) external {
        (uint256 oraclePrice1, uint256 shares1) = bounds(oraclePrice, shares);
        uint256 minShareRatio1 = bound(oraclePrice, 0, oraclePrice1);
        checkMint(
            createVault(iVaultOracle, shareName, shareSymbol),
            ALICE,
            ALICE,
            oraclePrice1,
            shares1,
            minShareRatio1,
            receiptInformation,
            ""
        );
    }

    /// Test multiple mints under different oracle prices
    function testMultipleMints(
        string memory shareName,
        string memory shareSymbol,
        uint256 shares1,
        uint256 shares2,
        uint256 oraclePrice1,
        uint256 oraclePrice2,
        bytes memory receiptInformation1,
        bytes memory receiptInformation2
    ) external {
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);

        (uint256 oraclePrice1Bounded, uint256 shares1Bounded) = bounds(oraclePrice1, shares1);
        uint256 minShareRatio1 = bound(oraclePrice1, 0, oraclePrice1Bounded);
        checkMint(vault, ALICE, ALICE, oraclePrice1Bounded, shares1Bounded, minShareRatio1, receiptInformation1, "");

        (uint256 oraclePrice2Bounded, uint256 shares2Bounded) = bounds(oraclePrice2, shares2);
        uint256 minShareRatio2 = bound(oraclePrice2, 0, oraclePrice2Bounded);
        checkMint(vault, ALICE, ALICE, oraclePrice2Bounded, shares2Bounded, minShareRatio2, receiptInformation2, "");
    }

    /// Test mint reverts with min share ratio
    function testMintWithMinShareRatio(
        string memory shareName,
        string memory shareSymbol,
        uint256 shares,
        uint256 minShareRatio,
        uint256 oraclePrice,
        bytes memory receiptInformation
    ) external {
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);

        (uint256 oraclePriceBounded, uint256 sharesBounded) = bounds(oraclePrice, shares);
        uint256 minShareRatioBounded = bound(minShareRatio, oraclePriceBounded + 1, type(uint256).max);
        checkMint(
            vault,
            ALICE,
            ALICE,
            oraclePriceBounded,
            sharesBounded,
            minShareRatioBounded,
            receiptInformation,
            abi.encodeWithSelector(MinShareRatio.selector, minShareRatioBounded, oraclePriceBounded)
        );
    }

    /// Test mint to someone else
    function testMintSomeoneElse(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        uint256 shares,
        uint256 oraclePrice,
        bytes memory receiptInformation
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);

        (uint256 oraclePriceBounded, uint256 sharesBounded) = bounds(oraclePrice, shares);
        uint256 minShareRatio = bound(oraclePrice, 0, oraclePriceBounded);
        checkMint(vault, alice, bob, oraclePriceBounded, sharesBounded, minShareRatio, receiptInformation, "");
    }

    /// Test mint function with zero shares
    function testMintWithZeroShares(
        string memory shareName,
        string memory shareSymbol,
        uint256 minShareRatio,
        uint256 oraclePrice,
        bytes memory receiptInformation
    ) external {
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, shareName, shareSymbol);
        uint256 shares = 0;

        (uint256 oraclePriceBounded, uint256 sharesBounded) = bounds(oraclePrice, shares);
        uint256 minShareRatioBounded = bound(minShareRatio, 0, oraclePriceBounded);

        checkMint(
            vault,
            ALICE,
            ALICE,
            oraclePriceBounded,
            sharesBounded,
            minShareRatioBounded,
            receiptInformation,
            abi.encodeWithSelector(ZeroAssetsAmount.selector)
        );
    }

    receive() external payable {}

    fallback() external {}
}
