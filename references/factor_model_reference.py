def build_weekly_market_return_vw(
    forceCreate=False,
    suffix="",
    src_table="nftpricing.analytics.weekly_collection_panel_filtered"
):
    """
    Build collection-level value-weighted market return using lagged volume weights.

    Parameters
    ----------
    forceCreate : bool
        If True, overwrite existing table.
    suffix : str
        Table suffix such as "" or "_susp".
    src_table : str
        Source weekly collection panel table.
    """

    table_id = f"nftpricing.analytics.weekly_market_return_vw{suffix}"

    if is_exist_table(table_id) and forceCreate is False:
        print(f"table : {table_id} exists, skip.")
        return

    sql = f"""
    CREATE OR REPLACE TABLE `{table_id}` AS
    WITH base AS (
      SELECT
        collection,
        week_start,
        median_price_usd,
        total_volume_usd,
        LAG(week_start) OVER (
          PARTITION BY collection ORDER BY week_start
        ) AS prev_week_start,
        LAG(median_price_usd) OVER (
          PARTITION BY collection ORDER BY week_start
        ) AS prev_median_price_usd,
        LAG(total_volume_usd) OVER (
          PARTITION BY collection ORDER BY week_start
        ) AS prev_total_volume_usd
      FROM `{src_table}`
    ),

    collection_ret AS (
      SELECT
        collection,
        week_start,
        total_volume_usd,
        prev_total_volume_usd,
        CASE
          WHEN prev_week_start IS NOT NULL
           AND DATE_DIFF(week_start, prev_week_start, DAY) = 7
           AND median_price_usd > 0
           AND prev_median_price_usd > 0
          THEN LOG(SAFE_DIVIDE(median_price_usd, prev_median_price_usd))
          ELSE NULL
        END AS collection_return
      FROM base
    )

    SELECT
      week_start,
      SAFE_DIVIDE(
        SUM(collection_return * prev_total_volume_usd),
        SUM(prev_total_volume_usd)
      ) AS market_return,
      COUNTIF(collection_return IS NOT NULL) AS n_collections_used,
      SUM(prev_total_volume_usd) AS total_lagged_volume_used
    FROM collection_ret
    WHERE collection_return IS NOT NULL
      AND prev_total_volume_usd IS NOT NULL
      AND prev_total_volume_usd > 0
    GROUP BY week_start
    ORDER BY week_start
    ;
    """

    _ = bpd.read_gbq(sql)
    print(f"✔ weekly_market_return_vw built → {table_id}")

def build_weekly_returns_vw(
    forceCreate=False,
    suffix="",
    market_table=None,
    fx_table="nftpricing.analytics.weekly_usd_eth_index",
    nft_table="nftpricing.analytics.weekly_collection_panel_filtered"
):
    """
    Create weekly returns table using:
      - NFT return from collection-level median weekly price
      - Market return from value-weighted market return table
      - FX return from weekly ETH/USD index

    Parameters
    ----------
    forceCreate : bool
        If True, overwrite existing table.
    suffix : str
        Table suffix such as "" or "_susp".
    market_table : str or None
        Market return table. If None, use weekly_market_return_vw{suffix}.
    fx_table : str
        Weekly ETH/USD table.
    nft_table : str
        Weekly collection panel table.
    """

    table_id = f"nftpricing.analytics.weekly_returns_vw{suffix}"
    if market_table is None:
        market_table = f"nftpricing.analytics.weekly_market_return_vw{suffix}"

    if is_exist_table(table_id) and not forceCreate:
        print(f"table : {table_id} exists, skip.")
        return

    sql = f"""
    CREATE OR REPLACE TABLE `{table_id}` AS
    WITH
      nft_ret AS (
        SELECT
          collection,
          week_start,
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
        FROM `{nft_table}`
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
        FROM `{fx_table}`
      )

    SELECT
      n.collection,
      n.week_start,
      n.nft_return,
      m.market_return,
      f.fx_return
    FROM nft_ret AS n
    LEFT JOIN `{market_table}` AS m
      ON n.week_start = m.week_start
    LEFT JOIN fx_ret AS f
      ON n.week_start = f.week_start
    WHERE n.nft_return IS NOT NULL
    ORDER BY n.collection, n.week_start
    ;
    """

    _ = bpd.read_gbq(sql)
    print(f"✔ weekly_returns_vw built → {table_id}")