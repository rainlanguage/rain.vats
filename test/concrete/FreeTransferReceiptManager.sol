// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IReceiptV3} from "src/interface/IReceiptV3.sol";
import {IReceiptManagerV2} from "src/interface/IReceiptManagerV2.sol";

/// @title FreeTransferReceiptManager
/// @notice TEST manager that authorizes ALL receipt transfers (no-op
/// `authorizeReceiptTransfer3`) — the worst case for the #309 spoofing bug,
/// where receipts are unconditionally transferable and there is no per-transfer
/// authorization hook to lean on (e.g. any vault inheriting the base
/// `ReceiptVault` no-op authorizer). `mint` takes an explicit `sender` so tests
/// can drive the operator directly, the way a vault passes `_msgSender()` (the
/// depositor) into `managerMint`.
contract FreeTransferReceiptManager is IReceiptManagerV2 {
    function authorizeReceiptTransfer3(address, address, address, uint256[] memory, uint256[] memory) external {}

    function mint(IReceiptV3 receipt, address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
    {
        receipt.managerMint(sender, account, id, amount, data);
    }
}
