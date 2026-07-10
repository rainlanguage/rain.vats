// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IAuthorizeV1} from "src/interface/IAuthorizeV1.sol";
import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";
import {CERTIFY} from "src/concrete/vault/OffchainAssetReceiptVault.sol";

/// @dev Minimal view of the vault the observer reads back during the callback.
interface ICertifiableObserverVault {
    function isCertificationExpired() external view returns (bool);
}

/// @title CertifyObserverAuthorizer
/// @notice TEST authorizer that is a REAL, owner-swappable, reentrant dependency
/// targeting the `certify` call site (row 14). `certify` is NOT `nonReentrant`;
/// its safety rests on `certifiedUntil` being written BEFORE the authorize call.
/// This authorizer re-enters the vault (a read) during the `CERTIFY` authorize
/// hook and records the certification state it observes.
///
/// Because the new `certifiedUntil` is written before authorize runs, a fresh
/// future certification MUST already be visible: `isCertificationExpired()` reads
/// `false` from inside the hook. If the write were ordered after the authorize
/// call, the observer would still see the stale `true`. The recorded value is the
/// discriminator.
contract CertifyObserverAuthorizer is IAuthorizeV1, IERC165 {
    ICertifiableObserverVault internal iVault;
    bool public observed;
    bool public observedExpiredDuringCertify;

    /// Point the observer at the vault whose state it reads back.
    function setVault(ICertifiableObserverVault vault) external {
        iVault = vault;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IAuthorizeV1).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /// @inheritdoc IAuthorizeV1
    function authorize(address, bytes32 permission, bytes memory) external override {
        if (permission == CERTIFY && address(iVault) != address(0)) {
            observed = true;
            observedExpiredDuringCertify = iVault.isCertificationExpired();
        }
    }
}
