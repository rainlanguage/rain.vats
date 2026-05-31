// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IERC1155Receiver} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155Receiver.sol";
import {IERC1155} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155.sol";

/// @title ReentrantLeakReceiver
/// @notice TEST receiver that, during the ERC1155 acceptance callback, tries to
/// forward its just-received tokens to an attacker by re-entering the receipt.
/// It swallows any revert (try/catch) and records whether the nested transfer
/// succeeded, so a test can assert the transfer was DENIED — i.e. the privileged
/// operator of the outer manager call did not leak into this re-entrant transfer
/// (it authorized as this contract, which is unprivileged).
contract ReentrantLeakReceiver is IERC1155Receiver {
    IERC1155 internal immutable iReceipt;
    address internal immutable iAttacker;
    uint256 internal immutable iId;
    uint256 internal immutable iAmount;

    bool public nestedAttempted;
    bool public nestedSucceeded;
    /// Revert data captured from the denied nested transfer. Captured in THIS
    /// contract's frame (which does not revert), so it survives even though the
    /// nested call's own state changes are rolled back.
    bytes public nestedRevertData;

    constructor(IERC1155 receipt, address attacker, uint256 id, uint256 amount) {
        iReceipt = receipt;
        iAttacker = attacker;
        iId = id;
        iAmount = amount;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        nestedAttempted = true;
        try iReceipt.safeTransferFrom(address(this), iAttacker, iId, iAmount, "") {
            nestedSucceeded = true;
        } catch (bytes memory err) {
            nestedSucceeded = false;
            nestedRevertData = err;
        }
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
