SELECT
    "артикул" AS article,
    год,
    мес,
    SUM("МАРЖА ПЛАН, ₽")   AS margin_plan,
    SUM("МАРЖА ПРОГН, ₽")  AS margin_forecast,
    SUM(regexp_replace("МАРЖА ФАКТ", '[^0-9\.\-]', '', 'g')::numeric) AS margin_fact,
    CASE WHEN SUM("МАРЖА ПЛАН, ₽") > 0
         THEN SUM(regexp_replace("МАРЖА ФАКТ", '[^0-9\.\-]', '', 'g')::numeric)
              / SUM("МАРЖА ПЛАН, ₽")
         ELSE 0 END AS percent_plan,
    CASE WHEN SUM("РЕКЛАМА РАСХОДЫ ПЛАН, ₽") > 0
         THEN SUM("МАРЖА ПЛАН, ₽") / SUM("РЕКЛАМА РАСХОДЫ ПЛАН, ₽")
         ELSE 0 END AS roi_plan,
    CASE WHEN SUM("РЕКЛАМА РАСХОДЫ ФАКТ, ₽") > 0
         THEN SUM(regexp_replace("МАРЖА ФАКТ", '[^0-9\.\-]', '', 'g')::numeric)
              / SUM("РЕКЛАМА РАСХОДЫ ФАКТ, ₽")
         ELSE 0 END AS roi_fact
FROM "ПланПродаж"
WHERE год = 2025
GROUP BY "артикул", год, мес
ORDER BY "артикул", год, мес;

