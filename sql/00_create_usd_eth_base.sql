-- Replace the project and dataset placeholders before execution.
DECLARE project_id STRING DEFAULT '<YOUR_GCP_PROJECT_ID>';
DECLARE dataset_id STRING DEFAULT '<YOUR_BIGQUERY_DATASET>';
DECLARE analysis_start_date DATE DEFAULT DATE('2017-10-19');
DECLARE analysis_end_date DATE DEFAULT DATE('2025-04-01');

EXECUTE IMMEDIATE FORMAT("""
CREATE OR REPLACE TABLE `%s.%s.usd_eth_base` AS
SELECT
  TIMESTAMP_SECONDS(CAST(UnixTimeStamp AS INT64)) AS timestamp,
  DATE(TIMESTAMP_SECONDS(CAST(UnixTimeStamp AS INT64))) AS date,
  DATE_TRUNC(DATE(TIMESTAMP_SECONDS(CAST(UnixTimeStamp AS INT64))), WEEK(MONDAY)) AS week_start,
  CAST(Value AS FLOAT64) AS usd_eth_rate
FROM `%s.%s.usd_eth_raw`
WHERE TIMESTAMP_SECONDS(CAST(UnixTimeStamp AS INT64)) >= TIMESTAMP(@analysis_start_date, 'UTC')
  AND TIMESTAMP_SECONDS(CAST(UnixTimeStamp AS INT64)) < TIMESTAMP(@analysis_end_date, 'UTC')
ORDER BY timestamp
""", project_id, dataset_id, project_id, dataset_id)
USING analysis_start_date AS analysis_start_date,
      analysis_end_date AS analysis_end_date;
