// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable-5.7.0/token/ERC20/ERC20Upgradeable.sol";

/// @dev The ERC-7201 namespaced storage root for OpenZeppelin's
/// `ERC20Upgradeable`, computed in-source from the spec formula rather than
/// hardcoded as a hex literal. The compiler evaluates this at deploy time,
/// so there is no runtime cost versus a hardcoded hex.
bytes32 constant ERC20_STORAGE_LOCATION =
    keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff));

/// @dev The slot holding OZ's raw `_totalSupply`: offset 2 from the ERC-7201
/// root, per the `ERC20Upgradeable` struct layout documented on
/// `LibERC20Storage`. Every read and write of the accumulator goes through
/// this constant.
bytes32 constant ERC20_TOTAL_SUPPLY_SLOT = bytes32(uint256(ERC20_STORAGE_LOCATION) + 2);

/// @title LibERC20Storage
/// @notice Direct storage access to OpenZeppelin ERC20Upgradeable internals.
/// Used by the rebase migration system to write balances and totalSupply
/// without going through `_update`, which would emit spurious Transfer events
/// and create reentrancy concerns.
///
/// SAFETY: This is tightly coupled to OZ v5's ERC20Upgradeable ERC-7201
/// storage layout. The struct layout at the namespaced slot is:
///   slot+0: mapping(address => uint256) _balances
///   slot+1: mapping(address => mapping(address => uint256)) _allowances
///   slot+2: uint256 _totalSupply
/// If OZ changes this layout, this library MUST be updated.
library LibERC20Storage {
    /// @dev Derive the storage slot holding `_balances[account]`, i.e.
    /// `keccak256(account || ERC20_STORAGE_LOCATION)` per Solidity's
    /// mapping slot rule with the base at offset 0 of the namespaced
    /// struct.
    function balanceSlot(address account) private pure returns (bytes32) {
        bytes32 base = ERC20_STORAGE_LOCATION;
        bytes32 slot;
        assembly ("memory-safe") {
            mstore(0x00, account)
            mstore(0x20, base)
            slot := keccak256(0x00, 0x40)
        }
        return slot;
    }

    /// @notice Read the account's raw underlying balance at OZ's ERC-7201
    /// `_balances` slot. This is whatever value OZ's `_update` has last
    /// written — no semantic overlay is applied here.
    /// @param account The account to read.
    /// @return The raw value of `_balances[account]`.
    function underlyingBalance(address account) internal view returns (uint256) {
        bytes32 slot = balanceSlot(account);
        uint256 result;
        assembly ("memory-safe") {
            result := sload(slot)
        }
        return result;
    }

    /// @notice Write the account's raw underlying balance at OZ's ERC-7201
    /// `_balances` slot. Bypasses OZ's `_update` entirely — no `Transfer`
    /// event, no `_totalSupply` adjustment.
    /// @param account The account to write.
    /// @param newBalance The new value to write to `_balances[account]`.
    function setUnderlyingBalance(address account, uint256 newBalance) internal {
        bytes32 slot = balanceSlot(account);
        assembly ("memory-safe") {
            sstore(slot, newBalance)
        }
    }

    /// @notice Read the raw underlying `_totalSupply` at OZ's ERC-7201 slot.
    /// This is whatever value OZ's `_update` has last written; no semantic
    /// overlay is applied here. Consumers that need a rebase-aware or
    /// otherwise-derived supply figure must compute it themselves.
    /// @return The raw value of OZ's `_totalSupply`.
    function underlyingTotalSupply() internal view returns (uint256) {
        bytes32 slot = ERC20_TOTAL_SUPPLY_SLOT;
        uint256 supply;
        assembly ("memory-safe") {
            supply := sload(slot)
        }
        return supply;
    }

    /// @notice Write the raw underlying `_totalSupply` at OZ's ERC-7201 slot.
    /// Bypasses OZ's `_update` entirely — no `Transfer` event, no balance
    /// adjustment.
    ///
    /// @dev This slot is NOT the reported supply: `StoxReceiptVault.totalSupply()`
    /// is the rebase-aware `LibTotalSupply.effectiveTotalSupply()`. Writing
    /// here keeps OZ's internals self-consistent and does not change what the
    /// token reports.
    ///
    /// @param newTotalSupply The new value to write to `_totalSupply`.
    function setUnderlyingTotalSupply(uint256 newTotalSupply) internal {
        bytes32 slot = ERC20_TOTAL_SUPPLY_SLOT;
        assembly ("memory-safe") {
            sstore(slot, newTotalSupply)
        }
    }

    /// @notice Shift OZ's raw `_totalSupply` by the delta a rebase applied to
    /// one account's balance, preserving OZ's own `_totalSupply == Σ _balances`
    /// invariant.
    ///
    /// @dev The lazy rebase migration rewrites `_balances` behind OZ's back.
    /// OZ's `_update` still subtracts from the raw slot **unchecked** on burn
    /// and adds to it **checked** on mint, so a slot left stale by a rebase
    /// drifts below the true balance sum, wraps to ~`2**256` on the first burn
    /// that exceeds it, and from then on reverts every mint with `Panic(0x11)`
    /// — silently, because `totalSupply()`, `balanceOf()` and all events keep
    /// agreeing with each other. The slot has no write path other than
    /// mint/burn, so recovery would need a beacon implementation upgrade.
    /// See `StoxReceiptVaultRawTotalSupplyTest` (Protofire H01).
    ///
    /// Arithmetic is checked. `supply >= oldBalance` always holds (the account's
    /// balance is one of the summands of the supply), so the only reachable
    /// revert is an overflow on `supply + newBalance`, which means the split
    /// multiplier has pushed supply past `uint256` — `LibRebaseMath` would
    /// already have hit that on the individual balance, and failing closed is
    /// the correct outcome.
    ///
    /// @param oldBalance The account's stored balance before rasterization.
    /// @param newBalance The account's stored balance after rasterization.
    function applyBalanceDeltaToTotalSupply(uint256 oldBalance, uint256 newBalance) internal {
        setUnderlyingTotalSupply(underlyingTotalSupply() + newBalance - oldBalance);
    }

    /// @notice OZ's own `ERC20Storage` struct at its ERC-7201 root, typed with
    /// OZ's declaration so the `_name` / `_symbol` offsets follow OZ rather
    /// than a local mirror. Used by code that runs in the vault's storage
    /// context without inheriting `ERC20Upgradeable` (the delegatecalled
    /// facet's `setUnderlying`) to overwrite the stored name and symbol.
    /// @return s Storage reference to OZ's `ERC20Storage` struct.
    function getStorage() internal pure returns (ERC20Upgradeable.ERC20Storage storage s) {
        bytes32 position = ERC20_STORAGE_LOCATION;
        assembly ("memory-safe") {
            s.slot := position
        }
    }
}
