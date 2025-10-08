DROP TABLE IF EXISTS analytics."СВОД МЕС";

CREATE TABLE IF NOT EXISTS analytics."СВОД МЕС" AS

WITH base AS (
    SELECT
        "артикул",
        мес,
        SUM("МАРЖА ПЛАН, ₽") AS margin_plan,
        SUM("МАРЖА ПРОГН, ₽") AS margin_forecast,

        -- runrate по марже
        CASE 
          WHEN date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day' < CURRENT_DATE - interval '1 day'
          THEN SUM("МАРЖА ПЛАН, ₽")
          ELSE SUM("МАРЖА ПЛАН, ₽") *
               (EXTRACT(DAY FROM CURRENT_DATE - interval '1 day')::numeric /
                EXTRACT(DAY FROM (date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day'))::numeric)
        END AS runrate,

        -- выручка план
        SUM("ВЫКУПЫ ОРГАНИКА ПЛАН, ₽") AS revenue_plan,

        -- runrate по выручке
        CASE 
          WHEN date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day' < CURRENT_DATE - interval '1 day'
          THEN SUM("ВЫКУПЫ ОРГАНИКА ПЛАН, ₽")
          ELSE SUM("ВЫКУПЫ ОРГАНИКА ПЛАН, ₽") *
               (EXTRACT(DAY FROM CURRENT_DATE - interval '1 day')::numeric /
                EXTRACT(DAY FROM (date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day'))::numeric)
        END AS runrate_2,

        -- выручка прогноз
        SUM(
          "ЗАКАЗЫ ОРГАНИКА ФАКТ, ₽" *
          (COALESCE(NULLIF(
              regexp_replace(
                regexp_replace(replace("ВЫКУП ПЛАН %", ',', '.'), '[^0-9\.]', '', 'g'),
                '\.+$', '', 'g'
              ),
              ''
            )::numeric, 0) / 100.0)
        ) AS revenue_forecast,

        -- выручка факт
        SUM("ВЫКУПЫ ОРГАНИКА ФАКТ, ₽") AS revenue_fact,

        -- расходы план
        SUM(
          COALESCE(NULLIF(
            regexp_replace(
              regexp_replace(replace("РЕКЛАМА РАСХОДЫ ПЛАН, ₽"::text, ',', '.'), '[^0-9\.]', '', 'g'),
              '\.+$', '', 'g'
            ),
            ''
          )::numeric, 0)
        ) AS ads_plan,

        -- расходы факт
        SUM(
          COALESCE(NULLIF(
            regexp_replace(
              regexp_replace(replace("РЕКЛАМА РАСХОДЫ ФАКТ, ₽"::text, ',', '.'), '[^0-9\.]', '', 'g'),
              '\.+$', '', 'g'
            ),
            ''
          )::numeric, 0)
        ) AS ads_fact,

        -- продажи (штуки)
        SUM("ВЫКУПЫ ОРГАНИКА ПРОГН, шт") AS sales,

        -- деньги в товаре средние дни (план)
        AVG(
          CASE 
            WHEN COALESCE(NULLIF(
              regexp_replace(
                regexp_replace(replace("ДЕНЕГ В ТОВАРЕ ПЛАН"::text, ',', '.'), '[^0-9\.]', '', 'g'),
                '\.+$', '', 'g'
              ),
              ''
            )::numeric, 0) > 0
            THEN COALESCE(NULLIF(
              regexp_replace(
                regexp_replace(replace("ДЕНЕГ В ТОВАРЕ ПЛАН"::text, ',', '.'), '[^0-9\.]', '', 'g'),
                '\.+$', '', 'g'
              ),
              ''
            )::numeric, 0)
          END
        ) AS money_in_goods_avg_days,

        -- деньги в товаре конец месяца (план)
        SUM(
          CASE 
            WHEN to_date("дата", 'DD.MM.YYYY') = LEAST(
                date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day',
                CURRENT_DATE - interval '1 day'
            )::date
            THEN COALESCE(NULLIF(
                   regexp_replace(
                     regexp_replace(replace("ДЕНЕГ В ТОВАРЕ ПЛАН"::text, ',', '.'), '[^0-9\.]', '', 'g'),
                     '\.+$', '', 'g'
                   ),
                   ''
                 )::numeric, 0)
          END
        ) AS money_in_goods_end_month,

        -- остаток ФФ
        SUM(
          CASE 
            WHEN to_date("дата", 'DD.MM.YYYY') = LEAST(
                date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day',
                CURRENT_DATE - interval '1 day'
            )::date
            THEN COALESCE(NULLIF(
                   regexp_replace(
                     regexp_replace(replace("ОСТАТОК ФФ"::text, ',', '.'), '[^0-9\.]', '', 'g'),
                     '\.+$', '', 'g'
                   ),
                   ''
                 )::numeric, 0)
          END
        ) AS ostatok_ff,

        -- остаток WB + в пути
        SUM(
          CASE 
            WHEN to_date("дата", 'DD.MM.YYYY') = LEAST(
                date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day',
                CURRENT_DATE - interval '1 day'
            )::date
            THEN COALESCE(NULLIF(
                   regexp_replace(
                     regexp_replace(replace("ОСТАТОК WB + В ПУТИ"::text, ',', '.'), '[^0-9\.]', '', 'g'),
                     '\.+$', '', 'g'
                   ),
                   ''
                 )::numeric, 0)
          END
        ) AS ostatok_wb_v_puti,

        -- остаток средние дни (только > 0)
        AVG(
          CASE 
            WHEN COALESCE(NULLIF(
              regexp_replace(
                regexp_replace(replace("остаток"::text, ',', '.'), '[^0-9\.]', '', 'g'),
                '\.+$', '', 'g'
              ),
              ''
            )::numeric, 0) > 0
            THEN COALESCE(NULLIF(
              regexp_replace(
                regexp_replace(replace("остаток"::text, ',', '.'), '[^0-9\.]', '', 'g'),
                '\.+$', '', 'g'
              ),
              ''
            )::numeric, 0)
          END
        ) AS ostatok_avg_days,

        -- средние продажи в дни (только > 0)
        AVG(
          CASE 
            WHEN COALESCE(NULLIF("ВЫКУПЫ ОРГАНИКА ПРОГН, шт", 0), 0) > 0
            THEN "ВЫКУПЫ ОРГАНИКА ПРОГН, шт"
          END
        ) AS sales_avg_days,

        -- sebes_1
        CASE 
          WHEN SUM(
                   CASE WHEN COALESCE(
                              NULLIF(regexp_replace(
                                regexp_replace(replace("остаток"::text, ',', '.'), '[^0-9\.]', '', 'g'),
                                '\.+$', '', 'g'
                              ),'' )::numeric,0
                            ) > 0
                        THEN COALESCE(
                              NULLIF(regexp_replace(
                                regexp_replace(replace("остаток"::text, ',', '.'), '[^0-9\.]', '', 'g'),
                                '\.+$', '', 'g'
                              ),'' )::numeric,0
                            )
                   END
               ) > 0
          THEN SUM(
                   CASE WHEN COALESCE(
                              NULLIF(regexp_replace(
                                regexp_replace(replace("остаток"::text, ',', '.'), '[^0-9\.]', '', 'g'),
                                '\.+$', '', 'g'
                              ),'' )::numeric,0
                            ) > 0
                        THEN COALESCE(
                              NULLIF(regexp_replace(
                                regexp_replace(replace("СЕБЕС ПЛАН"::text, ',', '.'), '[^0-9\.]', '', 'g'),
                                '\.+$', '', 'g'
                              ),'' )::numeric,0
                            )
                             * COALESCE(
                              NULLIF(regexp_replace(
                                regexp_replace(replace("остаток"::text, ',', '.'), '[^0-9\.]', '', 'g'),
                                '\.+$', '', 'g'
                              ),'' )::numeric,0
                            )
                   END
               )
               / SUM(
                   CASE WHEN COALESCE(
                              NULLIF(regexp_replace(
                                regexp_replace(replace("остаток"::text, ',', '.'), '[^0-9\.]', '', 'g'),
                                '\.+$', '', 'g'
                              ),'' )::numeric,0
                            ) > 0
                        THEN COALESCE(
                              NULLIF(regexp_replace(
                                regexp_replace(replace("остаток"::text, ',', '.'), '[^0-9\.]', '', 'g'),
                                '\.+$', '', 'g'
                              ),'' )::numeric,0
                            )
                   END
               )
          ELSE 0
        END AS sebes_1,

        -- buyout
        AVG(
          CASE 
            WHEN COALESCE(NULLIF(
              regexp_replace(
                regexp_replace(replace("ВЫКУП ПЛАН %", ',', '.'), '[^0-9\.]', '', 'g'),
                '\.+$', '', 'g'
              ),
              ''
            )::numeric, 0) > 0
            THEN COALESCE(NULLIF(
              regexp_replace(
                regexp_replace(replace("ВЫКУП ПЛАН %", ',', '.'), '[^0-9\.]', '', 'g'),
                '\.+$', '', 'g'
              ),
              ''
            )::numeric, 0)
          END
        ) AS buyout
    FROM "ПланПродаж"
    WHERE год = 2025
      AND мес BETWEEN 1 AND 12
    GROUP BY "артикул", мес
)
SELECT
    b."артикул",
    b.мес,
    (make_date(2025, b.мес::int, 1) + interval '1 month - 1 day')::date AS end_of_month,
    s."предмет",

    b.margin_plan,
    b.margin_forecast,
    b.runrate,
    CASE WHEN b.margin_plan > 0 THEN b.runrate / b.margin_plan ELSE 0 END AS percent_plan,
    CASE WHEN b.margin_plan > 0 THEN b.margin_forecast / b.margin_plan ELSE 0 END AS percent_fact,
    CASE WHEN b.margin_forecast > 0 THEN b.runrate / b.margin_forecast ELSE 0 END AS tempo,
    CASE WHEN b.revenue_plan > 0 THEN b.margin_plan / b.revenue_plan ELSE 0 END AS margin_rate_plan,
    CASE WHEN b.revenue_forecast > 0 THEN b.margin_forecast / b.revenue_forecast ELSE 0 END AS margin_rate_forecast,
    CASE WHEN b.revenue_forecast > 0 THEN b.margin_plan / b.revenue_forecast ELSE 0 END AS roi_plan,
    CASE WHEN b.revenue_forecast > 0 THEN b.margin_forecast / b.revenue_forecast ELSE 0 END AS roi_fact,
    (CASE WHEN b.revenue_plan > 0 THEN b.margin_plan / b.revenue_plan ELSE 0 END) +
    (CASE WHEN b.revenue_plan > 0 THEN b.ads_plan / b.revenue_plan ELSE 0 END) AS margin_before_drr_plan,
    (CASE WHEN b.revenue_forecast > 0 THEN b.margin_forecast / b.revenue_forecast ELSE 0 END) +
    (CASE WHEN b.revenue_forecast > 0 THEN b.ads_fact / b.revenue_forecast ELSE 0 END) AS margin_before_drr_fact,
    (CASE WHEN b.revenue_forecast > 0 THEN b.margin_plan / b.revenue_forecast ELSE 0 END) +
    (CASE WHEN b.sales > 0 THEN b.ostatok_avg_days / b.sales ELSE 0 END) AS roi_before_drr_plan,
    (CASE WHEN b.revenue_forecast > 0 THEN b.margin_forecast / b.revenue_forecast ELSE 0 END) +
    (CASE WHEN b.sales > 0 THEN b.ostatok_avg_days / b.sales ELSE 0 END) AS roi_before_drr_fact,
    CASE WHEN b.revenue_plan > 0 THEN b.ads_plan / b.revenue_plan ELSE 0 END AS drr_plan,
    CASE WHEN b.revenue_forecast > 0 THEN b.ads_fact / b.revenue_forecast ELSE 0 END AS drr_fact,
    CASE WHEN b.sales > 0 THEN b.ostatok_avg_days / b.sales ELSE 0 END AS turnover_avg_days,
    CASE WHEN b.sales > 0 THEN b.ostatok_wb_v_puti / b.sales ELSE 0 END AS turnover,
    CASE WHEN b.sales > 0 THEN (b.ostatok_ff + b.ostatok_wb_v_puti) / b.sales ELSE 0 END AS turnover_mp,    
    b.ostatok_avg_days,
    (b.ostatok_ff + b.ostatok_wb_v_puti) AS ostatok,
    b.ostatok_wb_v_puti,
    b.ostatok_ff,
    b.sales_avg_days,
    b.sales,
    b.money_in_goods_avg_days,
    b.money_in_goods_end_month,
    CASE WHEN b.money_in_goods_avg_days > 0 THEN (b.margin_forecast / b.money_in_goods_avg_days) * 12 ELSE 0 END AS gm_roi_year,
    CASE WHEN b.money_in_goods_avg_days > 0 THEN b.margin_forecast / b.money_in_goods_avg_days ELSE 0 END AS gm_roi,
    CASE WHEN b.sales > 0 THEN b.revenue_forecast / b.sales ELSE 0 END AS avg_check,
    b.sebes_1,
    b.buyout,
    NULL::numeric AS sebes_2,
    b.revenue_plan,
    b.runrate_2,
    b.revenue_forecast,
    b.revenue_fact,
    CASE WHEN b.revenue_plan > 0 THEN b.runrate_2 / b.revenue_plan ELSE 0 END AS percent_plan_2,
    CASE WHEN b.revenue_plan > 0 THEN b.revenue_forecast / b.revenue_plan ELSE 0 END AS percent_fact_2,
    CASE WHEN b.runrate_2 > 0 THEN b.revenue_forecast / b.runrate_2 ELSE 0 END AS tempo_2
FROM base b
LEFT JOIN "справочник" s
  ON s."Артикул поставщика" = b."артикул"
ORDER BY b."артикул", b.мес;
