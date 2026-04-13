// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {ICloneableV2} from "rain.factory/interface/ICloneableV2.sol";
import {IAuthorizeV1} from "src/interface/IAuthorizeV1.sol";
import {
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1
} from "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

contract OffchainAssetReceiptVaultPaymentMintAuthorizerV1IERC165Test is Test {
    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1IERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(ICloneableV2).interfaceId);
        vm.assume(badInterfaceId != type(IAuthorizeV1).interfaceId);
        vm.assume(badInterfaceId != type(IAccessControl).interfaceId);

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            new OffchainAssetReceiptVaultPaymentMintAuthorizerV1();
        assertTrue(authorizer.supportsInterface(type(IERC165).interfaceId));
        assertTrue(authorizer.supportsInterface(type(ICloneableV2).interfaceId));
        assertTrue(authorizer.supportsInterface(type(IAuthorizeV1).interfaceId));
        assertTrue(authorizer.supportsInterface(type(IAccessControl).interfaceId));

        assertFalse(authorizer.supportsInterface(badInterfaceId));
    }
}
