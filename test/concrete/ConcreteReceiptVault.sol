// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ReceiptVault, ReceiptVaultConfigV2} from "../../src/abstract/ReceiptVault.sol";
import {ICLONEABLE_V2_SUCCESS} from "rain-factory-0.1.5/src/interface/ICloneableV2.sol";

contract ConcreteReceiptVault is ReceiptVault {
    function initialize(bytes calldata data) external virtual override initializer returns (bytes32) {
        ReceiptVaultConfigV2 memory config = abi.decode(data, (ReceiptVaultConfigV2));
        __ReceiptVault_init(config);
        return ICLONEABLE_V2_SUCCESS;
    }
}
