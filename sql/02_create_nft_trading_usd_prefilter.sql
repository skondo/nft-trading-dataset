-- Replace the project and dataset placeholders before execution.
DECLARE project_id STRING DEFAULT '<YOUR_GCP_PROJECT_ID>';
DECLARE dataset_id STRING DEFAULT '<YOUR_BIGQUERY_DATASET>';
DECLARE local_price_quantile_resolution INT64 DEFAULT 1000;
DECLARE local_price_quantile_offset INT64 DEFAULT 999;
DECLARE global_max_price_usd FLOAT64 DEFAULT 5000000;

EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.nft_trading_usd_prefilter` AS
WITH
  base AS (
    SELECT
      *
    FROM `%s.%s.nft_trading_usd`
  ),
  local_cutoff AS (
    SELECT
      collection,
      APPROX_QUANTILES(price_usd, @local_price_quantile_resolution)[OFFSET(@local_price_quantile_offset)] AS local_p999
    FROM base
    WHERE price_usd IS NOT NULL
    GROUP BY collection
  )
SELECT
  b.*
FROM base b
LEFT JOIN local_cutoff lc USING (collection)
WHERE
  (lc.local_p999 IS NULL OR b.price_usd <= lc.local_p999)
  AND b.price_usd <= @global_max_price_usd
""", project_id, dataset_id, project_id, dataset_id)
USING local_price_quantile_resolution AS local_price_quantile_resolution,
      local_price_quantile_offset AS local_price_quantile_offset,
      global_max_price_usd AS global_max_price_usd;
