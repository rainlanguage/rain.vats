// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IERC1155Receiver} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155Receiver.sol";
import {IERC1155} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155.sol";

/// @title ApprovalSpoofReceiver
/// @notice TEST receiver that re-enters the receipt during the ERC1155
/// acceptance callback and grants `attacker` operator approval. Pre-#309-fix
/// this was spoofed onto the depositor (the overridden `_msgSender()`);
/// post-fix it lands on this contract itself (the true `msg.sender`).
contract ApprovalSpoofReceiver is IERC1155Receiver {
    IERC1155 internal immutable iReceipt;
    address internal immutable iAttacker;

    constructor(IERC1155 receipt, address attacker) {
        iReceipt = receipt;
        iAttacker = attacker;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        iReceipt.setApprovalForAll(iAttacker, true);
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
