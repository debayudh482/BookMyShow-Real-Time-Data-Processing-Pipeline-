-- Azure Synapse / SQL Server version
WITH w AS (
  SELECT *
  FROM bookymyshow.bookings_fact
  WHERE booking_time >= DATEADD(day, -7, SYSUTCDATETIME())
)
SELECT
  'Last 7 Days' AS period,
  COUNT(*) AS total_transactions,
  SUM(total_amount) AS total_revenue,
  AVG(total_amount) AS avg_transaction_value,
  COUNT(DISTINCT customer_id) AS unique_customers,
  SUM(CASE WHEN payment_status = 'Success' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS success_rate_pct,

  SUM(CASE WHEN event_category LIKE '%Music%'  THEN total_amount ELSE 0 END) AS music_revenue,
  SUM(CASE WHEN event_category LIKE '%Cinema%' THEN total_amount ELSE 0 END) AS cinema_revenue,
  SUM(CASE WHEN event_category LIKE '%Sports%' THEN total_amount ELSE 0 END) AS sports_revenue,

  SUM(CASE WHEN booking_platform = 'Mobile App' THEN 1 ELSE 0 END) AS mobile_bookings,
  SUM(CASE WHEN booking_platform = 'Website'   THEN 1 ELSE 0 END) AS website_bookings,

  (SELECT TOP 1 customer_city
     FROM w
     WHERE customer_city IS NOT NULL
     GROUP BY customer_city
     ORDER BY SUM(total_amount) DESC) AS top_city,

  SUM(CASE WHEN alert_category <> 'Normal' THEN 1 ELSE 0 END) AS anomaly_count,
  AVG(processing_time_ms) AS avg_processing_time_ms
FROM w;