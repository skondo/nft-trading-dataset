# NFT Trading Dataset: Data Preparation, Regime Detection, and Two-Factor Estimation

This repository provides documentation and executable notebook workflows for rebuilding the analysis-ready BigQuery tables used in the study from the publicly released dataset on Zenodo and for reproducing the changepoint-based regime labeling workflow and the two-factor estimation pipeline used in downstream analysis.

The repository starts from the public processed dataset published on Zenodo and describes how to:

- download the released dataset files,
- upload them to Google Cloud Storage (GCS),
- load them into BigQuery base tables,
- ingest daily ETH/USD exchange-rate data from Etherscan,
- construct the prepared transaction tables used in the study,
- detect changepoints from weekly market series,
- create the `regime_labels` table used in downstream analysis,
- construct weekly collection-level return panels, and
- estimate collection-level alpha and two betas (market and FX) for the full sample and by regime.

The intended execution environment is **VS Code Notebook (Python)** with access to Google Cloud resources.

## Source dataset

Primary dataset release:

- Zenodo record: `https://zenodo.org/records/19111864`
- DOI: `10.5281/zenodo.19111864`

The current Zenodo release contains:

- `nft_trading_base.tar.gz`
- `nft_metadata_base.parquet.gz`
- `README.md`

According to the Zenodo dataset README, `nft_trading_base` includes transaction-level NFT trading data with fields such as `timestamp` (timestamp), `week_start` (date), `market`, `token_type`, `price_eth`, and `fee_eth`, while `nft_metadata_base` includes collection-level metadata-derived variables such as `category`, `confidence`, ERC standard indicators, and royalty information. The ETH/USD reference data used in the paper are not redistributed in the Zenodo archive and must be obtained separately from Etherscan.

## Scope of this repository

This repository covers **data preparation, regime labeling, and the minimal two-factor estimation pipeline**.

It includes:

- operational prerequisites for using GCS and BigQuery from VS Code Notebook,
- upload and load procedures for the Zenodo dataset,
- a simple procedure for obtaining ETH/USD daily price data,
- construction of the following BigQuery tables:
  - `nft_trading_base`
  - `nft_metadata_base`
  - `usd_eth_raw`
  - `usd_eth_base`
  - `nft_trading_usd`
  - `nft_trading_usd_prefilter`
  - `nft_trading_usd_filtered`
- changepoint detection from weekly market series,
- creation of the following analytics tables:
  - `regime_labels`
  - `weekly_collection_panel_filtered`
  - `weekly_returns_vw`
  - `beta_alpha_estimates`
  - `beta_alpha_estimates_by_regime`

It does **not** cover:

- raw blockchain extraction pipelines,
- the broader econometric modeling workflow,
- the full visualization pipeline used in the paper,
- broader downstream cross-sectional analysis beyond the minimal two-factor estimation workflow.

## Repository structure

```text
.
├── README.md
├── environment.yml
├── requirements.txt
├── .gitignore
├── data/
│   ├── raw/
│   │   └── .gitkeep
│   └── extracted/
│       └── .gitkeep
├── notebooks/
│   ├── data_preparation.ipynb
│   ├── regime_detection.ipynb
│   ├── factor_model_preparation.ipynb
│   └── factor_model_estimation.ipynb
├── references/
│   └── factor_model_reference.py
└── sql/
    ├── 00_create_usd_eth_base.sql
    ├── 01_create_nft_trading_usd.sql
    ├── 02_create_nft_trading_usd_prefilter.sql
    ├── 03_create_nft_trading_usd_filtered.sql
    ├── 10_create_regime_labels.sql
    ├── 20_create_weekly_collection_panel_filtered.sql
    ├── 21_create_weekly_returns_vw.sql
    └── table_definitions.md
```

The `data/` subdirectories are included only as local working locations for downloaded and extracted source files. The `.gitignore` keeps large raw data artifacts out of version control while preserving the folder structure expected by the notebooks.

## Factor-model workflow

The factor-model portion of the repository follows a minimal public pipeline:

1. Build `weekly_collection_panel_filtered` from `nft_trading_usd_filtered`.
2. Build `weekly_returns_vw`, which combines:
   - collection-level weekly NFT returns,
   - a value-weighted weekly market return, and
   - a weekly FX return derived from `usd_eth_base`.
3. Join `weekly_returns_vw` with `regime_labels` at estimation time.
4. Estimate and save:
   - `beta_alpha_estimates`
   - `beta_alpha_estimates_by_regime`

The minimal public version does **not** create a separate residual table or a separate `weekly_factor_input_vw` table.

## Prerequisites

You should have the following prepared in advance.

### Google Cloud

- a GCP project,
- billing enabled,
- permission to use:
  - Google Cloud Storage,
  - BigQuery,
- a target GCS bucket,
- a target BigQuery dataset for base tables,
- a target BigQuery dataset for analytics outputs.

Recommended example names:

- GCP project: `your-gcp-project`
- GCS bucket: `gs://your-bucket`
- BigQuery base dataset: `base`
- BigQuery analytics dataset: `analytics`

### Local tools

The notebooks assume that the following tools are available on your machine:

- `gcloud`
- `gcloud storage` or `gsutil`
- `bq`
- VS Code with Notebook support

### Authentication

Before running notebook cells that interact with GCP, authenticate locally.

```bash
gcloud auth login
gcloud config set project <YOUR_GCP_PROJECT_ID>
gcloud auth application-default login
```

To confirm the active project:

```bash
gcloud config get-value project
```

The notebooks use Application Default Credentials through the Google Cloud Python client libraries.

## Environment setup

This repository does not document general Python or VS Code installation. Instead, it provides the minimum reproducible environment definition needed to run the notebooks locally.

The recommended execution environment is defined in `environment.yml`.

```bash
conda env create -f environment.yml
conda activate nft_research
python -m ipykernel install --user --name nft_research --display-name "Python (nft_research)"
```

After creating the environment, open the notebooks in VS Code and select the `Python (nft_research)` kernel.

A lightweight `requirements.txt` is also included for users who prefer a pip-based setup, although the Conda environment is the recommended option for reproducibility.

```bash
pip install -r requirements.txt
```

## Configuration parameters

The notebooks expose the main environment- and analysis-dependent settings near the top of the file.

For example:

- `PROJECT_ID`
- `BASE_DATASET_ID`
- `ANALYTICS_DATASET_ID`
- `BUCKET_NAME`
- `GCS_RAW_PREFIX`
- `ANALYSIS_START_DATE`
- `ANALYSIS_END_DATE`
- `GLOBAL_MAX_PRICE_USD`
- `MIN_ACTIVE_WEEKS`
- `LOCAL_PRICE_QUANTILE_RESOLUTION`
- `LOCAL_PRICE_QUANTILE_OFFSET`
- `PENALTY_GRID`
- `SELECTED_PENALTY`
- `CP_MERGE_TOL_DAYS`

Adjust these values before running the notebooks in your own environment.

## Data preparation workflow

The data preparation process is organized into the following stages.

### 1. Download the public dataset from Zenodo

Download the released files from the Zenodo record and place them in a local working directory.

Suggested local directory layout:

```text
data/
├── raw/
│   ├── nft_trading_base.tar.gz
│   ├── nft_metadata_base.parquet.gz
│   └── etherprice.csv
└── extracted/
    └── nft_trading_base/
```

Example:

```bash
mkdir -p data/raw data/extracted
curl -L -o data/raw/nft_trading_base.tar.gz "https://zenodo.org/records/19111864/files/nft_trading_base.tar.gz?download=1"
curl -L -o data/raw/nft_metadata_base.parquet.gz "https://zenodo.org/records/19111864/files/nft_metadata_base.parquet.gz?download=1"
tar -xzf data/raw/nft_trading_base.tar.gz -C data/extracted/
```

### 2. Upload source files to GCS

Example commands:

```bash
gcloud storage cp data/raw/nft_metadata_base.parquet.gz gs://<YOUR_GCS_BUCKET>/nft_market_regimes/raw/
gcloud storage cp data/raw/etherprice.csv gs://<YOUR_GCS_BUCKET>/nft_market_regimes/raw/
gcloud storage cp --recursive data/extracted/nft_trading_base gs://<YOUR_GCS_BUCKET>/nft_market_regimes/raw/nft_trading_base/
```

If the extracted trading archive contains many Parquet parts, upload the extracted directory rather than the compressed archive.

### 3. Load BigQuery base tables

The `data_preparation.ipynb` notebook shows a Python-based loading approach and includes notes for CLI-oriented users.

The target base tables are:

- `<YOUR_GCP_PROJECT_ID>.<YOUR_BIGQUERY_DATASET>.nft_trading_base`
- `<YOUR_GCP_PROJECT_ID>.<YOUR_BIGQUERY_DATASET>.nft_metadata_base`
- `<YOUR_GCP_PROJECT_ID>.<YOUR_BIGQUERY_DATASET>.usd_eth_raw`

### 4. Obtain ETH/USD daily exchange-rate data

The ETH/USD data used in the paper are obtained from Etherscan and should be saved locally as `data/raw/etherprice.csv`.

Load the CSV into `usd_eth_raw` first, then normalize it into `usd_eth_base` using `sql/00_create_usd_eth_base.sql` or the matching notebook section.

### 5. Create derived transaction tables

After the base tables are ready, create:

- `usd_eth_base`
- `nft_trading_usd`
- `nft_trading_usd_prefilter`
- `nft_trading_usd_filtered`

Reusable SQL is provided under `sql/`.

- `sql/00_create_usd_eth_base.sql`
- `sql/01_create_nft_trading_usd.sql`
- `sql/02_create_nft_trading_usd_prefilter.sql`
- `sql/03_create_nft_trading_usd_filtered.sql`

`nft_trading_usd` is built by joining `nft_trading_base.timestamp` to `usd_eth_base` on `DATE(timestamp)` and multiplying `price_eth` by the daily ETH/USD rate. `nft_trading_usd_prefilter` applies collection-level and global outlier filtering on `price_usd`. `nft_trading_usd_filtered` retains only collections observed in at least the configured number of active weeks.

## Regime detection workflow

The `notebooks/regime_detection.ipynb` notebook reproduces the changepoint-based regime detection workflow.

It performs the following steps:

1. load weekly series for wallets, collections, market volume, median market price, and ETH/USD,
2. standardize the series using `log1p`,
3. run a penalty sensitivity check,
4. generate changepoints with the selected penalty,
5. identify the study-specific `boom_start` and `post_start` boundaries,
6. create `<YOUR_GCP_PROJECT_ID>.<YOUR_ANALYTICS_BIGQUERY_DATASET>.regime_labels`.

The selected penalty in the current notebook template is `6`, consistent with the supplied workflow.

A matching SQL template is also provided in `sql/10_create_regime_labels.sql`. That script expects `BOOM_START` and `POST_BOOM_START` to be filled in after they have been selected from the notebook output.

## Target tables

### Base and prepared tables

- `nft_trading_base`
- `nft_metadata_base`
- `usd_eth_raw`
- `usd_eth_base`
- `nft_trading_usd`
- `nft_trading_usd_prefilter`
- `nft_trading_usd_filtered`

### Analytics table

- `regime_labels`

`regime_labels` contains one row per `week_start` and assigns each week to `pre-boom`, `boom`, or `post-boom` according to the changepoint-derived boundaries.

## Notes

- The notebooks assume that `nft_trading_base.timestamp` is a timestamp column with time information and that the ETH/USD file is daily. The join therefore uses `DATE(timestamp)`.
- If your uploaded `nft_metadata_base` object remains gzip-compressed in GCS, decompress it locally before loading or verify that your BigQuery loading path handles the uploaded object correctly.
- Inspect the loaded schemas in BigQuery and confirm table partitioning and clustering choices before adapting the SQL scripts for production use.
