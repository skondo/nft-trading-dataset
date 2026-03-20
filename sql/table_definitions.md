# Table Definitions and Build Order

This file summarizes the intended table build order documented in the notebook and points to the reusable SQL scripts included in this repository.

## Build order

1. `nft_trading_base`
2. `nft_metadata_base`
3. `usd_eth_base`
4. `nft_trading_usd`
5. `nft_trading_usd_prefilter`
6. `nft_trading_usd_filtered`

## SQL scripts

The reusable derived-table SQL is split into the following files:

- `sql/01_create_nft_trading_usd.sql`
- `sql/02_create_nft_trading_usd_prefilter.sql`
- `sql/03_create_nft_trading_usd_filtered.sql`

Each script uses BigQuery scripting with the following placeholders at the top of the file:

- `project_id = '<YOUR_GCP_PROJECT_ID>'`
- `dataset_id = '<YOUR_BIGQUERY_DATASET>'`

Update these values before executing the script in the BigQuery editor or from the CLI.

## Base table notes

### `nft_trading_base`

The Zenodo dataset README documents the following key columns for this table: `timestamp` (timestamp), `week_start` (date), `market`, `token_type`, `price_eth`, and `fee_eth`, together with transaction identifiers and wallet or collection addresses.

### `nft_metadata_base`

The Zenodo dataset README documents collection-level metadata fields including `category_pred`, `confidence`, `category`, social-link indicators, ERC standard indicators, and `royalty_fee_percent`.

### `usd_eth_base`

The ETH/USD CSV is expected to originate from Etherscan and include the fields `Date(UTC)`, `UnixTimeStamp`, and `Value`.

## Derived table notes

### `nft_trading_usd`

Implemented in `sql/01_create_nft_trading_usd.sql`.

Logic:

- join `nft_trading_base` to `usd_eth_base` using `DATE(timestamp)` = parsed ETH/USD calendar date,
- rename the exchange-rate field to `eth_usd_rate`,
- create:
  - `price_usd = price_eth * eth_usd_rate`
  - `fee_usd = fee_eth * eth_usd_rate`

### `nft_trading_usd_prefilter`

Implemented in `sql/02_create_nft_trading_usd_prefilter.sql`.

Logic:

- compute collection-level `price_usd` cutoff values using `APPROX_QUANTILES(price_usd, 1000)[OFFSET(999)]`,
- remove rows above the collection-specific 99.9th percentile,
- apply an additional global upper bound of `price_usd <= 5000000`.

### `nft_trading_usd_filtered`

Implemented in `sql/03_create_nft_trading_usd_filtered.sql`.

Logic:

- count active weeks for each collection using `COUNT(DISTINCT week_start)`,
- retain only collections with `active_weeks >= 8`.

## Operational notes

- Confirm loaded schemas before creating derived tables.
- Because `timestamp` contains time information, use `DATE(timestamp)` when joining to the daily ETH/USD table.
- Add partitioning and clustering where appropriate for cost and performance control.
