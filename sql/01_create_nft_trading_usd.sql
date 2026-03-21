-- Replace the project and dataset placeholders before execution.
DECLARE project_id STRING DEFAULT '<YOUR_GCP_PROJECT_ID>';
DECLARE dataset_id STRING DEFAULT '<YOUR_BIGQUERY_DATASET>';

EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.nft_trading_usd` AS
SELECT
  t.*,
  fx.usd_eth_rate,
  t.price_eth * fx.usd_eth_rate AS price_usd,
  t.fee_eth * fx.usd_eth_rate AS fee_usd
FROM `%s.%s.nft_trading_base` AS t
LEFT JOIN `%s.%s.usd_eth_base` AS fx
  ON DATE(t.timestamp) = fx.date
""", project_id, dataset_id, project_id, dataset_id, project_id, dataset_id);
