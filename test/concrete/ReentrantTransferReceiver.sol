// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IERC1155Receiver} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155Receiver.sol";
import {IERC1155} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155.sol";

/// @title ReentrantTransferReceiver
/// @notice TEST receiver that, during the ERC1155 acceptance callback, transfers
/// its OWN just-received tokens onward (a legitimate transfer it is allowed to
/// make as the owner). Used to observe which operator identity the receipt
/// forwards to `authorizeReceiptTransfer3` for a transfer that re-enters during
/// a manager call.
contract ReentrantTransferReceiver is IERC1155Receiver {
    IERC1155 internal immutable iReceipt;
    address internal immutable iTo;
    uint256 internal immutable iId;
    uint256 internal immutable iAmount;

    constructor(IERC1155 receipt, address to, uint256 id, uint256 amount) {
        iReceipt = receipt;
        iTo = to;
        iId = id;
        iAmount = amount;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        iReceipt.safeTransferFrom(address(this), iTo, iId, iAmount, "");
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
