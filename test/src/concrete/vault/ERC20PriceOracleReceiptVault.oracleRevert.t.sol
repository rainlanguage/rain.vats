// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {IPriceOracleV2} from "src/interface/IPriceOracleV2.sol";

/// Oracle errors must surface from `_nextId` to the caller of mint / deposit /
/// previewMint / previewDeposit. The previous behaviour caught any revert and
/// returned 0, which collapsed downstream into a `Panic(0x12)` divide-by-zero
/// and erased the underlying selector (e.g. Pyth `StalePrice()`).
contract ERC20PriceOracleReceiptVaultOracleRevertTest is ERC20PriceOracleReceiptVaultTest {
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

    function testMintPropagatesOracleRevert(string memory name, string memory symbol, uint256 shares) external {
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);
        mockOracleRevert();
        vm.expectRevert(abi.encodeWithSelector(OracleError.selector));
        vault.mint(shares, address(this), 0, "");
    }

    function testDepositPropagatesOracleRevert(string memory name, string memory symbol, uint256 assets) external {
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);
        mockOracleRevert();
        vm.expectRevert(abi.encodeWithSelector(OracleError.selector));
        vault.deposit(assets, address(this), 0, "");
    }

    function testPreviewMintPropagatesOracleRevert(string memory name, string memory symbol, uint256 shares) external {
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);
        mockOracleRevert();
        vm.expectRevert(abi.encodeWithSelector(OracleError.selector));
        vault.previewMint(shares, 0);
    }

    function testPreviewDepositPropagatesOracleRevert(string memory name, string memory symbol, uint256 assets)
        external
    {
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);
        mockOracleRevert();
        vm.expectRevert(abi.encodeWithSelector(OracleError.selector));
        vault.previewDeposit(assets, 0);
    }

    /// ERC4626 spec: `max*` MUST NOT revert. The fix removes the try/catch
    /// around `priceOracle.price()` in `_nextId`; pin that none of the `max*`
    /// view functions route through `_nextId` so a reverting oracle never
    /// reaches that surface. `id` is bounded `> 0` because `_calculateRedeem`
    /// divides by share ratio and would panic on `id == 0` — that's a
    /// separate, oracle-independent invariant outside the scope of this fix.
    function testMaxFunctionsDoNotRevertOnOracleRevert(
        string memory name,
        string memory symbol,
        address receiver,
        address owner,
        uint256 id
    ) external {
        id = bound(id, 1, type(uint256).max);
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, name, symbol);
        mockOracleRevert();
        vault.maxDeposit(receiver);
        vault.maxMint(receiver);
        vault.maxRedeem(owner, id);
        vault.maxWithdraw(owner, id);
    }

    receive() external payable {}

    fallback() external payable {}
}
