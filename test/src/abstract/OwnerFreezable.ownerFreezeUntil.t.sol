// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OwnerFreezableOwnerFreezeUntilTest} from "test/abstract/OwnerFreezableOwnerFreezeUntilTest.t.sol";
import {TestOwnerFreezable} from "test/concrete/TestOwnerFreezable.sol";

contract OwnerFreezableTestOwnerFreezeUntil is OwnerFreezableOwnerFreezeUntilTest {
    constructor() {
        sAlice = address(123456);
        sBob = address(56789);
        vm.prank(sAlice);
        sOwnerFreezable = new TestOwnerFreezable();
    }
}
