-- Create the USD-enriched transaction table.

DECLARE PROJECT_ID STRING DEFAULT '<YOUR_GCP_PROJECT_ID>';
DECLARE DATASET_ID STRING DEFAULT '<YOUR_BIGQUERY_DATASET>';

EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.nft_trading_usd` AS
SELECT
  t.*,
  e.usd_eth_rate AS eth_usd_rate,
  SAFE_MULTIPLY(t.price_eth, e.usd_eth_rate) AS price_usd,
  SAFE_MULTIPLY(t.fee_eth, e.usd_eth_rate) AS fee_usd
FROM `%s.%s.nft_trading_base` AS t
LEFT JOIN `%s.%s.usd_eth_base` AS e
  ON DATE(t.timestamp) = e.date
""", PROJECT_ID, DATASET_ID, PROJECT_ID, DATASET_ID, PROJECT_ID, DATASET_ID);
