DECLARE PROJECT_ID STRING DEFAULT '<YOUR_GCP_PROJECT_ID>';
DECLARE BASE_DATASET_ID STRING DEFAULT '<YOUR_BASE_BIGQUERY_DATASET>';
DECLARE ANALYTICS_DATASET_ID STRING DEFAULT '<YOUR_ANALYTICS_BIGQUERY_DATASET>';

CREATE OR REPLACE TABLE `${PROJECT_ID}.${ANALYTICS_DATASET_ID}.weekly_returns_vw` AS
WITH nft_ret AS (
  SELECT
    collection,
    week_start,
    total_volume_usd,
    CASE
      WHEN LAG(week_start) OVER (PARTITION BY collection ORDER BY week_start) IS NOT NULL
       AND DATE_DIFF(
             week_start,
             LAG(week_start) OVER (PARTITION BY collection ORDER BY week_start),
             DAY
           ) = 7
       AND median_price_usd > 0
       AND LAG(median_price_usd) OVER (PARTITION BY collection ORDER BY week_start) > 0
      THEN LOG(
        SAFE_DIVIDE(
          median_price_usd,
          LAG(median_price_usd) OVER (PARTITION BY collection ORDER BY week_start)
        )
      )
      ELSE NULL
    END AS nft_return
  FROM `${PROJECT_ID}.${ANALYTICS_DATASET_ID}.weekly_collection_panel_filtered`
),
market_ret AS (
  SELECT
    week_start,
    SAFE_DIVIDE(
      SUM(nft_return * total_volume_usd),
      SUM(total_volume_usd)
    ) AS market_return
  FROM nft_ret
  WHERE nft_return IS NOT NULL
    AND total_volume_usd IS NOT NULL
    AND total_volume_usd > 0
  GROUP BY week_start
),
fx_weekly AS (
  SELECT
    week_start,
    AVG(SAFE_CAST(usd_eth_rate AS FLOAT64)) AS avg_usd_eth_rate
  FROM `${PROJECT_ID}.${BASE_DATASET_ID}.usd_eth_base`
  WHERE usd_eth_rate IS NOT NULL
  GROUP BY week_start
),
fx_ret AS (
  SELECT
    week_start,
    LOG(
      SAFE_DIVIDE(
        avg_usd_eth_rate,
        LAG(avg_usd_eth_rate) OVER (ORDER BY week_start)
      )
    ) AS fx_return
  FROM fx_weekly
)
SELECT
  n.collection,
  n.week_start,
  n.nft_return,
  m.market_return,
  f.fx_return
FROM nft_ret AS n
LEFT JOIN market_ret AS m
  ON n.week_start = m.week_start
LEFT JOIN fx_ret AS f
  ON n.week_start = f.week_start
WHERE n.nft_return IS NOT NULL
ORDER BY n.collection, n.week_start;
