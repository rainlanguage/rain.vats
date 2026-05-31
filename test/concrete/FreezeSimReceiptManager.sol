// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IReceiptV3} from "src/interface/IReceiptV3.sol";
import {IReceiptManagerV2} from "src/interface/IReceiptManagerV2.sol";

/// Thrown by `FreezeSimReceiptManager` when a non-mint/burn transfer is
/// attempted by an operator that is not the privileged handler.
error NotPrivileged(address operator);

/// @title FreezeSimReceiptManager
/// @notice TEST manager that simulates a frozen system: mints and burns (the
/// `address(0)` legs) are always allowed for repair, but any peer-to-peer
/// receipt transfer is allowed ONLY when the authorization `operator` is the
/// designated privileged handler (e.g. a confiscator). It lets tests prove the
/// security consequence of the #309 consume-once operator — that a privileged
/// outer operator does NOT leak into a transfer re-entering during an acceptance
/// callback (which would otherwise authorize with the leaked privilege).
contract FreezeSimReceiptManager is IReceiptManagerV2 {
    address public immutable privileged;
    address public lastOperator;

    constructor(address privileged_) {
        privileged = privileged_;
    }

    function authorizeReceiptTransfer3(address operator, address from, address to, uint256[] memory, uint256[] memory)
        external
    {
        lastOperator = operator;
        // Minting (`from == 0`) and burning (`to == 0`) are always permitted so
        // holdings can be set up and repaired.
        if (from == address(0) || to == address(0)) {
            return;
        }
        // Otherwise only the privileged handler may move receipts.
        if (operator != privileged) {
            revert NotPrivileged(operator);
        }
    }

    function mint(IReceiptV3 receipt, address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
    {
        receipt.managerMint(sender, account, id, amount, data);
    }

    function transferFrom(
        IReceiptV3 receipt,
        address sender,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external {
        receipt.managerTransferFrom(sender, from, to, id, amount, data);
    }
}
