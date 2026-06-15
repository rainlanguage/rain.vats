// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IReceiptV3} from "src/interface/IReceiptV3.sol";
import {IReceiptManagerV2} from "src/interface/IReceiptManagerV2.sol";
import {TestReceiptManagerAsset} from "test/concrete/TestReceiptManagerAsset.sol";

/// Thrown when a transfer is not authorized.
/// @param from The transfer attempted from this address.
/// @param to The transfer attemped to this address.
error UnauthorizedTransfer(address from, address to);

/// @title TestReceiptManager
/// @notice TEST contract that can be the manager of an `IReceiptV3` and forward
/// function calls to the manager restricted functions on the receipt. Completely
/// insecure, intended for use only by the test harness to drive tests.
contract TestReceiptManager is IReceiptManagerV2 {
    /// The address of the test asset.
    address internal iAsset;

    /// The address that is authorized to send transfers.
    address internal sFrom;
    /// The address that is authorized to receive transfers.
    address internal sTo;

    uint8 internal sDecimals;

    constructor() {
        iAsset = address(new TestReceiptManagerAsset());
        sDecimals = 18;
    }

    /// Anon can set the from address.
    /// @param from The new `from` address.
    function setFrom(address from) external {
        sFrom = from;
    }

    /// Anon can set the to address.
    /// @param to The new `to` address.
    function setTo(address to) external {
        sTo = to;
    }

    /// Only transfers between `from` and `to` are authorized.
    /// @inheritdoc IReceiptManagerV2
    function authorizeReceiptTransfer3(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external view {
        (ids, amounts, operator);
        if (from != sFrom) {
            revert UnauthorizedTransfer(from, to);
        }
        if (to != sTo) {
            revert UnauthorizedTransfer(from, to);
        }
    }

    /// Exposes `IReceiptV3.managerMint` to anon.
    /// @param receipt The `IReceiptV3` contract to call.
    /// @param account As per `IReceiptV3.managerMint`.
    /// @param id As per `IReceiptV3.managerMint`.
    /// @param amount As per `IReceiptV3.managerMint`.
    /// @param data As per `IReceiptV3.managerMint`.
    function managerMint(IReceiptV3 receipt, address account, uint256 id, uint256 amount, bytes memory data) external {
        receipt.managerMint(msg.sender, account, id, amount, data);
    }

    /// Exposes `IReceiptV3.managerBurn` to anon.
    /// @param receipt The `IReceiptV3` contract to call.
    /// @param account As per `IReceiptV3.managerBurn`.
    /// @param id As per `IReceiptV3.managerBurn`.
    /// @param amount As per `IReceiptV3.managerBurn`.
    /// @param receiptInformation As per `IReceiptV3.managerBurn`.
    function managerBurn(
        IReceiptV3 receipt,
        address account,
        uint256 id,
        uint256 amount,
        bytes memory receiptInformation
    ) external {
        receipt.managerBurn(msg.sender, account, id, amount, receiptInformation);
    }

    /// Exposes `IReceiptV3.managerTransferFrom` to anon.
    /// @param receipt The `IReceiptV3` contract to call.
    /// @param from As per `IReceiptV3.managerTransferFrom`.
    /// @param to As per `IReceiptV3.managerTransferFrom`.
    /// @param id As per `IReceiptV3.managerTransferFrom`.
    /// @param amount As per `IReceiptV3.managerTransferFrom`.
    /// @param data As per `IReceiptV3.managerTransferFrom`.
    function managerTransferFrom(
        IReceiptV3 receipt,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external {
        receipt.managerTransferFrom(msg.sender, from, to, id, amount, data);
    }

    function name() external pure returns (string memory) {
        return "TestReceiptManager";
    }

    function symbol() external pure returns (string memory) {
        return "TRM";
    }

    function asset() external view returns (address) {
        return iAsset;
    }

    function decimals() external view returns (uint8) {
        return sDecimals;
    }

    function setDecimals(uint8 newDecimals) external {
        sDecimals = newDecimals;
    }
}
