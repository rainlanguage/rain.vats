// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault, DEPOSIT, WITHDRAW} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultAuthorizerV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";

/// @dev ERC-4626 spec compliance tests for OffchainAssetReceiptVault.
/// The ERC-4626 spec mandates that `max*` functions MUST NOT revert under any
/// input. `preview*` functions must return the same result as the corresponding
/// mutating call under the same state. `convertTo*` functions must be
/// caller-agnostic inverses.
contract OffchainAssetReceiptVaultERC4626SpecTest is OffchainAssetReceiptVaultTest {
    /// ERC-4626 maxWithdraw MUST NOT revert for any (owner, id) pair.
    /// For this vault _shareRatioUserAgnostic always returns 1e18, so no
    /// divide-by-zero risk exists at id == 0, but we pin the invariant so a
    /// future subclass override cannot silently regress it.
    function testMaxWithdrawAnyIdDoesNotRevert(string memory name, string memory symbol, address owner, uint256 id)
        external
    {
        OffchainAssetReceiptVault vault = createVault(address(this), name, symbol);
        vault.maxWithdraw(owner, id);
    }

    /// ERC-4626 maxWithdraw MUST NOT revert for id == 0 specifically.
    function testMaxWithdrawZeroIdDoesNotRevert(string memory name, string memory symbol, address owner) external {
        OffchainAssetReceiptVault vault = createVault(address(this), name, symbol);
        assertEqUint(vault.maxWithdraw(owner, 0), 0);
    }

    /// ERC-4626 maxRedeem MUST NOT revert for any (owner, id) pair.
    /// maxRedeem returns receipt.balanceOf(owner, id) which is 0 for any id
    /// with no deposit; the ERC-1155 balanceOf view call is safe for all ids.
    function testMaxRedeemAnyIdDoesNotRevert(string memory name, string memory symbol, address owner, uint256 id)
        external
    {
        OffchainAssetReceiptVault vault = createVault(address(this), name, symbol);
        vault.maxRedeem(owner, id);
    }

    /// ERC-4626 maxDeposit MUST NOT revert for any receiver.
    function testMaxDepositAnyOwnerDoesNotRevert(string memory name, string memory symbol, address owner) external {
        OffchainAssetReceiptVault vault = createVault(address(this), name, symbol);
        vault.maxDeposit(owner);
    }

    /// ERC-4626 maxMint MUST NOT revert for any receiver.
    function testMaxMintAnyOwnerDoesNotRevert(string memory name, string memory symbol, address owner) external {
        OffchainAssetReceiptVault vault = createVault(address(this), name, symbol);
        vault.maxMint(owner);
    }

    /// ERC-4626: convertToShares and convertToAssets must be inverses.
    /// For this vault (share ratio == 1e18) both are identity functions so
    /// convertToAssets(convertToShares(amount)) == amount for any non-zero id.
    /// convertToShares is payable and calls Address.sendValue back to msg.sender;
    /// the prank must be an EOA (not the test contract) to accept that call.
    function testConvertToInverses(
        string memory name,
        string memory symbol,
        uint256 aliceSeed,
        uint256 amount,
        uint256 id
    ) external {
        address alice = vm.addr(bound(aliceSeed, 1, type(uint128).max));
        id = bound(id, 1, type(uint256).max);
        amount = bound(amount, 1, type(uint128).max);

        OffchainAssetReceiptVault vault = createVault(alice, name, symbol);

        vm.startPrank(alice);
        uint256 shares = vault.convertToShares(amount, id);
        vm.stopPrank();
        uint256 assets = vault.convertToAssets(shares, id);
        assertEqUint(assets, amount);
    }

    /// ERC-4626: asset() must be immutable — must return the same address
    /// before and after deposit/withdraw operations.
    function testAssetImmutableAfterOperations(
        string memory name,
        string memory symbol,
        address alice,
        uint256 assets,
        bytes memory info
    ) external {
        vm.assume(alice != address(0));
        assets = bound(assets, 1, type(uint128).max);

        OffchainAssetReceiptVault vault = createVault(alice, name, symbol);
        address assetBefore = vault.asset();

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(WITHDRAW, alice);

        vault.deposit(assets, alice, 0, info);
        assertEq(vault.asset(), assetBefore);

        vault.withdraw(assets, alice, alice, 1, info);
        assertEq(vault.asset(), assetBefore);
        vm.stopPrank();
    }

    /// ERC-4626: previewDeposit must return the same shares as deposit would
    /// credit under the same state (same caller, same args, same vault state).
    /// For this vault (1:1, no oracle fee) previewDeposit(assets, 0) == assets.
    function testPreviewDepositMatchesDeposit(
        string memory name,
        string memory symbol,
        address alice,
        uint256 assets,
        bytes memory info
    ) external {
        vm.assume(alice != address(0));
        assets = bound(assets, 1, type(uint128).max);

        OffchainAssetReceiptVault vault = createVault(alice, name, symbol);

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);

        uint256 previewShares = vault.previewDeposit(assets, 0);
        uint256 actualShares = vault.deposit(assets, alice, 0, info);
        assertEqUint(previewShares, actualShares);
        vm.stopPrank();
    }

    /// ERC-4626: previewRedeem must return the same assets as redeem would pay
    /// out under the same state. For this 1:1 vault, previewRedeem(shares, id)
    /// == shares (since share ratio == 1e18 == identity).
    function testPreviewRedeemMatchesRedeem(
        string memory name,
        string memory symbol,
        address alice,
        uint256 assets,
        bytes memory info
    ) external {
        vm.assume(alice != address(0));
        assets = bound(assets, 1, type(uint128).max);

        OffchainAssetReceiptVault vault = createVault(alice, name, symbol);

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizerV1(address(vault.authorizer())).grantRole(WITHDRAW, alice);

        uint256 actualShares = vault.deposit(assets, alice, 0, info);

        // preview is called before redeem to capture the pre-redeem state
        uint256 previewAssets = vault.previewRedeem(actualShares, 1);
        uint256 actualAssets = vault.redeem(actualShares, alice, alice, 1, info);
        assertEqUint(previewAssets, actualAssets);
        vm.stopPrank();
    }
}
