// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibConfigRegistry} from "rain-deploy-0.1.21/src/lib/LibConfigRegistry.sol";
import {ICloneableV2} from "rain-factory-0.2.4/src/interface/ICloneableV2.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    OffchainAssetReceiptVaultAuthorizerV1Config
} from "./OffchainAssetReceiptVaultAuthorizerV1.sol";

/// @dev Configuration for `ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1`.
/// @param authority The `ConfigRegistry` authority the admin binding is read
/// under.
/// @param adminName The name `authority` binds to `abi.encode(admin)`.
struct ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1Config {
    address authority;
    bytes32 adminName;
}

/// @title ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1
/// @notice `OffchainAssetReceiptVaultAuthorizerV1` whose initial admin is
/// resolved from the `ConfigRegistry` at `initialize`, so one init data serves
/// every chain while each chain binds its own admin. A later rebind does not
/// move the roles.
contract ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1 is OffchainAssetReceiptVaultAuthorizerV1 {
    /// @inheritdoc ICloneableV2
    /// @dev `data` is `abi.encode(ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1Config)`.
    function initialize(bytes memory data) external virtual override initializer returns (bytes32) {
        ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1Config memory config =
            abi.decode(data, (ConfigRegistryOffchainAssetReceiptVaultAuthorizerV1Config));
        //slither-disable-next-line unused-return
        (bytes memory admin,) =LibConfigRegistry.resolve(config.authority, config.adminName);
        return _initialize(OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: abi.decode(admin, (address))}));
    }
}
