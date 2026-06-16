// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceipt} from "src/concrete/receipt/ERC20PriceOracleReceipt.sol";

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
