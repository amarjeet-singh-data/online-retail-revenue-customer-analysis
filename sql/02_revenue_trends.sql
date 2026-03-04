/*
=========================================================
PART 1: TIME SERIES ANALYSIS (Revenue Over Time)
Goal: Identify trends, seasonality, and growth patterns
=========================================================
*/

-- 1.1 Total Revenue per Year
SELECT
    EXTRACT(YEAR FROM invoicedate) AS invoice_year,
    SUM(totalamount) AS total_revenue
FROM retail_sales
GROUP BY invoice_year
ORDER BY invoice_year DESC;

-- 1.2 Total Revenue per Month (across all years)
SELECT
    EXTRACT(MONTH FROM invoicedate) AS invoice_month,
    SUM(totalamount) AS total_revenue
FROM retail_sales
GROUP BY invoice_month
ORDER BY total_revenue DESC;

-- 1.3 Total Revenue per Month-Year (chronological)
SELECT
    DATE_TRUNC('month', invoicedate) AS month_start,
    SUM(totalamount) AS total_revenue
FROM retail_sales
GROUP BY month_start
ORDER BY month_start;

-- 1.4 Month-over-Month (MoM) Growth Analysis
SELECT
    DATE_TRUNC('month', invoicedate) AS month_start,
    SUM(totalamount) AS total_revenue,
    COALESCE(
        LAG(SUM(totalamount)) OVER (ORDER BY DATE_TRUNC('month', invoicedate)), 
        SUM(totalamount)
    ) AS prev_month_revenue,
    ROUND(
        ((SUM(totalamount) - COALESCE(LAG(SUM(totalamount)) OVER (ORDER BY DATE_TRUNC('month', invoicedate)), SUM(totalamount)))
        / NULLIF(COALESCE(LAG(SUM(totalamount)) OVER (ORDER BY DATE_TRUNC('month', invoicedate)), SUM(totalamount)), 0)
        ) * 100, 2
    ) AS mom_growth_pct
FROM retail_sales
GROUP BY month_start
ORDER BY month_start;

-- 1.5 Rolling 3-Month Average Revenue
SELECT
    "Month",
    "Revenue",
    ROUND(AVG("Revenue") OVER (
        ORDER BY "Month"
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_3m_avg
FROM (
    SELECT
        DATE_TRUNC('month', invoicedate) AS "Month",
        SUM(totalamount) AS "Revenue"
    FROM retail_sales
    GROUP BY 1
) sub;