-- Create nft_trading_usd_filtered
--
-- Update the two variables below before execution.

DECLARE project_id STRING DEFAULT '<YOUR_GCP_PROJECT_ID>';
DECLARE dataset_id STRING DEFAULT '<YOUR_BIGQUERY_DATASET>';

EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.nft_trading_usd_filtered` AS
WITH base AS (
  SELECT *
  FROM `%s.%s.nft_trading_usd_prefilter`
),
collection_stats AS (
  SELECT
    collection,
    COUNT(DISTINCT week_start) AS active_weeks
  FROM base
  GROUP BY collection
),
active_collections AS (
  SELECT collection
  FROM collection_stats
  WHERE active_weeks >= 8
),
final_trades AS (
  SELECT b.*
  FROM base AS b
  JOIN active_collections USING (collection)
)
SELECT *
FROM final_trades
""", project_id, dataset_id, project_id, dataset_id);
