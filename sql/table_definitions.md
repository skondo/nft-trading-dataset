# Table Definitions and Build Order

This file summarizes the intended build order documented in the notebooks and SQL scripts.

## Base and prepared transaction tables

1. `nft_trading_base`
2. `nft_metadata_base`
3. `usd_eth_raw`
4. `usd_eth_base`
5. `nft_trading_usd`
6. `nft_trading_usd_prefilter`
7. `nft_trading_usd_filtered`

## Regime analysis outputs

8. `regime_labels`

## SQL scripts

- `sql/00_create_usd_eth_base.sql`
- `sql/01_create_nft_trading_usd.sql`
- `sql/02_create_nft_trading_usd_prefilter.sql`
- `sql/03_create_nft_trading_usd_filtered.sql`
- `sql/10_create_regime_labels.sql`

## Notes

- Load the Etherscan CSV into `usd_eth_raw` first, then build `usd_eth_base`.
- `regime_labels` depends on changepoint boundaries selected from the regime-detection notebook.
- Review partitioning and clustering choices before adapting the SQL scripts for production use.


## Additional analytics SQL templates

- `20_create_weekly_collection_panel_filtered.sql`: Builds the collection-week panel used for factor-model estimation.
- `21_create_weekly_returns_vw.sql`: Builds collection-level weekly returns together with the market and FX factor returns.
- `30_create_clustering_master.sql`: Builds the integrated collection-level structural feature table used for clustering.
