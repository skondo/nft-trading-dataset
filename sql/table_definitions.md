# Table Definitions and Build Order

This file summarizes the intended table build order documented in the notebook.

## Build order

1. `nft_trading_base`
2. `nft_metadata_base`
3. `usd_eth_raw`
4. `usd_eth_base`
5. `nft_trading_usd`
6. `nft_trading_usd_prefilter`
7. `nft_trading_usd_filtered`

## Table summary

### `nft_trading_base`
Loaded from the Zenodo-released trading Parquet files.

### `nft_metadata_base`
Loaded from the Zenodo-released metadata Parquet file.

### `usd_eth_raw`
Raw Etherscan CSV loaded into BigQuery with autodetected CSV schema.

### `usd_eth_base`
Normalized ETH/USD reference table created from `usd_eth_raw`:

- `timestamp`: UTC timestamp converted from the raw Unix-time field
- `date`: calendar date derived from `timestamp`
- `week_start`: Monday-based week start derived from `date`
- `usd_eth_rate`: normalized ETH/USD exchange rate

Rows are restricted to:
- `timestamp >= TIMESTAMP("`ANALYSIS_START_DATE`", "UTC")`
- `timestamp < TIMESTAMP("`ANALYSIS_END_DATE`", "UTC")`

Implemented in `sql/00_create_usd_eth_base.sql`.

### `nft_trading_usd`
Derived by joining `nft_trading_base` to `usd_eth_base` using `DATE(timestamp) = date`, then computing USD-denominated trading values.

Implemented in `sql/01_create_nft_trading_usd.sql`.

### `nft_trading_usd_prefilter`
Derived from `nft_trading_usd` by removing outliers using:

- collection-level `APPROX_QUANTILES(price_usd, 1000)[OFFSET(999)]` as `local_p999`
- global upper bound `price_usd <= `GLOBAL_MAX_PRICE_USD``

Implemented in `sql/02_create_nft_trading_usd_prefilter.sql`.

### `nft_trading_usd_filtered`
Derived from `nft_trading_usd_prefilter` by retaining only collections with at least 8 distinct active weeks.

Implemented in `sql/03_create_nft_trading_usd_filtered.sql`.

## Notes

- Confirm loaded schemas before creating derived tables.
- Review timestamp and date column types in all base tables.
- Add partitioning and clustering where appropriate for cost and performance control.
