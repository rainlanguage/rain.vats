// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IERC1155Receiver} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155Receiver.sol";
import {IReceiptV3} from "src/interface/IReceiptV3.sol";

/// @title ManagerForgeReceiver
/// @notice TEST receiver that, during the ERC1155 acceptance callback, tries to
/// forge a manager-only `managerMint` while NOT being the manager. The fix does
/// not override `_msgSender()`, so `_onlyManager` sees this contract (the true
/// caller) rather than any stored/spoofed identity and reverts `OnlyManager`,
/// proving a malicious receiver cannot hijack the manager authorization from
/// inside a callback (e.g. to forge mints or confiscations).
contract ManagerForgeReceiver is IERC1155Receiver {
    IReceiptV3 internal immutable iReceipt;
    uint256 internal immutable iForgeId;
    uint256 internal immutable iForgeAmount;

    constructor(IReceiptV3 receipt, uint256 forgeId, uint256 forgeAmount) {
        iReceipt = receipt;
        iForgeId = forgeId;
        iForgeAmount = forgeAmount;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        // Attempt to mint to ourselves as if we were the manager. `_onlyManager`
        // must reject this because `_msgSender()` is this contract, not the
        // manager — it reverts the call and unwinds the outer manager operation.
        iReceipt.managerMint(address(this), address(this), iForgeId, iForgeAmount, "");
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
