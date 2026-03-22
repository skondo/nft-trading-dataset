-- Apply outlier filtering to the USD-enriched transaction table.

DECLARE PROJECT_ID STRING DEFAULT '<YOUR_GCP_PROJECT_ID>';
DECLARE DATASET_ID STRING DEFAULT '<YOUR_BIGQUERY_DATASET>';
DECLARE LOCAL_PRICE_QUANTILE_RESOLUTION INT64 DEFAULT 1000;
DECLARE LOCAL_PRICE_QUANTILE_OFFSET INT64 DEFAULT 999;
DECLARE GLOBAL_MAX_PRICE_USD FLOAT64 DEFAULT 5000000;

EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.nft_trading_usd_prefilter` AS
WITH base AS (
  SELECT *
  FROM `%s.%s.nft_trading_usd`
),
local_cutoff AS (
  SELECT
    collection,
    APPROX_QUANTILES(price_usd, @quantile_resolution)[OFFSET(@quantile_offset)] AS local_p999
  FROM base
  WHERE price_usd IS NOT NULL
  GROUP BY collection
)
SELECT
  b.*
FROM base AS b
LEFT JOIN local_cutoff AS lc USING (collection)
WHERE (lc.local_p999 IS NULL OR b.price_usd <= lc.local_p999)
  AND b.price_usd <= @global_max_price_usd
""", PROJECT_ID, DATASET_ID, PROJECT_ID, DATASET_ID)
USING LOCAL_PRICE_QUANTILE_RESOLUTION AS quantile_resolution,
      LOCAL_PRICE_QUANTILE_OFFSET AS quantile_offset,
      GLOBAL_MAX_PRICE_USD AS global_max_price_usd;
