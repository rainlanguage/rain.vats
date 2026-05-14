// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IERC20} from "forge-std-1.16.1/src/interfaces/IERC20.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {LibFork} from "rain-flare-0.1.1/src/../test/fork/LibFork.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain-math-fixedpoint-0.2.0/src/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {Vm} from "forge-std-1.16.1/src/Vm.sol";
import {SFLR_CONTRACT} from "rain-flare-0.1.1/src/lib/sflr/LibSceptreStakedFlare.sol";
import {LibFtsoV2LTS, FLR_USD_FEED_ID} from "rain-flare-0.1.1/src/lib/lts/LibFtsoV2LTS.sol";
import {LibSceptreStakedFlare} from "rain-flare-0.1.1/src/lib/sflr/LibSceptreStakedFlare.sol";

library LibERC20PriceOracleReceiptVaultFork {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    uint256 constant BLOCK_NUMBER = 31725348;

    function setup(Vm vm, uint256 amount) internal returns (ERC20PriceOracleReceiptVault, address) {
        address alice = address(uint160(uint256(keccak256("ALICE"))));

        // Contract address on Flare
        ERC20PriceOracleReceiptVault vault =
            ERC20PriceOracleReceiptVault(payable(0xf0363b922299EA467d1E9c0F9c37d89830d9a4C4));

        vm.createSelectFork(LibFork.rpcUrlFlare(vm), BLOCK_NUMBER);

        vm.startPrank(alice);
        uint256 assets = vault.previewMint(amount, 0);

        IERC20(address(SFLR_CONTRACT)).approve(payable(vault), assets);

        return (vault, alice);
    }

    function getRate() internal returns (uint256) {
        uint256 usdPerFlr = LibFtsoV2LTS.ftsoV2LTSGetFeed(FLR_USD_FEED_ID, 60);
        uint256 sflrPerFlr = LibSceptreStakedFlare.getSFLRPerFLR18();
        uint256 rate = usdPerFlr.fixedPointDiv(sflrPerFlr, Math.Rounding.Ceil);

        return rate;
    }
}
