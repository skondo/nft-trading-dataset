# Table definitions

## Base tables
- `nft_trading_base`: transaction-level NFT trading records loaded from Zenodo.
- `nft_metadata_base`: collection-level metadata loaded from Zenodo.
- `usd_eth_raw`: raw Etherscan ETH/USD CSV loaded into BigQuery.
- `usd_eth_base`: normalized daily ETH/USD table derived from `usd_eth_raw`.

## Prepared transaction tables
- `nft_trading_usd`: transaction table with USD-converted price and fee fields.
- `nft_trading_usd_prefilter`: prefiltered version of `nft_trading_usd` after local and global outlier removal.
- `nft_trading_usd_filtered`: filtered version that retains collections with at least the configured number of active weeks.

## Regime table
- `regime_labels`: weekly regime labels (`pre-boom`, `boom`, `post-boom`).

## Factor-model tables
- `weekly_collection_panel_filtered`: collection-week panel with median price, total volume, and transaction count.
- `weekly_returns_vw`: collection-level weekly NFT return together with market and FX returns.
- `beta_alpha_estimates`: full-period HAC-robust two-factor estimates.
- `beta_alpha_estimates_by_regime`: regime-wise HAC-robust two-factor estimates.

## Clustering tables
- `clustering_master`: collection-level structural feature table built directly from public source tables using CTEs.
- `clustering_result`: final clustering output with `collection`, `cluster`, and `distance_to_centroid`.
