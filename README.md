# rain.vats

VATS = Verifiable Asset Tokenization System.

## High Level (VATS)

There are two dominiant _representation_ systems in defi today:

- Fungible tokens: Ideal for trading/investment concerns such as liquidity,
  interoperatiblity, transerring, swapping, both large/small scale operations,
  generalized/bulk behaviours, etc.
- Non-fungible tokens: Ideal for auditability/provenance concerns such as mapping
  onchain to external/offchain entities, _specific_ mint/burn histories,
  "physical allocation"-esque legalities, etc.

For many use cases, one of these will be the clear preferred representation. For
example an onchain token minted purely to represent voting power in some DAO fits
a fungible model well. A token minted to represent individual and unique
collectable items fits the non fungible model best.

Some use cases need properties of both, notably many RWAs (real world asset) have
concerns relevant to both representations.

Almost every RWA, except those that already have global adoption and relevance
such as USD pegged stables, or gold backed tokens, have hard liquidity
constraints. Hard in the sense that there is always some upper limit of capital
that can be absorbed by the RWA meaningfully due to physical constraints. For
example, we could tokenise a house that could be sold for $500k and then
investors and traders can buy/sell tokens ultimately backed by the sale price of
the house offchain setting a floor on the token value, but the maximum size of
their trades at a liquid price can only ever be some small percentage of $500k.
It is hard to imagine a $100k swap going through without significant slippage,
as this represents 20% of the entire supply.

If every asset on the planet needs to be individually tokenized and build a
liquid market for itself, with its own risk/reward profiles, market participants,
issuer/management, etc. then it is clear that pragmatically the friction is too
high for adoption by anyone except the most motivated and resource rich
participants.

From this perspective we clearly favour the standard ERC20 fungible token. We are
going to want to start grouping similar assets together. Perhaps 100 houses
in the same area of similar investment quality can back a token with a $50M
liquidity cap, rather than the $500k from a single house.

This is certainly an improvement for trading, but it introduces a meta problem.
The nature of a basket of assets is fundamentally different from an individual
asset.

Consider our above example, we have 100 houses in the same area. In one sense
this makes them all similar to each other, which justifies their "sameness", an
important feature of any fungible token. In another sense we have simply shifted
our liquidity problem offchain. What if there is a bank run on the token and a
significant percentage of these 100 houses all need to be sold in a short period
of time in order to maintain the backing? Selling 1 house in a good area is
relatively simple, although still might take months, selling 100 houses in the
same area could take many years to do in a way that doesn't crash the sale price
due to sudden oversupply.

This example even applies to assets that are generally considered to have
essentially infinite liquidity and are commodities, such as gold or silver. There
exists many times more claims on gold and silver in the financial system via.
derivatives and other "paper" than there is real gold and silver sitting in
vaults that can be physically delivered if there was ever a global bank run on
the metals. Different setup, same problem, the quality of the aggregate asset
during times of stress is only as strong as its weakest component.

So now we want some kind of ability to curate or assess the quality of the
investment at the level of a token that is behaving more like a fund that holds
many assets than some specific asset. The ERC20 token doesn't provide any
information or guard rails around the many individual specific assets offchain or
elsewhere that back the liquidity.

For this kind of provenance and audit trail we would typically use a non-fungible
token standard such as ERC721 or ERC1155.

The VATS approach specifies that, at the point of minting and burning, we always
create and destroy _both_ an ERC20 and associated ERC1155 pairwise in equal
amount. This protects the "bridge" between the tokenized representation and the
externally referenced assets, while allowing fully decoupled behaviour of both
tokens onchain outside the bridge processes.

As both the ERC20 and ERC1155 tokens exist onchain and are not simply handled
offchain, e.g. via some system of event emissions, there can be onchain guard
rails and governance enforced at the smart contract layer. The VATS concept is
agnostic to the specifics of governance, other than the requirement that tokens
are created and destroyed in lockstep to maintain supply integrity.

V: Verifiable => "Anyone" can compare the onchain ERC1155 NFT IDs/data/supply
  against the offchain assets to check the integrity of the system.
A: Asset => The system is designed to work referencing/backed by real assets.
T: Tokenization => The system is fundamentally a tokenization approach to
  building liquidity for the referenced assets.
S: System => This is a system of tokens, both an ERC20 and ERC1155, and cannot
  provide all promised features/guarantees without multiple tokens bound together
  logically somehow (e.g. at mint/burn time)

## Implementation

Defines and implements the concept of a "Receipt Vault".

Very similar to an ERC4626 vault https://eips.ethereum.org/EIPS/eip-4626.

The main difference is that each mint/burn has an associated ERC1155 receipt
representing the mint/burn event https://eips.ethereum.org/EIPS/eip-1155.

The ID of the mint/burn receipt somehow encodes the identity of the mint/burn
event, and the amount matches the number of ERC20 shares that are minted/burned.

This implies that the ERC1155 receipts are also burned 1:1 with ERC20 shares
if/when a burn happens, and that receipt holders are the only users capable of
burning shares.

The utility of this approach is that the receipt allows information about the
_justification_ of the mint to be encoded onchain.

For example, if this was used for some real world asset (RWA) like a bar of gold,
the 1155 receipt can map its ID to some offchain evidence of the bar of gold in
custody in a vault somewhere.

If some bar was to be taken out of custody, the associated receipt must be burned,
which means the associated ERC20 shares must be burned. This ensures that the
fungible shares in circulation are all backed 1:1 with mint/burn justifications.

`OffchainAssetReceiptVault.sol` is a concrete implementation of RWA minting.

The same approach can be applied to onchain collateral, allowing for vault
tokenomics other than the standard ERC4626 style approach of minting shares in
the same ratio as deposits.

This can allow for novel onchain mechanics where mint/burning of ERC20 tokens is
decoupled from previous/future mint burns, such as referencing external oracles
for share rates, and recording that rate in the associated ERC1155.

`ERC20PriceOracleReceiptVault.sol` is a concrete implementation of onchain oracle
minting.

## Dev stuff

### Local environment & CI

Uses nixos.

Install `nix develop` - https://nixos.org/download.html.

Run `nix develop` in this repo to drop into the shell. Please ONLY use the nix
version of `foundry` for development, to ensure versions are all compatible.

Read the `flake.nix` file to find some additional commands included for dev and
CI usage.

## Legal stuff

Everything is under DecentraLicense 1.0 (DCL-1.0) which can be found in `LICENSES/`.

This is basically `CAL-1.0` which is an open source license
https://opensource.org/license/cal-1-0

The non-legal summary of DCL-1.0 is that the source is open, as expected, but
also user data in the systems that this code runs on must also be made available
to those users as relevant, and that private keys remain private.

Roughly it's "not your keys, not your coins" aware, as close as we could get in
legalese.

This is the default situation on permissionless blockchains, so shouldn't require
any additional effort by dev-users to adhere to the license terms.

This repo is REUSE 3.2 compliant https://reuse.software/spec-3.2/ and compatible
with `reuse` tooling (also available in the nix shell here).

```
nix develop -c rainix-sol-legal
```

## Contributions

Contributions are welcome **under the same license** as above.

Contributors agree and warrant that their contributions are compliant.