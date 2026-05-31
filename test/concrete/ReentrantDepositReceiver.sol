// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IERC1155Receiver} from "@openzeppelin-contracts-5.6.1/token/ERC1155/IERC1155Receiver.sol";

/// @dev Minimal view of the vault `deposit` entrypoint the receiver re-enters.
interface IReentrantDepositTarget {
    function deposit(uint256 assets, address receiver, uint256 depositMinShareRatio, bytes memory receiptInformation)
        external
        returns (uint256);
}

/// @title ReentrantDepositReceiver
/// @notice TEST receiver that re-enters the VAULT's `deposit` during the ERC1155
/// acceptance callback fired by the outer deposit's receipt mint. The vault's
/// `_deposit` is `nonReentrant`, so the nested deposit must revert with
/// `ReentrancyGuardReentrantCall`, reverting the whole outer deposit. This is the
/// end-to-end guard that backstops the #309 callback surface: even with the fix
/// making the callback observe the true caller, the shared reentrancy guard also
/// forbids re-entering any value-moving vault flow from inside the callback.
contract ReentrantDepositReceiver is IERC1155Receiver {
    IReentrantDepositTarget internal immutable iVault;
    uint256 internal immutable iAssets;

    constructor(IReentrantDepositTarget vault, uint256 assets) {
        iVault = vault;
        iAssets = assets;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        iVault.deposit(iAssets, address(this), 0, "");
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
