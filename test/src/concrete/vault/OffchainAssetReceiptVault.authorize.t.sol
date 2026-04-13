// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {
    OffchainAssetReceiptVault,
    IAuthorizeV1,
    Unauthorized,
    CERTIFY,
    CertifyStateChange
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {LibExtrospectERC1167Proxy} from "rain.extrospection/lib/LibExtrospectERC1167Proxy.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {
    OwnableUpgradeable as Ownable
} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract AlwaysAuthorize is IAuthorizeV1, IERC165 {
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IAuthorizeV1).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /// @inheritdoc IAuthorizeV1
    function authorize(address, bytes32, bytes memory) external pure override {}
}

contract OffchainAssetReceiptVaultAuthorizeTest is OffchainAssetReceiptVaultTest {
    /// Test that authorize contract is as initialized.
    function testAuthorizeContract(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);
        (bob);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        address authorizer = address(vault.authorizer());
        (bool isProxy, address implementation) = LibExtrospectERC1167Proxy.isERC1167Proxy(authorizer.code);
        assertTrue(isProxy);
        assertEq(implementation, address(iAuthorizerImplementation));
        CertifyStateChange memory certifyStateChange = CertifyStateChange({
            oldCertifiedUntil: 0, newCertifiedUntil: 1234, userCertifyUntil: 1234, forceUntil: true, data: ""
        });
        // Smoke test the authorizer NOT authorizing.
        vm.expectRevert(
            abi.encodeWithSelector(Unauthorized.selector, address(this), CERTIFY, abi.encode(certifyStateChange))
        );
        vault.certify(certifyStateChange.newCertifiedUntil, certifyStateChange.forceUntil, "");
    }

    /// Test that the owner can change the authorizer.
    function testChangeAuthorizer(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        address authorizer = address(vault.authorizer());
        (bool isProxy, address implementation) = LibExtrospectERC1167Proxy.isERC1167Proxy(authorizer.code);
        assertTrue(isProxy);
        assertEq(implementation, address(iAuthorizerImplementation));

        AlwaysAuthorize alwaysAuthorize = new AlwaysAuthorize();

        vm.prank(alice);
        vm.expectEmit(false, false, false, true);
        emit IAuthorizeV1.AuthorizerSet(address(alice), alwaysAuthorize);
        vault.setAuthorizer(alwaysAuthorize);

        authorizer = address(vault.authorizer());
        assertEq(authorizer, address(alwaysAuthorize));

        AlwaysAuthorize alwaysAuthorize2 = new AlwaysAuthorize();

        // Bob cannot set the authorizer.
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        vault.setAuthorizer(alwaysAuthorize2);
    }
}
