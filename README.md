# NFT Trading Dataset: Data Preparation & Setup

This repository provides documentation and an executable notebook workflow for rebuilding the analysis-ready BigQuery tables used in the study from the publicly released dataset on Zenodo.

The repository starts from the public processed dataset published on Zenodo and describes how to:

- download the released dataset files,
- upload them to Google Cloud Storage (GCS),
- load them into BigQuery base tables,
- ingest ETH/USD exchange-rate data from Etherscan,
- normalize the raw ETH/USD CSV into a reusable base table, and
- construct the prepared transaction tables used in the study.

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

This repository covers **data preparation and setup only**.

It includes:

- operational prerequisites for using GCS and BigQuery from VS Code Notebook,
- environment setup guidance using `environment.yml`,
- upload and load procedures for the Zenodo dataset,
- a simple procedure for obtaining ETH/USD price data from Etherscan,
- construction of the following BigQuery tables:
  - `nft_trading_base`
  - `nft_metadata_base`
  - `usd_eth_raw`
  - `usd_eth_base`
  - `nft_trading_usd`
  - `nft_trading_usd_prefilter`
  - `nft_trading_usd_filtered`

It does **not** cover:

- general Python, Conda, or VS Code installation,
- downstream modeling and estimation,
- regression or factor-model notebooks,
- visualization workflows,
- raw blockchain extraction pipelines.

## Repository structure

```text
.
├── .gitignore
├── README.md
├── environment.yml
├── requirements.txt
├── data/
│   ├── raw/
│   │   └── .gitkeep
│   └── extracted/
│       └── .gitkeep
├── notebooks/
│   └── data_preparation.ipynb
└── sql/
    ├── 00_create_usd_eth_base.sql
    ├── 01_create_nft_trading_usd.sql
    ├── 02_create_nft_trading_usd_prefilter.sql
    ├── 03_create_nft_trading_usd_filtered.sql
    └── table_definitions.md
```

## Prerequisites

You should have the following prepared in advance.

### Google Cloud

- a GCP project,
- billing enabled,
- permission to use:
  - Google Cloud Storage,
  - BigQuery,
- a target GCS bucket,
- a target BigQuery dataset.

Recommended placeholders:

- GCP project: `<YOUR_GCP_PROJECT_ID>`
- GCS bucket: `gs://<YOUR_GCS_BUCKET>`
- BigQuery dataset: `<YOUR_BIGQUERY_DATASET>`

### Local tools

The notebook assumes that the following tools are available on your machine:

- `gcloud`
- `gcloud storage` or `gsutil`
- `bq`
- VS Code with the Python and Jupyter extensions

### Environment setup

The recommended execution environment is defined in `environment.yml`.

```bash
conda env create -f environment.yml
conda activate nft_research
python -m ipykernel install --user --name nft_research --display-name "Python (nft_research)"
```

Open `notebooks/data_preparation.ipynb` in VS Code and select the `Python (nft_research)` kernel.

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

The notebook uses Application Default Credentials through the Google Cloud Python client libraries.


## Configuration parameters

The notebook and SQL files are designed so that environment-specific identifiers and reusable thresholds are defined once and then referenced throughout the workflow.

Recommended configuration variables:

- `PROJECT_ID`
- `DATASET_ID`
- `BUCKET_NAME`
- `GCS_RAW_PREFIX`
- `ANALYSIS_START_DATE`
- `ANALYSIS_END_DATE`
- `GLOBAL_MAX_PRICE_USD`
- `MIN_ACTIVE_WEEKS`
- `LOCAL_PRICE_QUANTILE_RESOLUTION`
- `LOCAL_PRICE_QUANTILE_OFFSET`

This makes it easier to:

- move the workflow across GCP projects or datasets,
- change storage prefixes without editing multiple cells,
- extend the study period later, and
- revise filtering thresholds in a single place.

## Python dependencies

`environment.yml` is the recommended environment definition for reproducibility.  
`requirements.txt` is provided as a lightweight pip-oriented reference.

Typical pip installation:

```bash
pip install -r requirements.txt
```

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

The notebook shows a Python-based loading approach and includes notes for CLI-oriented users.

The target loaded tables are:

- `<YOUR_GCP_PROJECT_ID>.<YOUR_BIGQUERY_DATASET>.nft_trading_base`
- `<YOUR_GCP_PROJECT_ID>.<YOUR_BIGQUERY_DATASET>.nft_metadata_base`
- `<YOUR_GCP_PROJECT_ID>.<YOUR_BIGQUERY_DATASET>.usd_eth_raw`

The raw ETH/USD CSV is first loaded into `usd_eth_raw`, then normalized into `usd_eth_base`.

### 4. Obtain ETH/USD exchange-rate data

Download the CSV from Etherscan and save it locally as `data/raw/etherprice.csv`.

The raw CSV fields are expected to include:

- `Date(UTC)`
- `UnixTimeStamp`
- `Value`

Upload the CSV to GCS and load it into BigQuery as `usd_eth_raw`.

Example CLI loading command:

```bash
bq load \
  --source_format=CSV \
  --skip_leading_rows=1 \
  --autodetect \
  <YOUR_GCP_PROJECT_ID>:<YOUR_BIGQUERY_DATASET>.usd_eth_raw \
  gs://<YOUR_GCS_BUCKET>/nft_market_regimes/raw/etherprice.csv
```

Then create the normalized table `usd_eth_base` from `usd_eth_raw`.
The normalization step produces:

- `timestamp`
- `date`
- `week_start`
- `usd_eth_rate`

and keeps only rows within the configured analysis period defined by `ANALYSIS_START_DATE` and `ANALYSIS_END_DATE`.

### 5. Create derived analysis tables

After the base tables are ready, create:

- `usd_eth_base`
- `nft_trading_usd`
- `nft_trading_usd_prefilter`
- `nft_trading_usd_filtered`

In this repository:

- `usd_eth_base` is created from `usd_eth_raw`,
- `nft_trading_usd` is built by joining `nft_trading_base.timestamp` to `usd_eth_base` on `DATE(timestamp) = date`,
- `nft_trading_usd_prefilter` removes collection-level and global price outliers using configurable `price_usd` thresholds,
- `nft_trading_usd_filtered` retains only collections observed in at least `MIN_ACTIVE_WEEKS` active weeks.

Reusable SQL files are included under `sql/`.

## Target tables

### `nft_trading_base`

Base NFT trading table loaded from the public Zenodo release.

### `nft_metadata_base`

Base metadata-derived table loaded from the public Zenodo release.

### `usd_eth_raw`

Raw ETH/USD CSV imported from Etherscan.

### `usd_eth_base`

Normalized ETH/USD reference table derived from `usd_eth_raw` with standardized timestamp/date fields.

### `nft_trading_usd`

Trading table enriched with the daily ETH/USD conversion, including `usd_eth_rate`, `price_usd`, and `fee_usd`.

### `nft_trading_usd_prefilter`

Intermediate transaction table after outlier filtering based on collection-level `price_usd` cutoffs and a global upper bound.

### `nft_trading_usd_filtered`

Filtered analysis table retaining only collections observed in at least 8 active weeks.

## Notes

- The notebook assumes that `nft_trading_base.timestamp` is a timestamp column with time information and that the ETH/USD CSV contains Unix-time values that can be converted into a normalized timestamp/date table.
- If your uploaded `nft_metadata_base` object remains gzip-compressed in GCS, decompress it locally before loading or verify that your BigQuery loading path handles the uploaded object correctly.
- Before promoting the SQL into reusable scripts, inspect the loaded schemas in BigQuery and confirm table partitioning and clustering choices.
