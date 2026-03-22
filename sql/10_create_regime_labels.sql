-- Create weekly regime labels after selecting changepoint boundaries.
-- Update BOOM_START and POST_BOOM_START to the dates selected from the notebook.

DECLARE PROJECT_ID STRING DEFAULT '<YOUR_GCP_PROJECT_ID>';
DECLARE BASE_DATASET_ID STRING DEFAULT '<YOUR_BASE_BIGQUERY_DATASET>';
DECLARE ANALYTICS_DATASET_ID STRING DEFAULT '<YOUR_ANALYTICS_BIGQUERY_DATASET>';
DECLARE BOOM_START DATE DEFAULT DATE('<BOOM_START_DATE>');
DECLARE POST_BOOM_START DATE DEFAULT DATE('<POST_BOOM_START_DATE>');

EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.regime_labels` AS
WITH weekly_trades AS (
  SELECT DISTINCT week_start
  FROM `%s.%s.nft_trading_usd_prefilter`
)
SELECT
  week_start,
  CASE
    WHEN week_start < @boom_start THEN 'pre-boom'
    WHEN week_start < @post_boom_start THEN 'boom'
    ELSE 'post-boom'
  END AS regime_class,
  @boom_start AS boom_start,
  @post_boom_start AS post_boom_start,
  6 AS selected_penalty
FROM weekly_trades
ORDER BY week_start
""", PROJECT_ID, ANALYTICS_DATASET_ID, PROJECT_ID, BASE_DATASET_ID)
USING BOOM_START AS boom_start, POST_BOOM_START AS post_boom_start;
