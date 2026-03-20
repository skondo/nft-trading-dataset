-- Create nft_trading_usd
--
-- Update the two variables below before execution.

DECLARE project_id STRING DEFAULT '<YOUR_GCP_PROJECT_ID>';
DECLARE dataset_id STRING DEFAULT '<YOUR_BIGQUERY_DATASET>';

EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.nft_trading_usd` AS
WITH usd_eth AS (
  SELECT
    PARSE_DATE('%%m/%%d/%%Y', `Date(UTC)`) AS price_date,
    SAFE_CAST(Value AS FLOAT64) AS eth_usd_rate,
    SAFE_CAST(UnixTimeStamp AS INT64) AS unix_timestamp
  FROM `%s.%s.usd_eth_base`
)
SELECT
  t.*,
  u.eth_usd_rate,
  SAFE_MULTIPLY(t.price_eth, u.eth_usd_rate) AS price_usd,
  SAFE_MULTIPLY(t.fee_eth, u.eth_usd_rate) AS fee_usd
FROM `%s.%s.nft_trading_base` AS t
LEFT JOIN usd_eth AS u
  ON DATE(t.timestamp) = u.price_date
""", project_id, dataset_id, project_id, dataset_id, project_id, dataset_id);
