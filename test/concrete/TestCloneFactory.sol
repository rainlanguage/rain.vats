// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

// `ICloneableFactoryV3` and `ICloneableFactoryV4` are imported for the
// `@inheritdoc` references on the functions they declare; `ICloneableFactoryV5`
// inherits rather than redeclares them, so the tags must name them and they
// must be in scope here.
import {ICloneableFactoryV3} from "rain-factory-0.1.31-pr271/src/interface/deprecated/ICloneableFactoryV3.sol";
import {ICloneableFactoryV4} from "rain-factory-0.1.31-pr271/src/interface/deprecated/ICloneableFactoryV4.sol";
import {ICloneableFactoryV5} from "rain-factory-0.1.31-pr271/src/interface/ICloneableFactoryV5.sol";
import {LibICloneableFactoryV4} from "rain-factory-0.1.31-pr271/src/lib/LibICloneableFactoryV4.sol";
import {LibICloneableFactoryV5} from "rain-factory-0.1.31-pr271/src/lib/LibICloneableFactoryV5.sol";

/// @title TestCloneFactory
/// @notice A concrete `ICloneableFactoryV5` for the test suite: every function
/// is a single delegation into `LibICloneableFactoryV4` or
/// `LibICloneableFactoryV5` and nothing else, which is the shape `rain-factory`
/// documents for a concrete factory.
///
/// `rain-factory` 0.1.6 and later ship only the interfaces and the library; the
/// concrete `CloneFactory` the tests used to deploy moved to
/// `rain-factory-deploy`. That package is not a dependency here because its
/// latest release pins an older `rain-factory` by path, so this fixture stands
/// in for it on the test side only. Nothing under `src/` deploys a factory.
contract TestCloneFactory is ICloneableFactoryV5 {
    /// @inheritdoc ICloneableFactoryV3
    function cloneDeterministic(address implementation, bytes calldata data, bytes32 salt) external returns (address) {
        return LibICloneableFactoryV4.cloneDeterministic(implementation, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV3
    function predictDeterministicAddress(address implementation, bytes32 salt, address deployer)
        external
        view
        returns (address)
    {
        return LibICloneableFactoryV4.predictDeterministicAddress(implementation, salt, deployer);
    }

    /// @inheritdoc ICloneableFactoryV4
    function cloneDeterministicOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        returns (address)
    {
        return LibICloneableFactoryV4.cloneDeterministicOpenSalt(implementation, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV4
    function predictDeterministicAddressOpenSalt(address implementation, bytes calldata data, bytes32 salt)
        external
        view
        returns (address)
    {
        return LibICloneableFactoryV4.predictDeterministicAddressOpenSalt(implementation, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV5
    function beaconProxyDeterministicOpenSalt(address beacon, bytes calldata data, bytes32 salt)
        external
        returns (address)
    {
        return LibICloneableFactoryV5.beaconProxyDeterministicOpenSalt(beacon, data, salt);
    }

    /// @inheritdoc ICloneableFactoryV5
    function predictBeaconProxyAddressOpenSalt(address beacon, bytes calldata data, bytes32 salt)
        external
        view
        returns (address)
    {
        return LibICloneableFactoryV5.predictBeaconProxyAddressOpenSalt(beacon, data, salt);
    }
}
