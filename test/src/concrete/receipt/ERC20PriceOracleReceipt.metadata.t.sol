// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ReceiptFactoryTest} from "test/abstract/ReceiptFactoryTest.sol";
import {TestReceiptManager} from "test/concrete/TestReceiptManager.sol";
import {ERC20PriceOracleReceipt} from "src/concrete/receipt/ERC20PriceOracleReceipt.sol";
import {LibFixedPointDecimalFormat} from "rain.math.fixedpoint/lib/format/LibFixedPointDecimalFormat.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {FIXED_POINT_ONE} from "rain.math.fixedpoint/lib/FixedPointDecimalConstants.sol";
import {ZeroReceiptId} from "src/error/ErrReceipt.sol";
import {LibConformString} from "rain.string/lib/mut/LibConformString.sol";
import {CMASK_QUOTATION_MARK, CMASK_PRINTABLE, CMASK_BACKSLASH} from "rain.string/lib/parse/LibParseCMask.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// This contract is used to test the metadata of the `Receipt` contract.
/// As all the overridden functions are internal, we need to create a new
/// contract that inherits from `Receipt` and exposes these functions; we can't
/// just mock `Receipt`.
contract MutableMetadataReceipt is ERC20PriceOracleReceipt {
    string internal sVaultShareSymbol;
    string internal sVaultAssetSymbol;
    //forge-lint: disable-next-line(mixed-case-variable)
    string internal sReceiptSVGURI;
    string internal sReferenceAssetSymbol;
    //forge-lint: disable-next-line(mixed-case-variable)
    string internal sRedeemURL;
    string internal sBrandName;

    function setVaultShareSymbol(string memory vaultShareSymbol) external {
        sVaultShareSymbol = vaultShareSymbol;
    }

    function setVaultAssetSymbol(string memory vaultAssetSymbol) external {
        sVaultAssetSymbol = vaultAssetSymbol;
    }

    //forge-lint: disable-next-line(mixed-case-function,mixed-case-variable)
    function setReceiptSVGURI(string memory receiptSVGURI) external {
        sReceiptSVGURI = receiptSVGURI;
    }

    function setReferenceAssetSymbol(string memory referenceAssetSymbol) external {
        sReferenceAssetSymbol = referenceAssetSymbol;
    }

    //forge-lint: disable-next-line(mixed-case-function,mixed-case-variable)
    function setRedeemURL(string memory redeemURL) external {
        sRedeemURL = redeemURL;
    }

    function setBrandName(string memory brandName) external {
        sBrandName = brandName;
    }

    function _vaultShareSymbol() internal view override returns (string memory) {
        return sVaultShareSymbol;
    }

    function _vaultAssetSymbol() internal view override returns (string memory) {
        return sVaultAssetSymbol;
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function _receiptSVGURI() internal view override returns (string memory) {
        return sReceiptSVGURI;
    }

    function _referenceAssetSymbol() internal view override returns (string memory) {
        return sReferenceAssetSymbol;
    }

    //forge-lint: disable-next-line(mixed-case-function)
    function _redeemURL() internal view override returns (string memory) {
        return sRedeemURL;
    }

    function _brandName() internal view override returns (string memory) {
        return sBrandName;
    }
}

contract ERC20PriceOracleReceiptMetadataTest is ReceiptFactoryTest {
    function testReceiptURIZeroError() external {
        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ERC20PriceOracleReceipt receipt = ERC20PriceOracleReceipt(
            iFactory.clone(address(iErc20PriceOracleReceiptImplementation), abi.encode(address(testManager)))
        );

        vm.expectRevert(ZeroReceiptId.selector);
        receipt.uri(0);
    }

    function testReceiptURI(uint256 id) external {
        vm.assume(id != 0);

        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ERC20PriceOracleReceipt receipt = ERC20PriceOracleReceipt(
            iFactory.clone(address(iErc20PriceOracleReceiptImplementation), abi.encode(address(testManager)))
        );

        string memory uri = receipt.uri(id);

        Metadata memory metadataJson = decodeMetadataURI(uri);

        string memory idInvFormatted = LibFixedPointDecimalFormat.fixedPointToDecimalString(
            LibFixedPointDecimalArithmeticOpenZeppelin.fixedPointDiv(FIXED_POINT_ONE, id, Math.Rounding.Floor)
        );
        assertEq(
            metadataJson.description,
            string.concat(
                "1 of these receipts can be burned alongside 1 TRM to redeem ", idInvFormatted, " of TRMAsset."
            )
        );

        assertEq(metadataJson.decimals, 18);
        assertEq(
            metadataJson.name,
            string.concat(
                "Receipt for lock at ", LibFixedPointDecimalFormat.fixedPointToDecimalString(id), " USD per TRMAsset."
            )
        );
    }

    function testReceiptName() external {
        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ERC20PriceOracleReceipt receipt = ERC20PriceOracleReceipt(
            iFactory.clone(address(iErc20PriceOracleReceiptImplementation), abi.encode(address(testManager)))
        );

        assertEq(receipt.name(), "TRM Receipt");
    }

    function testReceiptSymbol() external {
        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ERC20PriceOracleReceipt receipt = ERC20PriceOracleReceipt(
            iFactory.clone(address(iErc20PriceOracleReceiptImplementation), abi.encode(address(testManager)))
        );

        assertEq(receipt.symbol(), "TRM RCPT");
    }

    function testOverriddenMetadataWithoutImage(
        uint256 id,
        string memory vaultShareSymbol,
        string memory vaultAssetSymbol,
        string memory redeemUrl,
        string memory brandName,
        string memory referenceAssetSymbol,
        uint8 decimals
    ) external {
        vm.assume(id != 0);
        MutableMetadataReceipt receipt = new MutableMetadataReceipt();

        {
            uint256 mask = CMASK_PRINTABLE & ~(CMASK_QUOTATION_MARK | CMASK_BACKSLASH);

            LibConformString.conformStringToMask(vaultShareSymbol, mask, 0x100);
            LibConformString.conformStringToMask(vaultAssetSymbol, mask, 0x100);
            LibConformString.conformStringToMask(redeemUrl, mask, 0x100);
            LibConformString.conformStringToMask(brandName, mask, 0x100);
            LibConformString.conformStringToMask(referenceAssetSymbol, mask, 0x100);

            receipt.setVaultShareSymbol(vaultShareSymbol);
            receipt.setVaultAssetSymbol(vaultAssetSymbol);
            receipt.setRedeemURL(redeemUrl);
            receipt.setBrandName(brandName);
            receipt.setReferenceAssetSymbol(referenceAssetSymbol);
        }

        vm.mockCall(address(0), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(uint8(decimals)));
        vm.expectCall(address(0), abi.encodeWithSelector(IERC20Metadata.decimals.selector));
        string memory uri = receipt.uri(id);
        Metadata memory metadata = decodeMetadataURI(uri);

        string memory idInvFormatted = LibFixedPointDecimalFormat.fixedPointToDecimalString(
            LibFixedPointDecimalArithmeticOpenZeppelin.fixedPointDiv(FIXED_POINT_ONE, id, Math.Rounding.Floor)
        );

        string memory redeemUrlPhrase = bytes(redeemUrl).length > 0 ? string.concat(" Redeem at ", redeemUrl, ".") : "";
        string memory brandNamePhrase = bytes(brandName).length > 0 ? string.concat(brandName, " ") : "";

        assertEq(metadata.decimals, decimals);
        assertEq(
            metadata.description,
            string.concat(
                "1 of these receipts can be burned alongside 1 ",
                vaultShareSymbol,
                " to redeem ",
                idInvFormatted,
                " of ",
                vaultAssetSymbol,
                ".",
                redeemUrlPhrase
            )
        );
        string memory nameString = string.concat(
            "Receipt for ",
            brandNamePhrase,
            "lock at ",
            LibFixedPointDecimalFormat.fixedPointToDecimalString(id),
            " ",
            referenceAssetSymbol,
            " per ",
            vaultAssetSymbol,
            "."
        );
        assertEq(metadata.name, nameString);
    }

    function testOverriddenMetadataWithImage(
        uint256 id,
        string memory vaultShareSymbol,
        string memory vaultAssetSymbol,
        string memory redeemUrl,
        string memory brandName,
        string memory referenceAssetSymbol,
        string memory receiptSvgUri,
        uint8 decimals
    ) external {
        vm.assume(bytes(receiptSvgUri).length > 0);
        vm.assume(id != 0);
        MutableMetadataReceipt receipt = new MutableMetadataReceipt();

        {
            uint256 mask = CMASK_PRINTABLE & ~(CMASK_QUOTATION_MARK | CMASK_BACKSLASH);

            LibConformString.conformStringToMask(vaultShareSymbol, mask, 0x100);
            LibConformString.conformStringToMask(vaultAssetSymbol, mask, 0x100);
            LibConformString.conformStringToMask(redeemUrl, mask, 0x100);
            LibConformString.conformStringToMask(brandName, mask, 0x100);
            LibConformString.conformStringToMask(referenceAssetSymbol, mask, 0x100);
            LibConformString.conformStringToMask(receiptSvgUri, mask, 0x100);

            receipt.setVaultShareSymbol(vaultShareSymbol);
            receipt.setVaultAssetSymbol(vaultAssetSymbol);
            receipt.setRedeemURL(redeemUrl);
            receipt.setBrandName(brandName);
            receipt.setReferenceAssetSymbol(referenceAssetSymbol);
            receipt.setReceiptSVGURI(receiptSvgUri);
        }

        vm.mockCall(address(0), abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(uint8(decimals)));
        vm.expectCall(address(0), abi.encodeWithSelector(IERC20Metadata.decimals.selector));

        string memory uri = receipt.uri(id);
        MetadataWithImage memory metadata = decodeMetadataURIWithImage(uri);

        string memory idInvFormatted = LibFixedPointDecimalFormat.fixedPointToDecimalString(
            LibFixedPointDecimalArithmeticOpenZeppelin.fixedPointDiv(FIXED_POINT_ONE, id, Math.Rounding.Floor)
        );

        assertEq(metadata.decimals, decimals);

        {
            string memory redeemUrlPhrase =
                bytes(redeemUrl).length > 0 ? string.concat(" Redeem at ", redeemUrl, ".") : "";
            assertEq(
                metadata.description,
                string.concat(
                    "1 of these receipts can be burned alongside 1 ",
                    vaultShareSymbol,
                    " to redeem ",
                    idInvFormatted,
                    " of ",
                    vaultAssetSymbol,
                    ".",
                    redeemUrlPhrase
                )
            );
        }

        {
            string memory brandNamePhrase = bytes(brandName).length > 0 ? string.concat(brandName, " ") : "";
            string memory nameString = string.concat(
                "Receipt for ",
                brandNamePhrase,
                "lock at ",
                LibFixedPointDecimalFormat.fixedPointToDecimalString(id),
                " ",
                referenceAssetSymbol,
                " per ",
                vaultAssetSymbol,
                "."
            );
            assertEq(metadata.name, nameString);
        }

        assertEq(metadata.image, receiptSvgUri);
    }
}
