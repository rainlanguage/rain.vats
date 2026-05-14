// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std-1.16.1/src/Test.sol";
import {CommonBase} from "forge-std-1.16.1/src/Base.sol";

contract Order is CommonBase {
    function secp256k1Order() public pure returns (uint256) {
        return SECP256K1_ORDER;
    }
}

library LibUniqueAddressesGenerator {
    function generateUniqueAddresses(Vm vm, uint256 seed) internal returns (address) {
        return vm.addr((seed % ((new Order()).secp256k1Order() - 1)) + 1);
    }

    // Generates two unique addresses from the provided seeds
    function generateUniqueAddresses(Vm vm, uint256 aliceSeed, uint256 bobSeed) internal returns (address, address) {
        address alice = generateUniqueAddresses(vm, aliceSeed);
        address bob = generateUniqueAddresses(vm, bobSeed);
        vm.assume(alice != bob);

        return (alice, bob);
    }

    // Generates three unique addresses from the provided seeds
    function generateUniqueAddresses(Vm vm, uint256 aliceSeed, uint256 bobSeed, uint256 carolSeed)
        internal
        returns (address, address, address)
    {
        address alice = generateUniqueAddresses(vm, aliceSeed);
        address bob = generateUniqueAddresses(vm, bobSeed);
        address carol = generateUniqueAddresses(vm, carolSeed);
        vm.assume(alice != bob);
        vm.assume(alice != carol);
        vm.assume(bob != carol);

        return (alice, bob, carol);
    }
}
