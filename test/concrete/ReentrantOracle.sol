// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IPriceOracleV2} from "src/interface/IPriceOracleV2.sol";

/// @dev Minimal view of the vault `deposit` entrypoint the oracle re-enters.
interface IReentrantOracleVault {
    function deposit(uint256 assets, address receiver, uint256 depositMinShareRatio, bytes memory receiptInformation)
        external
        returns (uint256);
}

/// @title ReentrantOracle
/// @notice TEST price oracle that is a REAL, reentrant dependency read PRE-guard
/// (row 20). `_nextId` calls `priceOracle.price()` at the very top of `deposit`,
/// BEFORE `_deposit` acquires the `nonReentrant` guard. This oracle re-enters
/// `deposit` from inside `price()`.
///
/// Because the read happens before the guard, the nested deposit is a fresh,
/// independent, SUCCESSFUL deposit that locks its OWN price. The outer `price()`
/// call returns `iPriceOuter`; the re-entrant one returns `iPriceInner`. Distinct
/// prices produce distinct receipt ids, proving each deposit consumes a fresh
/// price into a concrete share amount with no staleness window. If `_nextId` were
/// read after the guard (the mutation this discriminates), the nested deposit
/// would revert on the guard and the whole flow would revert.
///
/// The re-entry is one-shot (`iEntered`) so the nested deposit's own `_nextId`
/// read returns `iPriceInner` without recursing.
contract ReentrantOracle is IPriceOracleV2 {
    IReentrantOracleVault internal iVault;
    uint256 internal immutable iPriceOuter;
    uint256 internal immutable iPriceInner;
    uint256 internal iReenterAssets;
    address internal iReenterReceiver;
    bool internal iEntered;

    constructor(uint256 priceOuter, uint256 priceInner) {
        iPriceOuter = priceOuter;
        iPriceInner = priceInner;
    }

    /// Point the oracle at the vault and configure the nested deposit.
    function configure(IReentrantOracleVault vault, uint256 reenterAssets, address reenterReceiver) external {
        iVault = vault;
        iReenterAssets = reenterAssets;
        iReenterReceiver = reenterReceiver;
    }

    /// @inheritdoc IPriceOracleV2
    function price() external payable override returns (uint256) {
        if (!iEntered && address(iVault) != address(0)) {
            iEntered = true;
            // Re-enter deposit from the pre-guard price read. Succeeds and locks
            // iPriceInner as its own receipt id.
            iVault.deposit(iReenterAssets, iReenterReceiver, 0, "");
            return iPriceOuter;
        }
        return iPriceInner;
    }

    /// @inheritdoc IPriceOracleV2
    fallback() external payable override {}

    /// @inheritdoc IPriceOracleV2
    receive() external payable override {}
}
