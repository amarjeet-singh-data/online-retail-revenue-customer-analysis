/*
=========================================================
PART 5: COHORT ANALYSIS, CHURN, AND LTV
Goal: Measure retention, churn, and estimate customer lifetime value
=========================================================
*/

-- Cohort Retention Analysis + Monthly Churn
WITH first_purchase AS (
    SELECT customerid, MIN(DATE_TRUNC('month', invoicedate)) AS cohort_month
    FROM retail_customers
    WHERE is_return = 0
    GROUP BY customerid
),
all_purchases AS (
    SELECT customerid, DATE_TRUNC('month', invoicedate) AS purchase_month
    FROM retail_customers
    WHERE is_return = 0
),
cohort_counts AS (
    SELECT f.cohort_month, a.purchase_month, COUNT(DISTINCT a.customerid) AS num_customers
    FROM all_purchases a
    JOIN first_purchase f USING(customerid)
    GROUP BY f.cohort_month, a.purchase_month
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(*) AS cohort_size
    FROM first_purchase
    GROUP BY cohort_month
),
cohort_retention AS (
    SELECT
        cc.cohort_month,
        cc.purchase_month,
        cc.num_customers,
        cs.cohort_size,
        (cc.num_customers::numeric / cs.cohort_size) AS retention
    FROM cohort_counts cc
    JOIN cohort_sizes cs USING(cohort_month)
)
SELECT
    cohort_month,
    purchase_month,
    num_customers,
    cohort_size,
    ROUND(retention*100,2) AS retention_pct,
    ROUND((1-retention)*100,2) AS churn_pct
FROM cohort_retention
ORDER BY cohort_month, purchase_month;

/*
=========================================================
PART 6: CHURN-DRIVEN LTV ESTIMATION
Goal: Estimate customer lifetime value using churn-adjusted formula
=========================================================
*/

WITH first_purchase AS (
  SELECT
    customerid,
    DATE_TRUNC('month', MIN(invoicedate)) AS cohort_month
  FROM retail_customers
  WHERE is_return = 0
  GROUP BY customerid
),
all_purchases AS (
  SELECT
    customerid,
    DATE_TRUNC('month', invoicedate) AS purchase_month
  FROM retail_customers
  WHERE is_return = 0
),
cohort_counts AS (
  -- month_offset: 0 = cohort month, 1 = next month, etc.
  SELECT
    f.cohort_month,
    ((DATE_PART('year', a.purchase_month) - DATE_PART('year', f.cohort_month)) * 12
      + (DATE_PART('month', a.purchase_month) - DATE_PART('month', f.cohort_month)))::int
      AS month_offset,
    COUNT(DISTINCT a.customerid) AS num_customers
  FROM all_purchases a
  JOIN first_purchase f USING (customerid)
  GROUP BY f.cohort_month, month_offset
),
cohort_sizes AS (
  SELECT cohort_month, COUNT(*) AS cohort_size
  FROM first_purchase
  GROUP BY cohort_month
),
cohort_retention AS (
  SELECT
    cc.cohort_month,
    cc.month_offset,
    cc.num_customers,
    cs.cohort_size,
    (cc.num_customers::numeric / cs.cohort_size) AS retention
  FROM cohort_counts cc
  JOIN cohort_sizes cs USING (cohort_month)
),
cohort_monthly_churn AS (
  -- compute month-over-month churn per cohort
  SELECT
    cohort_month,
    month_offset,
    retention,
    LAG(retention) OVER (PARTITION BY cohort_month ORDER BY month_offset) AS prev_retention,
    CASE
      WHEN month_offset = 0 THEN NULL
      ELSE (COALESCE(LAG(retention) OVER (PARTITION BY cohort_month ORDER BY month_offset), 1)
            - retention)
           / NULLIF(COALESCE(LAG(retention) OVER (PARTITION BY cohort_month ORDER BY month_offset), 1), 0)
    END AS month_churn
  FROM cohort_retention
),
avg_monthly_churn AS (
  SELECT AVG(month_churn) AS avg_monthly_churn
  FROM cohort_monthly_churn
  WHERE month_churn IS NOT NULL
),
customer_summary AS (
  SELECT
    customerid,
    COUNT(DISTINCT invoice) AS total_orders,
    SUM(totalamount) AS total_revenue,
    MIN(invoicedate) AS first_purchase,
    MAX(invoicedate) AS last_purchase
  FROM retail_customers
  WHERE is_return = 0
  GROUP BY customerid
),
customer_metrics AS (
  SELECT
    customerid,
    (total_revenue::numeric / NULLIF(total_orders,0)) AS avg_order_value,
    total_orders,
    total_revenue,
    -- compute years active but floor at 1.0 year to avoid extreme freq for single-order customers
    GREATEST(
      EXTRACT(EPOCH FROM (last_purchase - first_purchase)) / (3600*24*365),
      1.0
    ) AS years_active
  FROM customer_summary
),
customer_freq AS (
  SELECT
    customerid,
    avg_order_value,
    total_orders,
    total_revenue,
    years_active,
    (total_orders / years_active) AS purchase_frequency_per_year
  FROM customer_metrics
)
SELECT
  cf.customerid,
  ROUND(cf.avg_order_value, 2) AS avg_order_value,
  ROUND(cf.purchase_frequency_per_year, 2) AS purchase_frequency_per_year,
  ROUND(((1.0 / NULLIF(amc.avg_monthly_churn, 0)) / 12.0), 2) AS expected_lifespan_years,
  ROUND(
    cf.avg_order_value
    * cf.purchase_frequency_per_year
    * ((1.0 / NULLIF(amc.avg_monthly_churn, 0)) / 12.0)
  , 2) AS estimated_ltv
FROM customer_freq cf
CROSS JOIN avg_monthly_churn amc
ORDER BY estimated_ltv DESC;