// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Receipt, DATA_URI_BASE64_PREFIX, Base64} from "./Receipt.sol";
import {LibFixedPointDecimalFormat} from "rain.math.fixedpoint/lib/format/LibFixedPointDecimalFormat.sol";
import {ZeroReceiptId} from "../../error/ErrReceipt.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {FIXED_POINT_ONE} from "rain.math.fixedpoint/lib/FixedPointDecimalConstants.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

/// @dev The default symbol for the reference asset.
string constant DEFAULT_REFERENCE_ASSET_SYMBOL = "USD";

/// @dev The default URL for redeeming receipts.
string constant DEFAULT_REDEEM_URL = "";

/// @dev The default brand name for the receipt.
string constant DEFAULT_BRAND_NAME = "";

/// @dev The default SVG URI for the receipt.
string constant DEFAULT_SVG_URI = "";

contract ERC20PriceOracleReceipt is Receipt {
    /// @inheritdoc Receipt
    function uri(uint256 id) public view virtual override returns (string memory) {
        if (id == 0) {
            revert ZeroReceiptId();
        }
        //forge-lint: disable-next-line(mixed-case-variable)
        string memory redeemURL = _redeemURL();
        //forge-lint: disable-next-line(mixed-case-variable)
        string memory redeemURLPhrase = bytes(redeemURL).length > 0 ? string.concat(" Redeem at ", redeemURL, ".") : "";

        string memory brandName = _brandName();
        string memory brandNamePhrase = bytes(brandName).length > 0 ? string.concat(brandName, " ") : "";

        //forge-lint: disable-next-line(mixed-case-variable)
        string memory receiptSVGURI = _receiptSVGURI();
        //forge-lint: disable-next-line(mixed-case-variable)
        string memory receiptSVGURIPhrase =
            bytes(receiptSVGURI).length > 0 ? string.concat("\"image\":\"", receiptSVGURI, "\",") : "";

        string memory idString = LibFixedPointDecimalFormat.fixedPointToDecimalString(id);

        string memory nameString = string.concat(
            "Receipt for ",
            brandNamePhrase,
            "lock at ",
            idString,
            " ",
            _referenceAssetSymbol(),
            " per ",
            _vaultAssetSymbol(),
            "."
        );

        bytes memory json = bytes(
            string.concat(
                "{\"decimals\":",
                Strings.toString(_vaultDecimals()),
                ",\"description\":\"1 of these receipts can be burned alongside 1 ",
                _vaultShareSymbol(),
                " to redeem ",
                LibFixedPointDecimalFormat.fixedPointToDecimalString(
                        LibFixedPointDecimalArithmeticOpenZeppelin.fixedPointDiv(
                            FIXED_POINT_ONE, id, Math.Rounding.Floor
                        )
                    ),
                " of ",
                _vaultAssetSymbol(),
                ".",
                redeemURLPhrase,
                "\",",
                receiptSVGURIPhrase,
                "\"name\":\"",
                nameString,
                "\"}"
            )
        );

        return string.concat(DATA_URI_BASE64_PREFIX, Base64.encode(json));
    }

    /// Provides the SVG URI for the receipt. Can be overridden to provide a
    /// custom SVG URI. Default is an empty string, which will not include an
    /// image in the metadata json.
    //forge-lint: disable-next-line(mixed-case-function)
    function _receiptSVGURI() internal view virtual returns (string memory) {
        return DEFAULT_SVG_URI;
    }

    /// Provides the symbol of the reference asset that mint amounts are valued
    /// in. Can be overridden to provide a custom reference asset symbol. Default
    /// is "USD".
    function _referenceAssetSymbol() internal view virtual returns (string memory) {
        return DEFAULT_REFERENCE_ASSET_SYMBOL;
    }

    /// Provides the URL for redeeming receipts. Can be overridden to provide a
    /// custom redeem URL. Default is an empty string, which will not include a
    /// redeem URL in the metadata json.
    //forge-lint: disable-next-line(mixed-case-function)
    function _redeemURL() internal view virtual returns (string memory) {
        return DEFAULT_REDEEM_URL;
    }

    /// Provides the brand name for the receipt. Can be overridden to provide a
    /// custom brand name. Default is an empty string, which will not include a
    /// brand name in the metadata json.
    function _brandName() internal view virtual returns (string memory) {
        return DEFAULT_BRAND_NAME;
    }
}
