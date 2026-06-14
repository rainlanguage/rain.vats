// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OwnerFreezable} from "src/abstract/OwnerFreezable.sol";

contract TestOwnerFreezable is OwnerFreezable {
    constructor() {
        __OwnerFreezable_init();
        _transferOwnership(msg.sender);
    }
}
