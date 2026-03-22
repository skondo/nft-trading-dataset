DECLARE PROJECT_ID STRING DEFAULT '<YOUR_GCP_PROJECT_ID>';
DECLARE BASE_DATASET_ID STRING DEFAULT '<YOUR_BASE_BIGQUERY_DATASET>';
DECLARE ANALYTICS_DATASET_ID STRING DEFAULT '<YOUR_ANALYTICS_BIGQUERY_DATASET>';
DECLARE CATEGORY_TABLE_NAME STRING DEFAULT 'collection_category_labels';

CREATE OR REPLACE TABLE `${PROJECT_ID}.${ANALYTICS_DATASET_ID}.clustering_master` AS
WITH universe AS (
  SELECT DISTINCT collection
  FROM `${PROJECT_ID}.${BASE_DATASET_ID}.nft_trading_usd_filtered`
),
holder_flows AS (
  SELECT collection, transfer_to AS holder, token_id, DATE(timestamp) AS trade_date, 1 AS delta
  FROM `${PROJECT_ID}.${BASE_DATASET_ID}.nft_trading_usd_filtered`
  WHERE transfer_to IS NOT NULL AND collection IS NOT NULL AND token_id IS NOT NULL
  UNION ALL
  SELECT collection, transfer_from AS holder, token_id, DATE(timestamp) AS trade_date, -1 AS delta
  FROM `${PROJECT_ID}.${BASE_DATASET_ID}.nft_trading_usd_filtered`
  WHERE transfer_from IS NOT NULL AND collection IS NOT NULL AND token_id IS NOT NULL
),
balances AS (
  SELECT collection, holder, token_id, SUM(delta) AS balance
  FROM holder_flows
  GROUP BY collection, holder, token_id
),
positive_balances AS (
  SELECT collection, holder, token_id
  FROM balances
  WHERE balance > 0
),
holder_token_counts AS (
  SELECT collection, holder, COUNT(DISTINCT token_id) AS token_count
  FROM positive_balances
  GROUP BY collection, holder
),
holder_summary AS (
  SELECT
    collection,
    COUNT(DISTINCT holder) AS unique_holders,
    SUM(token_count) AS estimated_supply,
    SAFE_DIVIDE(COUNT(DISTINCT holder), SUM(token_count)) AS unique_holder_ratio
  FROM holder_token_counts
  GROUP BY collection
),
ranked_holders AS (
  SELECT
    collection,
    holder,
    token_count,
    ROW_NUMBER() OVER (PARTITION BY collection ORDER BY token_count DESC, holder) AS holder_rank,
    SUM(token_count) OVER (PARTITION BY collection) AS total_tokens
  FROM holder_token_counts
),
top10 AS (
  SELECT collection, SAFE_DIVIDE(SUM(token_count), MAX(total_tokens)) AS top10_share
  FROM ranked_holders
  WHERE holder_rank <= 10
  GROUP BY collection
),
hhi_gini_base AS (
  SELECT
    collection,
    holder,
    token_count,
    SAFE_DIVIDE(token_count, SUM(token_count) OVER (PARTITION BY collection)) AS share,
    ROW_NUMBER() OVER (PARTITION BY collection ORDER BY token_count, holder) AS rn,
    COUNT(*) OVER (PARTITION BY collection) AS n,
    SUM(token_count) OVER (PARTITION BY collection) AS total_tokens
  FROM holder_token_counts
),
hhi_gini AS (
  SELECT
    collection,
    SUM(POW(share, 2)) AS holder_hhi,
    SAFE_DIVIDE(SUM((2 * rn - n - 1) * token_count), n * total_tokens) AS holder_gini
  FROM hhi_gini_base
  GROUP BY collection, n, total_tokens
),
first_last_holding AS (
  SELECT
    collection,
    holder,
    MIN(trade_date) AS first_seen_date,
    MAX(trade_date) AS last_seen_date
  FROM (
    SELECT collection, transfer_to AS holder, DATE(timestamp) AS trade_date
    FROM `${PROJECT_ID}.${BASE_DATASET_ID}.nft_trading_usd_filtered`
    WHERE transfer_to IS NOT NULL
    UNION ALL
    SELECT collection, transfer_from AS holder, DATE(timestamp) AS trade_date
    FROM `${PROJECT_ID}.${BASE_DATASET_ID}.nft_trading_usd_filtered`
    WHERE transfer_from IS NOT NULL
  )
  GROUP BY collection, holder
),
longterm AS (
  SELECT
    collection,
    SAFE_DIVIDE(COUNTIF(DATE_DIFF(last_seen_date, first_seen_date, DAY) >= 90), COUNT(*)) AS longterm_holder_ratio
  FROM first_last_holding
  GROUP BY collection
),
buyer_stats AS (
  SELECT collection, buyer AS wallet, COUNT(*) AS tx_count
  FROM `${PROJECT_ID}.${BASE_DATASET_ID}.nft_trading_usd_filtered`
  WHERE buyer IS NOT NULL
  GROUP BY collection, wallet
),
seller_stats AS (
  SELECT collection, seller AS wallet, COUNT(*) AS tx_count
  FROM `${PROJECT_ID}.${BASE_DATASET_ID}.nft_trading_usd_filtered`
  WHERE seller IS NOT NULL
  GROUP BY collection, wallet
),
buyer_hhi AS (
  SELECT collection,
         SUM(POW(SAFE_DIVIDE(tx_count, SUM(tx_count) OVER (PARTITION BY collection)), 2)) AS buyer_hhi
  FROM buyer_stats
  GROUP BY collection
),
seller_hhi AS (
  SELECT collection,
         SUM(POW(SAFE_DIVIDE(tx_count, SUM(tx_count) OVER (PARTITION BY collection)), 2)) AS seller_hhi
  FROM seller_stats
  GROUP BY collection
),
holder_stats AS (
  SELECT
    u.collection,
    hs.unique_holders,
    hs.estimated_supply,
    hs.unique_holder_ratio,
    t10.top10_share,
    hg.holder_gini,
    hg.holder_hhi,
    bh.buyer_hhi,
    sh.seller_hhi,
    lt.longterm_holder_ratio
  FROM universe u
  LEFT JOIN holder_summary hs USING (collection)
  LEFT JOIN top10 t10 USING (collection)
  LEFT JOIN hhi_gini hg USING (collection)
  LEFT JOIN longterm lt USING (collection)
  LEFT JOIN buyer_hhi bh USING (collection)
  LEFT JOIN seller_hhi sh USING (collection)
),
trading_stats AS (
  WITH base AS (
    SELECT
      collection,
      DATE(MIN(timestamp)) AS first_trade_date,
      DATE(MAX(timestamp)) AS latest_trade_date,
      DATE_TRUNC(DATE(MIN(timestamp)), WEEK(MONDAY)) AS first_week_start,
      DATE_TRUNC(DATE(MAX(timestamp)), WEEK(MONDAY)) AS latest_week_start,
      DATE_DIFF(DATE(MAX(timestamp)), DATE(MIN(timestamp)), DAY) + 1 AS trading_days,
      COUNT(DISTINCT week_start) AS active_weeks,
      DATE_DIFF(DATE_TRUNC(DATE(MAX(timestamp)), WEEK(MONDAY)), DATE_TRUNC(DATE(MIN(timestamp)), WEEK(MONDAY)), WEEK) + 1 AS trading_week_span,
      COUNT(*) AS trades,
      SAFE_DIVIDE(COUNT(*), DATE_DIFF(DATE(MAX(timestamp)), DATE(MIN(timestamp)), DAY) + 1) AS daily_trades,
      COUNT(DISTINCT token_id) AS unique_items,
      COUNT(DISTINCT transfer_from) AS distinct_from_count,
      COUNT(DISTINCT transfer_to) AS distinct_to_count,
      SAFE_DIVIDE(COUNT(DISTINCT transfer_to), COUNT(DISTINCT transfer_from)) AS buyer_seller_ratio,
      APPROX_QUANTILES(price_usd, 4)[OFFSET(1)] AS p25_price,
      APPROX_QUANTILES(price_usd, 4)[OFFSET(2)] AS median_price,
      APPROX_QUANTILES(price_usd, 4)[OFFSET(3)] AS p75_price,
      STDDEV(price_usd) AS stddev_price,
      MIN(price_usd) AS min_price,
      MAX(price_usd) AS max_price,
      ((ARRAY_AGG(STRUCT(timestamp, price_usd) ORDER BY timestamp DESC LIMIT 1))[OFFSET(0)].price_usd -
       (ARRAY_AGG(STRUCT(timestamp, price_usd) ORDER BY timestamp ASC LIMIT 1))[OFFSET(0)].price_usd) AS diff_price
    FROM `${PROJECT_ID}.${BASE_DATASET_ID}.nft_trading_usd_filtered`
    GROUP BY collection
  )
  SELECT b.*, r.regime_class AS first_trade_regime
  FROM base b
  LEFT JOIN `${PROJECT_ID}.${ANALYTICS_DATASET_ID}.regime_labels` r
    ON b.first_week_start = r.week_start
),
metadata_stats AS (
  SELECT
    collection,
    CASE WHEN description IS NULL OR description = '' THEN 0 ELSE 1 END AS has_description,
    description_size AS description_length,
    CASE WHEN image_url IS NULL OR image_url = '' THEN 0 ELSE 1 END AS has_image,
    CASE WHEN project_url IS NULL OR project_url = '' THEN 0 ELSE 1 END AS has_project_url,
    CASE WHEN twitter_username IS NULL OR twitter_username = '' THEN 0 ELSE 1 END AS has_twitter,
    CASE WHEN discord_url IS NULL OR discord_url = '' THEN 0 ELSE 1 END AS has_discord,
    CASE WHEN instagram_username IS NULL OR instagram_username = '' THEN 0 ELSE 1 END AS has_instagram,
    CASE WHEN telegram_url IS NULL OR telegram_url = '' THEN 0 ELSE 1 END AS has_telegram,
    CASE WHEN LOWER(token_type) = 'erc721' THEN 1 ELSE 0 END AS is_erc721,
    CASE WHEN LOWER(token_type) = 'erc1155' THEN 1 ELSE 0 END AS is_erc1155,
    CASE WHEN erc2981_supported = 1 THEN 1 ELSE 0 END AS has_erc2981,
    royalty_fee_percent
  FROM `${PROJECT_ID}.${BASE_DATASET_ID}.nft_metadata_base`
),
category_labels AS (
  SELECT collection, final_category AS category
  FROM `${PROJECT_ID}.${ANALYTICS_DATASET_ID}.${CATEGORY_TABLE_NAME}`
)
SELECT
  u.collection,
  h.unique_holders,
  h.estimated_supply,
  h.unique_holder_ratio,
  h.top10_share,
  h.holder_gini,
  h.holder_hhi,
  h.buyer_hhi,
  h.seller_hhi,
  h.longterm_holder_ratio,
  t.first_trade_date,
  t.latest_trade_date,
  t.first_week_start,
  t.latest_week_start,
  t.first_trade_regime,
  t.trading_days,
  t.active_weeks,
  t.trading_week_span,
  t.trades,
  t.daily_trades,
  t.unique_items,
  t.distinct_from_count,
  t.distinct_to_count,
  t.buyer_seller_ratio,
  t.p25_price,
  t.median_price,
  t.p75_price,
  t.stddev_price,
  t.min_price,
  t.max_price,
  t.diff_price,
  m.has_description,
  m.description_length,
  m.has_image,
  m.has_project_url,
  m.has_twitter,
  m.has_discord,
  m.has_instagram,
  m.has_telegram,
  m.is_erc721,
  m.is_erc1155,
  m.has_erc2981,
  m.royalty_fee_percent,
  c.category
FROM universe u
LEFT JOIN holder_stats h USING (collection)
LEFT JOIN trading_stats t USING (collection)
LEFT JOIN metadata_stats m USING (collection)
LEFT JOIN category_labels c USING (collection);
