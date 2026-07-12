// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICloneableFactoryV3} from "rain-factory-0.1.5/src/interface/ICloneableFactoryV3.sol";
import {CloneFactory} from "rain-factory-0.1.5/src/concrete/CloneFactory.sol";
import {Test} from "forge-std-1.16.1/src/Test.sol";
import {Receipt as ReceiptContract} from "../../src/concrete/receipt/Receipt.sol";
import {ERC20PriceOracleReceipt} from "../../src/concrete/receipt/ERC20PriceOracleReceipt.sol";
import {DATA_URI_BASE64_PREFIX} from "../../src/concrete/receipt/Receipt.sol";
import {Base64} from "solady-0.1.26/src/utils/Base64.sol";

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

    ICloneableFactoryV3 internal immutable iFactory;
    ReceiptContract internal immutable iReceiptImplementation;
    ERC20PriceOracleReceipt internal immutable iErc20PriceOracleReceiptImplementation;

    /// A fresh salt for each shared-factory clone, so repeated deterministic
    /// clones of the same implementation never collide on their CREATE2 address.
    uint256 private sCloneSalt;

    constructor() {
        iFactory = new CloneFactory();
        iReceiptImplementation = new ReceiptContract();
        iErc20PriceOracleReceiptImplementation = new ERC20PriceOracleReceipt();
    }

    /// Deterministically clones and initializes `implementation` via the shared
    /// factory with a fresh salt, so sibling clones in a test never collide.
    function cloneReceipt(address implementation, bytes memory data) internal returns (address) {
        return iFactory.cloneDeterministic(implementation, data, bytes32(sCloneSalt++));
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
