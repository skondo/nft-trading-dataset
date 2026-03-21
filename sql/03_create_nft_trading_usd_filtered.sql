-- Replace the project and dataset placeholders before execution.
DECLARE project_id STRING DEFAULT '<YOUR_GCP_PROJECT_ID>';
DECLARE dataset_id STRING DEFAULT '<YOUR_BIGQUERY_DATASET>';
DECLARE min_active_weeks INT64 DEFAULT 8;

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
  WHERE active_weeks >= @min_active_weeks
),
final_trades AS (
  SELECT b.*
  FROM base b
  JOIN active_collections USING(collection)
)
SELECT *
FROM final_trades
""", project_id, dataset_id, project_id, dataset_id)
USING min_active_weeks AS min_active_weeks;
