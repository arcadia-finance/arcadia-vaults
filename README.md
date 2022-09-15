# Arcadia Finance Vaults

## Name
Arcadia Finance Vaults

## Docs
[Arcadia Finance Docs](https://arcadiafinance.notion.site)

## Description
Arcadia Finance is an Open Source protocol building solutions for digital assets, within collateral markets and the broader DeFi ecosystem. Arcadia Vaults are the core of our product suite and are responsible for locking, pricing and managing collateral.

Arcadia Vaults are user-controlled vaults enabling the on-chain pricing of any combination of different types of assets in one single base currency. Arcadia Vaults are non-custodial and allow its owner to actively manage the collateral contained within the Vault.

Arcadia Vaults themselves are according to the ERC-721 standard and can thus be represented as a single asset. This means that vaults are fully composable with existing infrastructure and are straightforward to integrate. Other benefits are that vaults can be tracked and monitored trough existing DeFi dashboards. Working according to this standard also opens up use-cases where vaults can be sold in their entirety on existing NFT marketplaces.

[Arcadia Lending](https://github.com/arcadia-finance/arcadia-lending) is the first financial product being built on top of the Arcadia Vaults.

This repo holds the Arcadia Finance Vault smart contracts.

# Arcadia Vaults

We have build a new DeFi primitive, *Arcadia Vaults*, enabling the on-chain pricing of any combination of different types of assets in one single base currency. Arcadia Vaults are non-custodial and allow its owner to actively manage the collateral contained within the Vault.

![Arcadia Vault overview](https://i.ibb.co/3vpkmQX/Arca-Fi-vault.png)

## Multi-asset

By allowing multiple types of assets to be deposited within a single vault, users, institutions & protocols can build a risk-diverse portfolio of assets under collateral.

In our current version, the following asset types are supported:

- ERC20s
- ERC4626s
- Uniswap & Sushiwap V2 LP
- Uniswap V3 LP
- Floor NFTs of select blue-chip collections (ERC721 & ERC1155)
- AAVE aTokens

The list of asset(types) that can be deposited in Arcadia Vaults is continuously being expanded. Our goal is for users to unlock capital of any quality, price-able DeFi primitive.

It is foreseen that vertical protocols integrating Arcadia Vaults can determine themselves which asset(types) are to be allowed as collateral.

## Future proof

Thanks to our modular pricing architecture, new token primitives and new token standards can be added to existing vaults without the need for any upgrade or asset migration.

![Modular pricing](https://i.ibb.co/kyWXZ6C/Arca-Fi-pricing.png)

## Pricing logic

As mentioned before, pricing logic is modular: a separate logic contract is deployed per type of token. We can distinguish two main categories, primary price feeds and derived price feeds.

For primary price feeds, we either have a direct decentralized price-oracle or we can rely on on-chain data via for instance Uniswap V3 TWAP prices. Examples of tokens for which we have primary price feeds are vanilla ERC20 tokens, or floor prices of NFT collectibles.

For derived price feeds (as the name implies), we don’t have a direct price feed. We first break down the asset in its underlying tokens for which we do have primary price feeds. Examples here are Uniswap LP positions or aTokens. 

All pricing logic is internally calculated with 18 decimals precision, relying on gas efficient and battle tested mathematical libraries. Pricing calculations have been tested to be flash-loan resistant. Where TWAP price feeds are used, risk assessment is performed in function of the capital needed to move the TWAP price, before the asset can be accepted as collateral.

## Non-custodial

An Arcadia Vault is represented by a user-owned smart contract. Arcadia Vaults are deployed through a proxy factory by the user. Doing so, the user becomes the sole owner of the deployed vault. Arcadia doesn’t take ownership of your assets and in no way can Arcadia withdraw, deposit or take any other action on the users’ behave.

## Vault upgradeability

Each deployed vault is linked to a certain vault logic contract. Vault logic will include the features vault owners can benefit from, for example, flash withdrawals, active collateral management, authorization delegation, … 

This vault logic is upgradable, but the user has full control if and when they want to upgrade to new logic. Should a user wish to use features newly introduced in an upcoming vault version, it will be up to them to upgrade the linked vault logic. Users will not have to migrate assets or close DeFi positions when doing so. 

Protocols building on top of Arcadia Vaults can determine which vault logic versions are allowed to be used for positions within their protocol. As such, highly-customized vault logic can be implemented for protocol-specific versions should this be required. 

The Arcadia protocol can in no way change the version of a user-owned deployed vault, or change any logic in existing vault logic.

## Composable

Arcadia Vaults themselves are according to the ERC-721 standard and can thus be represented as a single asset. This means that vaults are fully composable with existing infrastructure and are straightforward to integrate. Other benefits are that vaults can be tracked and monitored trough existing DeFi dashboards and it opens up use-cases where vaults can be sold in their entirety on existing NFT marketplaces.

## Active management of assets under collateral

Assets under collateral, or simply assets deposited in an Arcadia Vault, don’t have to be dormant assets. Depending on the vault logic version, assets within a vault can still actively be used within other DeFi protocols. In a first vault version, Arcadia foresees the following use-cases of active management:

- Swapping assets on Uniswap, Sushiswap and Curve. Users can diversify or change the risk-profile of the assets under collateral at any time.
- Stake or provide liquidity on approved DeFi protocols. External protocols used in this context will need to provide a receipt token which must be allowed as collateral as well within the Arcadia protocol. Examples can be providing liquidity on Aave (receiving approved aTokens), depositing assets on Yearn (receiving approved yTokens), …
- Change ranges for Uniswap V3 LP. Contrary to Uni V2 and similar AMMs, Uni V3 positions are meant to be more actively managed in terms of liquidity ranges. Users that deposit Uni V3 positions in their Arcadia Vaults will have the ability to change those liquidity ranges without having to withdraw their tokens first.
- Claim airdrops that depend on address-owned tokens. Arcadia Vaults will feature “flash withdrawals”. This feature can be used by the vault owner to claim airdrops using assets under collateral within their Arcadia Vault, without having to close DeFi positions to withdraw their tokens first.

## Gas efficiency

As many are aware, transaction costs of on-chain transactions are related to the amount of logic such a transaction needs to execute and how much reads & writes it needs to perform.

Design of an architecture that reduces gas costs as well as advanced gas optimizations are therefore a significant focus of our developments. Arcadia Vaults currently have only ~35% of the gas usage as compared with singe-asset vaults like MakerDAO. Nonetheless this success, we keep striving to bring down gas costs for users.

## Governance

Governance of the protocol will be used to shape and decide on the future developments within the Arcadia ecosystem. Examples of such developments could encompass pricing logic of new token primitives (Curve, Yearn…), new connectors to external protocols, new or partnering vertical protocols…

Arcadia aims to transition into a meaningful DAO upon reaching a certain level of maturity.

## Support
Support questions can be directed to our [Discord](https://discord.gg/PXcr8SEeTH). 

## Contributing
We are open to people looking to make contributions, both on the core contracts and on the front-end/dashboards.
If you'd like to get in touch with us before, please join [our Discord](https://discord.gg/PXcr8SEeTH) or send a mail to dev `[at]` arcadia.finance.

## License
The license can be found [here](LICENSE.md).