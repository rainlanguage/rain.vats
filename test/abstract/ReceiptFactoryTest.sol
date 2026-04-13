// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {Test} from "forge-std/Test.sol";
import {Receipt as ReceiptContract} from "../../src/concrete/receipt/Receipt.sol";
import {ERC20PriceOracleReceipt} from "../../src/concrete/receipt/ERC20PriceOracleReceipt.sol";
import {DATA_URI_BASE64_PREFIX} from "../../src/concrete/receipt/Receipt.sol";
import {Base64} from "solady/utils/Base64.sol";

contract ReceiptFactoryTest is Test {
    struct Metadata {
        uint8 decimals;
        string description;
        string name;
    }

    struct MetadataWithImage {
        uint8 decimals;
        string description;
        string image;
        string name;
    }

    ICloneableFactoryV2 internal immutable iFactory;
    ReceiptContract internal immutable iReceiptImplementation;
    ERC20PriceOracleReceipt internal immutable iErc20PriceOracleReceiptImplementation;

    constructor() {
        iFactory = new CloneFactory();
        iReceiptImplementation = new ReceiptContract();
        iErc20PriceOracleReceiptImplementation = new ERC20PriceOracleReceipt();
    }

    function decodeMetadataURI(string memory uri) internal pure returns (Metadata memory) {
        uint256 uriLength = bytes(uri).length;
        assembly ("memory-safe") {
            mstore(uri, 29)
        }
        assertEq(uri, DATA_URI_BASE64_PREFIX);
        assembly ("memory-safe") {
            uri := add(uri, 29)
            mstore(uri, sub(uriLength, 29))
        }

        string memory uriDecoded = string(Base64.decode(uri));
        bytes memory uriJsonData = vm.parseJson(uriDecoded);

        Metadata memory metadataJson = abi.decode(uriJsonData, (Metadata));
        return metadataJson;
    }

    function decodeMetadataURIWithImage(string memory uri) internal pure returns (MetadataWithImage memory) {
        uint256 uriLength = bytes(uri).length;
        assembly ("memory-safe") {
            mstore(uri, 29)
        }
        assertEq(uri, DATA_URI_BASE64_PREFIX);
        assembly ("memory-safe") {
            uri := add(uri, 29)
            mstore(uri, sub(uriLength, 29))
        }

        string memory uriDecoded = string(Base64.decode(uri));
        bytes memory uriJsonData = vm.parseJson(uriDecoded);

        MetadataWithImage memory metadataJson = abi.decode(uriJsonData, (MetadataWithImage));
        return metadataJson;
    }
}
