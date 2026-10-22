// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV2
} from "../../src/concrete/vault/OffchainAssetReceiptVault.sol";

/// Calls `_initialize` outside any initializer.
contract ExposedInitializeOffchainAssetReceiptVault is OffchainAssetReceiptVault {
    function exposedInitialize(OffchainAssetReceiptVaultConfigV2 memory config) external {
        _initialize(config);
    }

    function exposedInitializeAsInitializer(OffchainAssetReceiptVaultConfigV2 memory config) external initializer {
        _initialize(config);
    }
}
