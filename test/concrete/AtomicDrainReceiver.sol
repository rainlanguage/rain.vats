// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IERC1155Receiver} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155Receiver.sol";
import {IERC1155} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155.sol";

/// @title AtomicDrainReceiver
/// @notice TEST receiver that re-enters the receipt during the ERC1155
/// acceptance callback and tries to drain the victim's pre-existing receipts in
/// the same transaction. Pre-#309-fix the spoof made `_msgSender()` the victim,
/// so OZ's `from == sender` check passed; post-fix `_msgSender()` is this
/// contract, so the transfer reverts with `ERC1155MissingApprovalForAll`.
contract AtomicDrainReceiver is IERC1155Receiver {
    IERC1155 internal immutable iReceipt;
    address internal immutable iVictim;
    address internal immutable iAttacker;
    uint256 internal immutable iDrainId;
    uint256 internal immutable iDrainAmount;

    constructor(IERC1155 receipt, address victim, address attacker, uint256 drainId, uint256 drainAmount) {
        iReceipt = receipt;
        iVictim = victim;
        iAttacker = attacker;
        iDrainId = drainId;
        iDrainAmount = drainAmount;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        iReceipt.safeTransferFrom(iVictim, iAttacker, iDrainId, iDrainAmount, "");
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}
