DROP TABLE IF EXISTS analytics."СводНед";
CREATE TABLE analytics."СводНед" AS

WITH prepared AS (
    SELECT
        "артикул",
        to_date("дата", 'DD.MM.YYYY')::date AS дата,
        EXTRACT(WEEK FROM to_date("дата", 'DD.MM.YYYY'))::int AS нед,
        EXTRACT(MONTH FROM to_date("дата", 'DD.MM.YYYY'))::int AS мес,
        COALESCE(NULLIF(regexp_replace("ПРИХОД НА Р/С ПЛАН"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS prihod_rs_plan,

        -- план и факт по марже
        COALESCE(NULLIF(regexp_replace("МАРЖА ПЛАН, ₽"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS margin_plan,
        COALESCE(NULLIF(regexp_replace("МАРЖА ПРОГН, ₽"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS margin_forecast,
        COALESCE(NULLIF(regexp_replace("RUN RATE"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS runrate,
        COALESCE(NULLIF(regexp_replace("МАРЖА ЗА МЕСЯЦ ФАКТ, ₽"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS margin_cum_total,

        -- выручки
        COALESCE(NULLIF(regexp_replace("ВЫКУПЫ ОРГАНИКА ПЛАН, ₽"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS revenue_plan,
        COALESCE(NULLIF(regexp_replace("ЗАКАЗЫ ОРГАНИКА ФАКТ, ₽"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS orders_fact,
        COALESCE(NULLIF(regexp_replace("ВЫКУП ПЛАН %"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS buyout_plan_pct,
        COALESCE(NULLIF(regexp_replace("ВЫКУПЫ ОРГАНИКА ФАКТ, ₽"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS revenue_fact,

        -- расходы
        COALESCE(NULLIF(regexp_replace("РЕКЛАМА РАСХОДЫ ПЛАН, ₽"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS ads_plan,
        COALESCE(NULLIF(regexp_replace("РЕКЛАМА РАСХОДЫ ФАКТ, ₽"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS ads_fact,

        -- остатки
        COALESCE(NULLIF(regexp_replace("остаток"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS ostatok,
        COALESCE(NULLIF(regexp_replace("ОСТАТОК ФФ"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS ostatok_ff,
        COALESCE(NULLIF(regexp_replace("ОСТАТОК WB + В ПУТИ"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS ostatok_wb_v_puti,

        -- себес и деньги в товаре
        COALESCE(NULLIF(regexp_replace("СЕБЕС ПЛАН"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS sebes_plan,
        COALESCE(NULLIF(regexp_replace("ДЕНЕГ В ТОВАРЕ ПЛАН"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS money_in_goods_plan,

        -- продажи
        COALESCE(NULLIF(regexp_replace("ВЫКУПЫ ОРГАНИКА ПРОГН, шт"::text, '[^0-9\.]', '', 'g'), '')::numeric, 0) AS sales_plan_units
    FROM "ПланПродаж"
    WHERE год = 2025
)

, weekly AS (
    SELECT
        нед,
        "артикул",
        SUM(margin_plan) AS margin_plan,
        SUM(margin_forecast) AS margin_forecast,
        SUM(runrate) AS runrate,
        SUM(margin_cum_total) AS margin_cum_total,

        SUM(revenue_plan) AS revenue_plan,
        SUM(orders_fact * (buyout_plan_pct / 100.0)) AS revenue_forecast,
        SUM(revenue_fact) AS revenue_fact,

        SUM(ads_plan) AS ads_plan,
        SUM(ads_fact) AS ads_fact,

        AVG(NULLIF(ostatok,0)) AS ostatok_avg_days,
        SUM(ostatok) AS ostatok,
        SUM(ostatok_ff) AS ostatok_ff,
        SUM(ostatok_wb_v_puti) AS ostatok_wb_v_puti,

        SUM(sales_plan_units) AS sales,
        AVG(NULLIF(sales_plan_units,0)) AS sales_avg_days,

        AVG(NULLIF(money_in_goods_plan,0)) AS money_in_goods_avg_days,
        SUM(money_in_goods_plan) AS money_in_goods_end_week,

        CASE 
          WHEN SUM(NULLIF(ostatok,0)) > 0
          THEN SUM(sebes_plan * NULLIF(ostatok,0)) / SUM(NULLIF(ostatok,0))
          ELSE 0
        END AS sebes_1,

        CASE 
          WHEN MIN(мес) < EXTRACT(MONTH FROM CURRENT_DATE) THEN SUM(revenue_plan)
          WHEN MIN(мес) = EXTRACT(MONTH FROM CURRENT_DATE)
               THEN SUM(revenue_plan) *
                    (EXTRACT(DAY FROM CURRENT_DATE)::numeric /
                     EXTRACT(DAY FROM (date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day'))::numeric)
          ELSE 0
        END AS runrate_2,
		SUM(CASE WHEN дата = (date_trunc('month', дата) + interval '1 month - 1 day') THEN prihod_rs_plan end ) AS prihod_rs_plan,
        AVG(NULLIF(buyout_plan_pct,0)) AS buyout_pct,


        MIN(мес) AS мес
    FROM prepared
    GROUP BY нед, "артикул"
)

, monthly AS (
    SELECT
        "артикул",
        EXTRACT(MONTH FROM дата)::int AS мес,
        SUM(margin_plan) AS margin_plan_month,
        SUM(revenue_plan) AS revenue_plan_month
    FROM prepared
    GROUP BY "артикул", EXTRACT(MONTH FROM дата)
)

SELECT
    2025 AS год,
	w.нед,
    w."артикул",
    w.margin_plan,
    w.margin_forecast,
    w.runrate,
    w.margin_cum_total,

    CASE WHEN m.margin_plan_month > 0 THEN w.runrate / m.margin_plan_month ELSE 0 END AS percent_plan,
    CASE WHEN m.margin_plan_month > 0 THEN w.margin_cum_total / m.margin_plan_month ELSE 0 END AS percent_fact,
    CASE WHEN w.runrate > 0 THEN w.margin_cum_total / w.runrate ELSE 0 END AS tempo,

    CASE WHEN w.revenue_plan > 0 THEN w.margin_plan / w.revenue_plan ELSE 0 END AS margin_rate_plan,
    CASE WHEN w.revenue_fact > 0 THEN w.margin_cum_total / w.revenue_fact ELSE 0 END AS margin_rate_fact,

    (CASE WHEN w.revenue_plan > 0 THEN w.margin_plan / w.revenue_plan ELSE 0 END) +
    (CASE WHEN w.revenue_plan > 0 THEN w.ads_plan / w.revenue_plan ELSE 0 END) AS margin_before_drr_plan,

    (CASE WHEN w.revenue_fact > 0 THEN w.margin_cum_total / w.revenue_fact ELSE 0 END) +
    (CASE WHEN w.revenue_fact > 0 THEN w.ads_fact / w.revenue_fact ELSE 0 END) AS margin_before_drr_fact,

    CASE WHEN w.revenue_plan > 0 THEN w.ads_plan / w.revenue_plan ELSE 0 END AS drr_plan_pct,
    CASE WHEN w.revenue_fact > 0 THEN w.ads_fact / w.revenue_fact ELSE 0 END AS drr_fact_pct,

    CASE WHEN w.sales > 0 THEN w.ostatok_avg_days / w.sales ELSE 0 END AS turnover_avg_days,
    CASE WHEN w.sales > 0 THEN w.ostatok_wb_v_puti / w.sales ELSE 0 END AS turnover,
    CASE WHEN w.sales > 0 THEN (w.ostatok_ff + w.ostatok_wb_v_puti) / w.sales ELSE 0 END AS turnover_mp,

    w.ostatok_avg_days,
    w.ostatok,
    w.ostatok_wb_v_puti,
    w.ostatok_ff,

    w.sales_avg_days,
    w.sales,

    w.money_in_goods_avg_days,
    w.money_in_goods_end_week AS money_in_goods,

    CASE WHEN w.money_in_goods_avg_days > 0 THEN (w.margin_forecast / w.money_in_goods_avg_days) * 12 ELSE 0 END AS roi_year,
    CASE WHEN w.money_in_goods_avg_days > 0 THEN w.margin_forecast / w.money_in_goods_avg_days ELSE 0 END AS roi,

    CASE WHEN w.sales > 0 THEN w.revenue_forecast / w.sales ELSE 0 END AS avg_check,

    w.sebes_1,
    w.buyout_pct,

    w.revenue_plan,
    w.revenue_forecast,
    w.runrate_2,

    w.revenue_forecast AS revenue_cum_total,
    w.revenue_fact,

    
    CASE WHEN m.revenue_plan_month > 0 THEN w.runrate_2 / m.revenue_plan_month ELSE 0 END AS percent_plan_2,
    CASE WHEN m.revenue_plan_month > 0 THEN w.revenue_forecast / m.revenue_plan_month ELSE 0 END AS percent_fact_2,
    CASE WHEN w.runrate_2 > 0 THEN w.revenue_forecast / w.runrate_2 ELSE 0 END AS tempo_2,
    w.prihod_rs_plan

FROM weekly w
LEFT JOIN monthly m
    ON w."артикул" = m."артикул"
   AND w.мес = m.мес
ORDER BY w.нед, w."артикул";
