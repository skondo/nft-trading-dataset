-- Create collection-week panel from filtered NFT trades.
DECLARE PROJECT_ID STRING DEFAULT '<YOUR_GCP_PROJECT_ID>';
DECLARE BASE_DATASET_ID STRING DEFAULT '<YOUR_BASE_BIGQUERY_DATASET>';
DECLARE ANALYTICS_DATASET_ID STRING DEFAULT '<YOUR_ANALYTICS_BIGQUERY_DATASET>';

EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.weekly_collection_panel_filtered` AS
SELECT
  collection,
  week_start,
  APPROX_QUANTILES(SAFE_CAST(price_usd AS FLOAT64), 100)[OFFSET(50)] AS median_price_usd,
  SUM(SAFE_CAST(price_usd AS FLOAT64)) AS total_volume_usd,
  COUNT(*) AS tx_count
FROM `%s.%s.nft_trading_usd_filtered`
WHERE price_usd IS NOT NULL
  AND SAFE_CAST(price_usd AS FLOAT64) > 0
  AND collection IS NOT NULL
  AND week_start IS NOT NULL
GROUP BY collection, week_start
ORDER BY collection, week_start
""", PROJECT_ID, ANALYTICS_DATASET_ID, PROJECT_ID, BASE_DATASET_ID);
