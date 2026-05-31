// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IReceiptV3} from "src/interface/IReceiptV3.sol";
import {IReceiptManagerV2} from "src/interface/IReceiptManagerV2.sol";

/// @title SpyReceiptManager
/// @notice TEST manager that authorizes ALL transfers and records the
/// `(operator, from, to)` of the most recent `authorizeReceiptTransfer3` call,
/// so tests can assert exactly what operator identity the receipt forwards. The
/// `mint`/`burn`/`transferFrom` helpers forward to the manager-gated functions
/// with an explicit `sender`.
contract SpyReceiptManager is IReceiptManagerV2 {
    address public lastOperator;
    address public lastFrom;
    address public lastTo;

    function authorizeReceiptTransfer3(address operator, address from, address to, uint256[] memory, uint256[] memory)
        external
    {
        lastOperator = operator;
        lastFrom = from;
        lastTo = to;
    }

    function mint(IReceiptV3 receipt, address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
    {
        receipt.managerMint(sender, account, id, amount, data);
    }

    function burn(IReceiptV3 receipt, address sender, address account, uint256 id, uint256 amount, bytes memory data)
        external
    {
        receipt.managerBurn(sender, account, id, amount, data);
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
