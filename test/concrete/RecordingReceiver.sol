// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IERC1155Receiver} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155Receiver.sol";

/// @title RecordingReceiver
/// @notice TEST receiver that records the `operator` it is told about in the
/// ERC1155 acceptance callback, so tests can assert the callback observes the
/// true caller rather than a spoofed identity.
contract RecordingReceiver is IERC1155Receiver {
    address public lastOperator;

    function onERC1155Received(address operator, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        lastOperator = operator;
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address operator, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        returns (bytes4)
    {
        lastOperator = operator;
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}
