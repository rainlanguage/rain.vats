// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ReceiptVaultConfigV2, ReceiptVault, ShareAction, ICLONEABLE_V2_SUCCESS} from "../../abstract/ReceiptVault.sol";
import {IPriceOracleV2} from "../../interface/IPriceOracleV2.sol";

/// @dev String ID for the ERC20PriceOracleReceiptVault storage location v1.
string constant ERC20_PRICE_ORACLE_RECEIPT_VAULT_STORAGE_ID = "rain.storage.erc20-price-oracle-receipt-vault.1";

/// @dev "rain.storage.erc20-price-oracle-receipt-vault.1"
bytes32 constant ERC20_PRICE_ORACLE_RECEIPT_VAULT_STORAGE_LOCATION =
    0x2c9a4f39bd2ddc349dc9f5c9e14a1013643d88625d35a2c983590afa580ee000;

/// @param priceOracle The price oracle that will be permanently bound to the
/// `ERC20PriceOracleVault` upon initialization.
/// @param receiptVaultConfig All config for the underlying receipt vault.
//forge-lint: disable-next-line(pascal-case-struct)
struct ERC20PriceOracleReceiptVaultConfigV2 {
    IPriceOracleV2 priceOracle;
    ReceiptVaultConfigV2 receiptVaultConfig;
}

/// @title ERC20PriceOracleVault
/// @notice An ERC4626 vault that mints shares according to a price oracle. As
/// shares are minted an associated ERC1155 NFT receipt is minted for the
/// asset depositor. The price oracle defines the amount of shares minted for
/// each deposit. The price oracle's base MUST be the deposited asset but the
/// price quote can be anything with a reliable oracle.
///
/// When the assets are withdrawn from the vault, the withdrawer must provide a
/// receipt from a previous deposit. The receipt amount and the original
/// shares minted are the same according to the price at the time of deposit.
/// The withdraw burns shares in return for assets as per ERC4626 AND burns the
/// receipt nominated by the withdrawer. The current price from the oracle is
/// irrelevant to withdrawals, only the receipt price is relevant.
///
/// As an analogy, consider buying a shirt on sale and then attempting to get a
/// refund for it after the sale ends. The store will refund the shirt but only
/// at the sale price marked on the receipt, NOT the current price of the same
/// shirt in-store.
///
/// This dual 20/1155 token system allows for a dynamic shares:asset mint
/// ratio on deposits without withdrawals ever being able to remove more assets
/// than were ever deposited.
///
/// Where this gets interesting is trying to discover a price for the ERC20
/// share token. The share token can't be worth 0 because it represents a claim
/// on a fully collateralized vault of assets. The share token also can't be
/// worth more than the current oracle price as it would allow depositors to
/// buy infinite assets. To see why this is true, consider that selling 1 asset
/// for a token pegged to the price buys the same number of pegged tokens as
/// depositing 1 asset yields minted shares. If 1 share buys more than 1 pegged
/// token then depositing 1 asset and selling the minted shares buys more than
/// 1 asset. This sets up an infinite loop which can't exist in a real market.
///
/// `ERC20PriceOracleVault` shares are useful primitives that convert a valuable
/// but volatile asset (e.g. wBTC/wETH) into shares that trade in a range (0, 1)
/// of some reference price. Such a primitive MAY have trustless utility in
/// domains such as providing liquidity on DEX/AMMs, non-liquidating leverage
/// for speculation, risk management, etc.
///
/// Note on use of price oracles and their centralisation and counterparty risk.
/// As there are no owner/admin keys on `ERC20PriceOracleVault` this represents
/// an existential risk to the system if the price feeds stop behaving correctly.
/// This is because the wrong number of shares will be minted upon deposit and
/// nobody can modify the oracle address read by the vault. Long term holders
/// of the share tokens are the most likely bagholders in the case of some
/// oracle degradation as the fundamental tokenomics could break in arbitrary
/// ways due to incorrect minting. Upgradeable and pausable oracles are the
/// biggest risk as the keys that maintain the oracle can be lost or stolen, or
/// corrupted somehow.
contract ERC20PriceOracleReceiptVault is ReceiptVault {
    /// Emitted when deployed and constructed.
    /// @param sender msg sender that deployed the contract.
    /// @param config All construction config.
    event ERC20PriceOracleReceiptVaultInitializedV2(address sender, ERC20PriceOracleReceiptVaultConfigV2 config);

    /// @param priceOracle The price oracle used for all minting calculations.
    /// @custom:storage-location erc7201:rain.storage.erc20-price-oracle-receipt-vault.1
    //forge-lint: disable-next-line(pascal-case-struct)
    struct ERC20PriceOracleReceiptVault7201Storage {
        IPriceOracleV2 priceOracle;
    }

    /// @dev Accessor for ERC20PriceOracleReceiptVault storage.
    function getStorageERC20PriceOracleReceiptVault()
        private
        pure
        returns (ERC20PriceOracleReceiptVault7201Storage storage s)
    {
        assembly ("memory-safe") {
            s.slot := ERC20_PRICE_ORACLE_RECEIPT_VAULT_STORAGE_LOCATION
        }
    }

    /// Initialization of the underlying receipt vault and price oracle.
    function initialize(bytes memory data) public virtual override initializer returns (bytes32) {
        ERC20PriceOracleReceiptVaultConfigV2 memory config = abi.decode(data, (ERC20PriceOracleReceiptVaultConfigV2));

        ERC20PriceOracleReceiptVault7201Storage storage s = getStorageERC20PriceOracleReceiptVault();

        s.priceOracle = IPriceOracleV2(config.priceOracle);

        __ReceiptVault_init(config.receiptVaultConfig);

        // Slither false positive due to needing receipt to be set so that the
        // event can be emitted with the correct data.
        // slither-disable-next-line reentrancy-events
        emit ERC20PriceOracleReceiptVaultInitializedV2(
            _msgSender(),
            ERC20PriceOracleReceiptVaultConfigV2({
                priceOracle: config.priceOracle, receiptVaultConfig: config.receiptVaultConfig
            })
        );

        return ICLONEABLE_V2_SUCCESS;
    }

    /// The ID is the current oracle price always, even if this ID has already
    /// been issued for some other receipt, it will simply result in multiple
    /// holders of receipts with amounts of the same ID.
    /// @inheritdoc ReceiptVault
    function _nextId() internal virtual override returns (uint256) {
        ERC20PriceOracleReceiptVault7201Storage storage s = getStorageERC20PriceOracleReceiptVault();

        // The oracle CAN error so we wrap in a try block to meet spec
        // requirement that calls MUST NOT revert.
        // This contract is never intended to hold gas, it's only here to pay the
        // oracles that might need to be paid. The contract's assets are always
        // ERC20 tokens. This means the slither detector here is a false positive.
        //slither-disable-next-line arbitrary-send-eth
        try s.priceOracle.price{value: address(this).balance}()
        // slither puts false positives on `try/catch/returns`.
        // https://github.com/crytic/slither/issues/511
        //slither-disable-next-line
        returns (
            uint256 price
        ) {
            return price;
        } catch {
            // Depositing assets while the price oracle is erroring will give 0
            // shares (a real deposit will revert due to 0 ratio).
            return 0;
        }
    }

    /// The ID-less share ratio is the current oracle price, which will be the
    /// ID in the case of a real deposit.
    /// @inheritdoc ReceiptVault
    function _shareRatioUserAgnostic(uint256 id, ShareAction shareAction)
        internal
        view
        virtual
        override
        returns (uint256)
    {
        (shareAction);
        return id;
    }
}
