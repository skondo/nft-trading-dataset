-- Retain collections observed in at least the configured number of active weeks.

DECLARE PROJECT_ID STRING DEFAULT '<YOUR_GCP_PROJECT_ID>';
DECLARE DATASET_ID STRING DEFAULT '<YOUR_BIGQUERY_DATASET>';
DECLARE MIN_ACTIVE_WEEKS INT64 DEFAULT 8;

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
)
SELECT b.*
FROM base AS b
JOIN active_collections USING (collection)
""", PROJECT_ID, DATASET_ID, PROJECT_ID, DATASET_ID)
USING MIN_ACTIVE_WEEKS AS min_active_weeks;
