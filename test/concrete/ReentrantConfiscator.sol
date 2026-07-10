// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IERC1155Receiver} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155Receiver.sol";

/// @dev Minimal view of the vault `confiscateReceipt` entrypoint re-entered.
interface IReentrantConfiscateVault {
    function confiscateReceipt(address confiscatee, uint256 id, uint256 targetAmount, bytes memory data)
        external
        returns (uint256);
}

/// @title ReentrantConfiscator
/// @notice TEST confiscator that is a REAL, reentrant recipient of a confiscated
/// receipt (row 16). `confiscateReceipt` is `nonReentrant` and moves the receipt
/// to `to == _msgSender()` (this contract) via `managerTransferFrom`, which fires
/// the ERC1155 `onERC1155Received` acceptance callback. From inside that callback
/// this contract re-enters `confiscateReceipt`, which hits the held
/// `nonReentrant` guard and reverts with `ReentrancyGuardReentrantCall`. The
/// OpenZeppelin ERC1155 acceptance check bubbles that raw revert, so the whole
/// outer confiscation reverts.
contract ReentrantConfiscator is IERC1155Receiver {
    IReentrantConfiscateVault internal iVault;
    address internal iConfiscatee;
    uint256 internal iId;
    uint256 internal iTargetAmount;
    bool internal iEntered;

    /// Kick off the outer confiscation; this contract is the confiscator and so
    /// the recipient of the confiscated receipt.
    function attack(IReentrantConfiscateVault vault, address confiscatee, uint256 id, uint256 targetAmount) external {
        iVault = vault;
        iConfiscatee = confiscatee;
        iId = id;
        iTargetAmount = targetAmount;
        vault.confiscateReceipt(confiscatee, id, targetAmount, "");
    }

    /// @inheritdoc IERC1155Receiver
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        if (!iEntered && address(iVault) != address(0)) {
            iEntered = true;
            // Re-enter the guarded confiscation from inside the acceptance
            // callback; reverts on the nonReentrant guard.
            iVault.confiscateReceipt(iConfiscatee, iId, iTargetAmount, "");
        }
        return IERC1155Receiver.onERC1155Received.selector;
    }

    /// @inheritdoc IERC1155Receiver
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
