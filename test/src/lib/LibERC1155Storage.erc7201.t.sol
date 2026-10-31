// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibERC7201} from "test/lib/LibERC7201.sol";
import {Test} from "forge-std-1.17.0/src/Test.sol";
import {ERC20_STORAGE_LOCATION} from "src/lib/LibERC20Storage.sol";
import {ERC1155_STORAGE_LOCATION} from "src/lib/LibERC1155Storage.sol";

contract LibERC1155StorageERC7201Test is Test {
    /// The namespace is OZ's `@custom:storage-location erc7201:openzeppelin.storage.ERC1155`.
    function testErc1155SlotConstantMatchesDerivation() external pure {
        assertEq(ERC1155_STORAGE_LOCATION, LibERC7201.idForString("openzeppelin.storage.ERC1155"));
    }

    function testErc1155SlotConstantDistinctFromErc20SlotConstant() external pure {
        assertTrue(ERC1155_STORAGE_LOCATION != ERC20_STORAGE_LOCATION);
    }
}
