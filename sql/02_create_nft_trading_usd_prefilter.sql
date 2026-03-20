-- Create nft_trading_usd_prefilter
--
-- Update the two variables below before execution.

DECLARE project_id STRING DEFAULT '<YOUR_GCP_PROJECT_ID>';
DECLARE dataset_id STRING DEFAULT '<YOUR_BIGQUERY_DATASET>';

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
      APPROX_QUANTILES(price_usd, 1000)[OFFSET(999)] AS local_p999
    FROM base
    WHERE price_usd IS NOT NULL
    GROUP BY collection
  )
SELECT
  b.*
FROM base AS b
LEFT JOIN local_cutoff AS lc USING (collection)
WHERE
  (lc.local_p999 IS NULL OR b.price_usd <= lc.local_p999)
  AND b.price_usd <= 5000000
""", project_id, dataset_id, project_id, dataset_id);
