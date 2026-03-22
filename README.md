# NFT Trading Dataset Reproducibility Pipeline

This repository provides a minimal reproducible pipeline built on the public NFT dataset released on Zenodo.

Using the public source files and Google Cloud services, the repository reproduces the following analytical workflow:

1. public data ingestion and preparation
2. regime label construction
3. two-factor return estimation
4. collection-level clustering
5. cross-model comparison across category labels, clustering labels, and factor estimates

The repository is designed to support reproducibility of the main analytical workflow based on the public dataset. Some manuscript-specific exploratory analyses, figure styling utilities, and private or internal datasets are intentionally excluded.

---

## Public data source

The analysis starts from the public dataset published on Zenodo.

- Zenodo record: `10.5281/zenodo.19111864`
- Public source files include:
  - `nft_trading_base.tar.gz`
  - `nft_metadata_base.parquet.gz`

In addition, ETH/USD reference data is downloaded separately from Etherscan as a CSV file and incorporated into the BigQuery workflow.

---

## Scope

This repository provides a minimal reproducible workflow for:

- loading the public NFT dataset into Google Cloud Storage and BigQuery
- preparing trade-level and metadata-based analysis tables
- constructing regime labels from weekly market series
- estimating a two-factor model at the collection level
- generating collection-level clustering labels
- comparing category labels, clustering labels, and factor-model outputs

This repository does **not** include:

- private or internal datasets
- non-public annotations or manually curated labels outside the public dataset
- manuscript-specific LaTeX export utilities used only for paper production
- exploratory code paths that are not required for the minimal reproducible workflow

---

## Repository structure

```text
.
├── README.md
├── environment.yml
├── requirements.txt
├── .gitignore
├── data/
│   ├── raw/
│   └── extracted/
├── notebooks/
│   ├── data_preparation.ipynb
│   ├── regime_detection.ipynb
│   ├── factor_model_preparation.ipynb
│   ├── factor_model_estimation.ipynb
│   ├── clustering_preparation.ipynb
│   ├── clustering_modeling.ipynb
│   └── cross_model_evaluation.ipynb
├── sql/
│   ├── 00_create_usd_eth_base.sql
│   ├── 01_create_nft_trading_usd.sql
│   ├── 02_create_nft_trading_usd_prefilter.sql
│   ├── 03_create_nft_trading_usd_filtered.sql
│   ├── 10_create_regime_labels.sql
│   ├── 20_create_weekly_collection_panel_filtered.sql
│   ├── 21_create_weekly_returns_vw.sql
│   ├── 30_create_clustering_master.sql
│   └── table_definitions.md
└── references/
    └── factor_model_reference.py
```

---

## Environment setup

This repository assumes a local notebook workflow in VSCode with access to Google Cloud services.

### Prerequisites

- a Google Cloud project with BigQuery enabled
- a Google Cloud Storage bucket
- Google Cloud CLI (`gcloud`)
- Conda or Miniforge
- VSCode with the Python and Jupyter extensions installed

### Recommended Python environment

The recommended execution environment is defined in `environment.yml`.

```bash
conda env create -f environment.yml
conda activate nft_research
python -m ipykernel install --user --name nft_research --display-name "Python (nft_research)"
```

After creating the environment, open the notebooks in VSCode and select the `Python (nft_research)` kernel.

### Optional pip-based installation

A minimal pip-based dependency list is also provided.

```bash
pip install -r requirements.txt
```

---

## Google Cloud authentication

Authenticate both the CLI and Application Default Credentials (ADC):

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <YOUR_GCP_PROJECT_ID>
```

The notebooks use ADC to access Google Cloud Storage and BigQuery.

---

## Configuration parameters

The notebooks are designed to use a small number of configurable parameters defined near the top of each notebook.

Typical parameters include:

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

Replace placeholders such as:

- `<YOUR_GCP_PROJECT_ID>`
- `<YOUR_BASE_BIGQUERY_DATASET>`
- `<YOUR_ANALYTICS_BIGQUERY_DATASET>`
- `<YOUR_GCS_BUCKET>`

with values appropriate for your environment.

For example, in one environment the tables were stored under:

- project: `nftpricing`
- base dataset: `base`
- analytics dataset: `analytics`

but these names are intentionally parameterized in the public workflow.

---

## Notebook overview

The notebooks are organized by stage of the workflow.

### `notebooks/data_preparation.ipynb`

Builds the base analysis tables from the public Zenodo dataset and ETH/USD reference data.

Main outputs:

- `usd_eth_raw`
- `usd_eth_base`
- `nft_trading_usd`
- `nft_trading_usd_prefilter`
- `nft_trading_usd_filtered`

### `notebooks/regime_detection.ipynb`

Builds weekly market series, evaluates changepoint sensitivity, and creates regime labels.

Main output:

- `regime_labels`

### `notebooks/factor_model_preparation.ipynb`

Builds the collection-week panel and weekly return inputs required for factor estimation.

Main outputs:

- `weekly_collection_panel_filtered`
- `weekly_returns_vw`

### `notebooks/factor_model_estimation.ipynb`

Estimates full-period and regime-wise two-factor model parameters.

Main outputs:

- `beta_alpha_estimates`
- `beta_alpha_estimates_by_regime`

### `notebooks/clustering_preparation.ipynb`

Builds the collection-level structural feature table for clustering.

Main output:

- `clustering_master`

### `notebooks/clustering_modeling.ipynb`

Evaluates candidate values of `k`, fits the clustering model, and saves cluster assignments.

Main output:

- `clustering_result`

### `notebooks/cross_model_evaluation.ipynb`

Compares category labels, clustering labels, and factor-model estimates using grouped summaries and nonparametric tests.

This notebook is intended for screen-readable output rather than manuscript-oriented LaTeX export.

---

## Recommended execution order

Run the notebooks in the following order:

1. `notebooks/data_preparation.ipynb`
2. `notebooks/regime_detection.ipynb`
3. `notebooks/factor_model_preparation.ipynb`
4. `notebooks/factor_model_estimation.ipynb`
5. `notebooks/clustering_preparation.ipynb`
6. `notebooks/clustering_modeling.ipynb`
7. `notebooks/cross_model_evaluation.ipynb`

Later notebooks assume that the BigQuery tables created by earlier notebooks already exist.

---

## Data preparation workflow

### Step 1. Download the public files

Download the Zenodo source files manually or via browser:

- `nft_trading_base.tar.gz`
- `nft_metadata_base.parquet.gz`

Download ETH/USD reference data from Etherscan as CSV.

Expected local layout:

```text
data/
├── raw/
│   ├── nft_trading_base.tar.gz
│   ├── nft_metadata_base.parquet.gz
│   └── etherprice.csv
└── extracted/
    └── nft_trading_base/
```

### Step 2. Extract the trade archive

Example:

```bash
mkdir -p data/extracted
tar -xzf data/raw/nft_trading_base.tar.gz -C data/extracted
```

### Step 3. Upload local files to GCS

Example using `gcloud storage cp`:

```bash
gcloud storage cp data/raw/nft_metadata_base.parquet.gz gs://<YOUR_GCS_BUCKET>/nft_market_regimes/raw/
gcloud storage cp data/raw/etherprice.csv gs://<YOUR_GCS_BUCKET>/nft_market_regimes/raw/
gcloud storage cp --recursive data/extracted/nft_trading_base gs://<YOUR_GCS_BUCKET>/nft_market_regimes/raw/nft_trading_base/
```

The notebook also includes Python-based upload helpers using `google-cloud-storage`.

### Step 4. Load raw files into BigQuery

The notebook includes both Python and CLI-oriented patterns for loading data from GCS into BigQuery.

The ETH/USD CSV is first loaded as:

- `usd_eth_raw`

and then normalized into:

- `usd_eth_base`

---

## Main BigQuery outputs

### Data preparation

- `usd_eth_raw`
- `usd_eth_base`
- `nft_trading_usd`
- `nft_trading_usd_prefilter`
- `nft_trading_usd_filtered`

### Regime detection

- `regime_labels`

### Factor model

- `weekly_collection_panel_filtered`
- `weekly_returns_vw`
- `beta_alpha_estimates`
- `beta_alpha_estimates_by_regime`

### Clustering

- `clustering_master`
- `clustering_result`

The repository intentionally avoids creating unnecessary persistent intermediate tables where possible.

---

## Data preparation rules

### `usd_eth_raw` and `usd_eth_base`

The ETH/USD CSV downloaded from Etherscan is first loaded into `usd_eth_raw`.

`usd_eth_base` is then created as a normalized table with:

- `timestamp`
- `date`
- `week_start`
- `usd_eth_rate`

The analysis period is parameterized through notebook and SQL configuration values such as:

- `ANALYSIS_START_DATE`
- `ANALYSIS_END_DATE`

### `nft_trading_usd_prefilter`

The prefilter step removes extreme outliers using:

- collection-level `price_usd` 99.9th percentile
- global cap at `GLOBAL_MAX_PRICE_USD`

### `nft_trading_usd_filtered`

The filtered trade table retains only collections with:

- at least `MIN_ACTIVE_WEEKS` active weeks

---

## Regime detection

The regime detection workflow uses weekly series derived from:

- unique traders
- unique collections
- market volume
- median market price
- ETH/USD rate

Changepoints are detected using `ruptures` with a penalty parameter. Sensitivity checks are performed over a small penalty grid, while the default regime labeling step uses the selected baseline penalty configured in the notebook.

The regime labeling step creates:

- `regime_labels`

The current implementation follows the paper-aligned boundary-selection rule:

- `boom_start`: first global changepoint in 2021
- `post_start`: first global changepoint in 2022

This rule is made explicit in the notebook for transparency.

---

## Factor model

### Factor-model inputs

The two-factor model uses:

- collection-level NFT returns from `weekly_collection_panel_filtered`
- market return derived from value-weighted collection returns
- FX return derived from weekly ETH/USD changes

The public workflow intentionally keeps the factor-model pipeline minimal.

Persistent outputs are limited to:

- `weekly_collection_panel_filtered`
- `weekly_returns_vw`
- `beta_alpha_estimates`
- `beta_alpha_estimates_by_regime`

The public workflow does **not** create:

- `weekly_factor_input_vw`
- residual tables

### Estimation

The notebook estimates:

- full-period alpha and betas
- regime-wise alpha and betas

using a two-factor specification with:

- NFT return
- market return
- FX return

The implementation also includes:

- winsorization
- HAC standard errors
- minimum observation thresholds

---

## Category labels

This repository uses `nft_metadata_base.category` as the public category label source for collection-level comparisons.

For category-based evaluation, collections with category labels equal to:

- `unknown`
- `vague`

are excluded from the comparison step.

These labels may remain in the underlying base tables, but they are not used in category-level summary statistics or statistical tests.

---

## Clustering pipeline

The clustering workflow produces two main outputs:

- `clustering_master`
- `clustering_result`

### `clustering_master`

`clustering_master` is built as a single BigQuery table using SQL CTEs rather than multiple persistent intermediate tables.

It integrates collection-level structural features from:

- trade activity
- holder concentration and distribution
- metadata-derived structural attributes
- regime-aligned first-trade information
- category label from `nft_metadata_base.category`

The public clustering pipeline intentionally avoids creating separate persistent tables such as:

- `holder_metrics_full`
- `trading_stats`
- `metadata_stats`

Instead, equivalent logic is embedded inside the `clustering_master` build step.

### `clustering_result`

`clustering_result` is produced in the notebook after:

1. loading `clustering_master`
2. selecting the clustering feature set
3. applying optional log transformation
4. applying winsorization
5. scaling the features
6. evaluating candidate values of `k`
7. fitting KMeans with the selected number of clusters

The saved output includes:

- `collection`
- `cluster`
- `distance_to_centroid`

The public workflow does not use:

- suspicious-filtered clustering variants
- extra metadata tables beyond `nft_metadata_base`
- LaTeX table export for clustering summaries

---

## Cross-model evaluation

The final comparison stage integrates three kinds of outputs:

- category labels from `nft_metadata_base.category`
- clustering labels from `clustering_result`
- factor-model estimates from `beta_alpha_estimates` and `beta_alpha_estimates_by_regime`

The evaluation notebook focuses on screen-readable summaries instead of manuscript-oriented exports.

Included analyses are:

- category × cluster cross-tabulation
- grouped summaries of alpha and beta estimates
- Kruskal-Wallis tests across categories and clusters
- unified category-vs-cluster comparison tables
- partial R² comparisons for the FX factor across regimes

The current public workflow does **not** persist additional comparison-result tables by default.

---

## Design principle

This repository is intentionally designed as a minimal reproducible workflow.

Where possible, intermediate computations are performed inside notebooks or SQL CTEs rather than materialized as separate persistent tables. This keeps the public pipeline easier to understand and reduces the number of required artifacts for reproduction.

---

## Reproducibility note

All table names, project identifiers, dataset names, and storage locations are parameterized with placeholders where appropriate. Replace these placeholders with your own Google Cloud project, BigQuery dataset, and Cloud Storage bucket names before execution.

The notebooks assume that earlier pipeline stages have already created the prerequisite tables in BigQuery.

---

## Dependencies

The repository relies on a small set of scientific Python packages, including:

- `pandas`
- `numpy`
- `pyarrow`
- `bigframes`
- `google-cloud-bigquery`
- `google-cloud-storage`
- `statsmodels`
- `scikit-learn`
- `scipy`
- `ruptures`
- `jupyter`
- `ipykernel`

Use `environment.yml` as the recommended environment definition.

---

## Notes on public reproducibility

This repository is intended to provide a practical, minimal reproduction path from public raw data to the main analytical outputs.

Some exploratory branches, publication-specific formatting scripts, and project-internal helper utilities are intentionally omitted to keep the workflow readable and reproducible from the public dataset alone.
