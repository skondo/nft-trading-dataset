# NFT Trading Dataset: Data Preparation & Setup

This repository provides documentation and an executable notebook workflow for rebuilding the analysis-ready BigQuery tables used in the study from the publicly released dataset on Zenodo.

The repository starts from the public processed dataset published on Zenodo and describes how to:

- download the released dataset files,
- upload them to Google Cloud Storage (GCS),
- load them into BigQuery base tables,
- ingest daily ETH/USD exchange-rate data from Etherscan,
- construct the prepared transaction tables used in the study.

The intended execution environment is **VS Code Notebook (Python)** with access to Google Cloud resources.

## Source dataset

Primary dataset release:

- Zenodo record: `https://zenodo.org/records/19062204`
- DOI: `10.5281/zenodo.19062204`

The current Zenodo release contains:

- `nft_trading_base.tar.gz`
- `nft_metadata_base.parquet.gz`
- `README.md`

According to the Zenodo dataset README, `nft_trading_base` includes transaction-level NFT trading data with fields such as `timestamp` (timestamp), `week_start` (date), `market`, `token_type`, `price_eth`, and `fee_eth`, while `nft_metadata_base` includes collection-level metadata-derived variables such as `category`, `confidence`, ERC standard indicators, and royalty information. The ETH/USD reference data used in the paper are not redistributed in the Zenodo archive and must be obtained separately from Etherscan.

## Scope of this repository

This repository covers **data preparation and setup only**.

It includes:

- operational prerequisites for using GCS and BigQuery from VS Code Notebook,
- upload and load procedures for the Zenodo dataset,
- a simple procedure for obtaining ETH/USD daily price data,
- construction of the following BigQuery tables:
  - `nft_trading_base`
  - `nft_metadata_base`
  - `usd_eth_base`
  - `nft_trading_usd`
  - `nft_trading_usd_prefilter`
  - `nft_trading_usd_filtered`

It does **not** cover:

- Python environment creation,
- downstream modeling and estimation,
- regression or factor-model notebooks,
- visualization workflows,
- raw blockchain extraction pipelines.

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
│   └── data_preparation.ipynb
└── sql/
    ├── 01_create_nft_trading_usd.sql
    ├── 02_create_nft_trading_usd_prefilter.sql
    ├── 03_create_nft_trading_usd_filtered.sql
    └── table_definitions.md
```

The `data/` subdirectories are included only as local working locations for downloaded and extracted source files. The `.gitignore` keeps large raw data artifacts out of version control while preserving the folder structure expected by the notebook.

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

Recommended example names:

- GCP project: `your-gcp-project`
- GCS bucket: `gs://your-bucket`
- BigQuery dataset: `your_dataset`

### Local tools

The notebook assumes that the following tools are available on your machine:

- `gcloud`
- `gcloud storage` or `gsutil`
- `bq`
- VS Code with Notebook support

### Authentication

Before running notebook cells that interact with GCP, authenticate locally.

```bash
gcloud auth login
gcloud config set project your-gcp-project
gcloud auth application-default login
```

To confirm the active project:

```bash
gcloud config get-value project
```

The notebook uses Application Default Credentials through the Google Cloud Python client libraries.

## Environment setup

This repository does not document general Python or VS Code installation. Instead, it provides the minimum reproducible environment definition needed to run the notebook locally.

The recommended execution environment is defined in `environment.yml`.

```bash
conda env create -f environment.yml
conda activate nft_research
python -m ipykernel install --user --name nft_research --display-name "Python (nft_research)"
```

After creating the environment, open `notebooks/data_preparation.ipynb` in VS Code and select the `Python (nft_research)` kernel.

A lightweight `requirements.txt` is also included for users who prefer a pip-based setup, although the Conda environment is the recommended option for reproducibility.

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
gcloud storage cp data/raw/nft_metadata_base.parquet.gz gs://your-bucket/nft_market_regimes/raw/
gcloud storage cp data/raw/etherprice.csv gs://your-bucket/nft_market_regimes/raw/
gcloud storage cp --recursive data/extracted/nft_trading_base gs://your-bucket/nft_market_regimes/raw/nft_trading_base/
```

If the extracted trading archive contains many Parquet parts, upload the extracted directory rather than the compressed archive.

### 3. Load BigQuery base tables

The notebook shows a Python-based loading approach and includes notes for CLI-oriented users.

The target base tables are:

- `your_dataset.nft_trading_base`
- `your_dataset.nft_metadata_base`
- `your_dataset.usd_eth_base`

### 4. Obtain ETH/USD daily exchange-rate data

In the paper, ETH-denominated transaction values were converted into USD using ETH/USD data obtained from Etherscan. The Zenodo README states that these data are not redistributed and should be downloaded directly by users who want to reproduce the USD-denominated analysis. The CSV fields are `Date(UTC)`, `UnixTimeStamp`, and `Value`.

Save the file locally as `data/raw/etherprice.csv`, upload it to GCS, and load it into BigQuery as `usd_eth_base`.

### 5. Create derived analysis tables

After the base tables are ready, create:

- `nft_trading_usd`
- `nft_trading_usd_prefilter`
- `nft_trading_usd_filtered`

In this repository, the reusable SQL for derived tables is provided under `sql/` as separate scripts.

- `sql/01_create_nft_trading_usd.sql`
- `sql/02_create_nft_trading_usd_prefilter.sql`
- `sql/03_create_nft_trading_usd_filtered.sql`

`nft_trading_usd` is built by joining `nft_trading_base.timestamp` to `usd_eth_base` on `DATE(timestamp)` and multiplying `price_eth` by the daily ETH/USD rate. `nft_trading_usd_prefilter` applies collection-level and global outlier filtering on `price_usd`. `nft_trading_usd_filtered` retains only collections observed in at least 8 active weeks.

## Target tables

### `nft_trading_base`

Base NFT trading table loaded from the public Zenodo release.

### `nft_metadata_base`

Base metadata-derived table loaded from the public Zenodo release.

### `usd_eth_base`

Daily ETH/USD exchange-rate table used to convert native ETH prices into USD-denominated values.

### `nft_trading_usd`

Trading table enriched with the daily ETH/USD conversion, including `eth_usd_rate`, `price_usd`, and `fee_usd`.

### `nft_trading_usd_prefilter`

Intermediate table after USD conversion and outlier filtering. Rows are retained only when `price_usd` is at or below both the collection-specific 99.9th percentile and the global cap of USD 5,000,000.

### `nft_trading_usd_filtered`

Filtered analysis table used as the prepared transaction-level source for downstream analysis. Only collections observed in at least 8 active weeks are retained.

## Notes

- The notebook assumes that `nft_trading_base.timestamp` is a timestamp column with time information and that the ETH/USD file is daily. The join therefore uses `DATE(timestamp)`.
- If your uploaded `nft_metadata_base` object remains gzip-compressed in GCS, decompress it locally before loading or verify that your BigQuery loading path handles the uploaded object correctly.
- Inspect the loaded schemas in BigQuery and confirm table partitioning and clustering choices before adapting the SQL scripts for production use.
