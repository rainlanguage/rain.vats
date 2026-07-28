// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {IPriceOracleV2} from "src/interface/IPriceOracleV2.sol";
import {IERC20} from "forge-std-1.16.1/src/interfaces/IERC20.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain-math-fixedpoint-0.2.0/src/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

/// @dev ERC-4626 spec compliance tests for ERC20PriceOracleReceiptVault.
/// The ERC-4626 spec mandates that `max*` functions MUST NOT revert under any
/// input — for this vault that includes a broken (reverting/stale) oracle,
/// because `maxDeposit`/`maxMint` are pure and `maxWithdraw`/`maxRedeem`
/// derive the share ratio from the receipt `id`, never from the oracle.
/// `preview*` functions must return the same result as the corresponding
/// mutating call under the same state. `convertTo*` functions are
/// caller-agnostic and round down, so a round trip can only lose value to
/// rounding, never create it.
contract ERC20PriceOracleReceiptVaultERC4626SpecTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Arbitrary custom selector standing in for any oracle-side error
    /// (e.g. Pyth `StalePrice()` = 0x19abf40e).
    error OracleError();

    function mockOracleRevert() internal {
        vm.mockCallRevert(
            address(iVaultOracle),
            abi.encodeWithSelector(IPriceOracleV2.price.selector),
            abi.encodeWithSelector(OracleError.selector)
        );
    }

    function mockDepositTransfer(address from, ERC20PriceOracleReceiptVault vault, uint256 assets) internal {
        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, address(vault), assets),
            abi.encode(true)
        );
    }

    /// ERC-4626 maxWithdraw MUST NOT revert for any (owner, id) pair. For this
    /// vault the share ratio is the receipt `id` itself, so `id == 0` is the
    /// zero-share-ratio edge that would divide by zero in `_calculateRedeem`
    /// without the guard in `maxWithdraw`.
    function testMaxWithdrawAnyIdDoesNotRevert(string memory name, string memory symbol, address owner, uint256 id)
        external
    {
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);
        vault.maxWithdraw(owner, id);
    }

    /// ERC-4626 maxWithdraw MUST NOT revert for id == 0 specifically, and the
    /// max withdrawable at a zero share ratio is 0.
    function testMaxWithdrawZeroIdDoesNotRevert(string memory name, string memory symbol, address owner) external {
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);
        assertEqUint(vault.maxWithdraw(owner, 0), 0);
    }

    /// ERC-4626 maxRedeem MUST NOT revert for any (owner, id) pair.
    /// maxRedeem returns receipt.balanceOf(owner, id) which is 0 for any id
    /// with no deposit; the ERC-1155 balanceOf view call is safe for all ids.
    function testMaxRedeemAnyIdDoesNotRevert(string memory name, string memory symbol, address owner, uint256 id)
        external
    {
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);
        vault.maxRedeem(owner, id);
    }

    /// ERC-4626 maxDeposit MUST NOT revert for any receiver.
    function testMaxDepositAnyOwnerDoesNotRevert(string memory name, string memory symbol, address owner) external {
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);
        vault.maxDeposit(owner);
    }

    /// ERC-4626 maxMint MUST NOT revert for any receiver.
    function testMaxMintAnyOwnerDoesNotRevert(string memory name, string memory symbol, address owner) external {
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);
        vault.maxMint(owner);
    }

    /// ERC-4626 max* MUST NOT revert even when the oracle itself reverts
    /// (bricked feed, stale price, lost keys). The oracle error must stay
    /// contained to the mint-side functions that genuinely need a price;
    /// none of the max* functions consult the oracle.
    function testMaxFunctionsDoNotRevertWhenOracleReverts(
        string memory name,
        string memory symbol,
        address owner,
        uint256 id
    ) external {
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);
        mockOracleRevert();

        // Prove the broken-oracle premise: a call that does consult the
        // oracle surfaces the oracle error.
        vm.expectRevert(abi.encodeWithSelector(OracleError.selector));
        vault.previewDeposit(1e18, 0);

        assertEqUint(vault.maxDeposit(owner), type(uint256).max);
        assertEqUint(vault.maxMint(owner), type(uint256).max);
        assertEqUint(vault.maxWithdraw(owner, id), 0);
        assertEqUint(vault.maxWithdraw(owner, 0), 0);
        assertEqUint(vault.maxRedeem(owner, id), 0);
    }

    /// ERC-4626 max* MUST NOT revert under a broken oracle even when the owner
    /// holds shares and receipts from an earlier deposit, and must still
    /// report the real withdrawable/redeemable amounts: withdrawal pricing
    /// comes from the receipt id, not the (now broken) oracle.
    function testMaxFunctionsDoNotRevertWhenOracleRevertsAfterDeposit(
        uint256 aliceSeed,
        string memory name,
        string memory symbol,
        uint256 assets,
        uint256 oraclePrice,
        bytes memory receiptInformation
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);
        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        assets = bound(assets, 2, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);
        setVaultOraclePrice(oraclePrice);
        mockDepositTransfer(alice, vault, assets);

        vm.startPrank(alice);
        uint256 shares = vault.deposit(assets, alice, 0, receiptInformation);
        vm.stopPrank();

        mockOracleRevert();

        // Prove the broken-oracle premise: a call that does consult the
        // oracle surfaces the oracle error.
        vm.expectRevert(abi.encodeWithSelector(OracleError.selector));
        vault.previewDeposit(1e18, 0);

        assertEqUint(vault.maxDeposit(alice), type(uint256).max);
        assertEqUint(vault.maxMint(alice), type(uint256).max);
        assertEqUint(vault.maxRedeem(alice, oraclePrice), shares);
        assertEqUint(vault.maxWithdraw(alice, oraclePrice), shares.fixedPointDiv(oraclePrice, Math.Rounding.Floor));
    }

    /// ERC-4626: convertToShares and convertToAssets are inverses up to
    /// rounding. Both round down, so a round trip can only lose value, never
    /// create it, in either direction. The share ratio for this vault is the
    /// receipt `id`, fuzzed across the full price range.
    /// convertToShares is payable and calls Address.sendValue back to
    /// msg.sender; the prank must be an EOA (not the test contract) to accept
    /// that call.
    function testConvertToRoundTrip(
        string memory name,
        string memory symbol,
        uint256 aliceSeed,
        uint256 amount,
        uint256 id
    ) external {
        address alice = vm.addr(bound(aliceSeed, 1, type(uint128).max));
        id = bound(id, 1, type(uint128).max);
        amount = bound(amount, 1, type(uint128).max);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);

        vm.startPrank(alice);
        uint256 shares = vault.convertToShares(amount, id);
        vm.stopPrank();
        assertEqUint(shares, amount.fixedPointMul(id, Math.Rounding.Floor));

        uint256 assets = vault.convertToAssets(shares, id);
        assertEqUint(assets, shares.fixedPointDiv(id, Math.Rounding.Floor));

        // Round trip rounds down twice so can never create value.
        assertTrue(assets <= amount);

        // Inverse direction also never creates value.
        vm.startPrank(alice);
        uint256 sharesRoundTrip = vault.convertToShares(assets, id);
        vm.stopPrank();
        assertTrue(sharesRoundTrip <= shares);
    }

    /// ERC-4626: asset() must be immutable — must return the same address
    /// before and after deposit/withdraw operations.
    function testAssetImmutableAfterOperations(
        uint256 aliceSeed,
        string memory name,
        string memory symbol,
        uint256 assets,
        uint256 oraclePrice,
        bytes memory receiptInformation
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);
        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        assets = bound(assets, 2, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);
        address assetBefore = vault.asset();

        setVaultOraclePrice(oraclePrice);
        mockDepositTransfer(alice, vault, assets);

        vm.startPrank(alice);
        vault.deposit(assets, alice, 0, receiptInformation);
        assertEq(vault.asset(), assetBefore);

        uint256 withdrawAssets = vault.maxWithdraw(alice, oraclePrice);
        vm.assume(withdrawAssets > 0);
        vault.withdraw(withdrawAssets, alice, alice, oraclePrice, receiptInformation);
        assertEq(vault.asset(), assetBefore);
        vm.stopPrank();
    }

    /// ERC-4626: previewDeposit must return the same shares as deposit would
    /// credit under the same state (same caller, same args, same oracle
    /// price).
    function testPreviewDepositMatchesDeposit(
        uint256 aliceSeed,
        string memory name,
        string memory symbol,
        uint256 assets,
        uint256 oraclePrice,
        bytes memory receiptInformation
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);
        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        assets = bound(assets, 1, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);
        setVaultOraclePrice(oraclePrice);
        mockDepositTransfer(alice, vault, assets);

        vm.startPrank(alice);
        uint256 previewShares = vault.previewDeposit(assets, 0);
        uint256 actualShares = vault.deposit(assets, alice, 0, receiptInformation);
        assertEqUint(previewShares, actualShares);
        vm.stopPrank();
    }

    /// ERC-4626: previewRedeem must return the same assets as redeem would pay
    /// out under the same state. The share ratio is the receipt id (the oracle
    /// price at deposit time), not the current oracle price.
    function testPreviewRedeemMatchesRedeem(
        uint256 aliceSeed,
        string memory name,
        string memory symbol,
        uint256 assets,
        uint256 oraclePrice,
        bytes memory receiptInformation
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);
        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        assets = bound(assets, 2, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Floor) > 0);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);
        setVaultOraclePrice(oraclePrice);
        mockDepositTransfer(alice, vault, assets);

        vm.startPrank(alice);
        uint256 actualShares = vault.deposit(assets, alice, 0, receiptInformation);

        // preview is called before redeem to capture the pre-redeem state
        uint256 previewAssets = vault.previewRedeem(actualShares, oraclePrice);
        vm.assume(previewAssets > 0);
        uint256 actualAssets = vault.redeem(actualShares, alice, alice, oraclePrice, receiptInformation);
        assertEqUint(previewAssets, actualAssets);
        vm.stopPrank();
    }

    receive() external payable {}

    fallback() external payable {}
}
