// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Receipt} from "../../src/concrete/receipt/Receipt.sol";

/// A `Receipt` whose asset-symbol metadata does not read the vault's
/// `address(0)` asset, as an off-chain asset vault requires.
contract TestOffchainAssetReceipt is Receipt {
    string internal constant ASSET_SYMBOL = "OFFCHAIN";

    function _vaultAssetSymbol() internal pure override returns (string memory) {
        return ASSET_SYMBOL;
    }
}
