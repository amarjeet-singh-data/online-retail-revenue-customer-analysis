/*
=========================================================
PART 3: RETURN RATE ANALYSIS
Goal: Calculate returns % by product, country, and combination
=========================================================
*/

-- 3.1 Return % by Product
WITH sales AS (
    SELECT stockcode, description, SUM(quantity) AS total_sales_qty
    FROM retail_customers
    WHERE is_return = 0
    GROUP BY stockcode, description
),
returns AS (
    SELECT stockcode, description, SUM(ABS(quantity)) AS total_return_qty
    FROM retail_customers
    WHERE is_return = 1
    GROUP BY stockcode, description
)
SELECT
    s.stockcode,
    s.description,
    s.total_sales_qty,
    COALESCE(r.total_return_qty, 0) AS total_return_qty,
    ROUND((COALESCE(r.total_return_qty,0) * 100.0) / NULLIF(s.total_sales_qty,0),2) AS return_percentage,
    CASE 
        WHEN COALESCE(r.total_return_qty,0) > s.total_sales_qty THEN '⚠️ Incomplete sales history'
        ELSE 'Valid'
    END AS data_quality_flag
FROM sales s
LEFT JOIN returns r
    ON s.stockcode = r.stockcode AND s.description = r.description
ORDER BY return_percentage DESC;

-- 3.2 Return % by Country
WITH sales AS (
    SELECT country, SUM(quantity) AS total_sales_qty
    FROM retail_customers
    WHERE is_return = 0
    GROUP BY country
),
returns AS (
    SELECT country, SUM(ABS(quantity)) AS total_return_qty
    FROM retail_customers
    WHERE is_return = 1
    GROUP BY country
)
SELECT
    s.country AS country_name,
    s.total_sales_qty,
    COALESCE(r.total_return_qty, 0) AS total_return_qty,
    ROUND((COALESCE(r.total_return_qty,0) * 100.0)/NULLIF(s.total_sales_qty,0),2) AS return_percentage
FROM sales s
LEFT JOIN returns r
    ON s.country = r.country
ORDER BY return_percentage DESC;

-- 3.3 Return % by Product and Country (Optional Ranking)
WITH sales AS (
    SELECT stockcode, description, country, SUM(quantity) AS total_sales_qty
    FROM retail_customers
    WHERE is_return = 0
    GROUP BY stockcode, description, country
),
returns AS (
    SELECT stockcode, description, country, SUM(ABS(quantity)) AS total_return_qty
    FROM retail_customers
    WHERE is_return = 1
    GROUP BY stockcode, description, country
)
SELECT
    s.stockcode,
    s.description,
    s.country,
    s.total_sales_qty,
    COALESCE(r.total_return_qty,0) AS total_return_qty,
    ROUND((COALESCE(r.total_return_qty,0)*100.0)/NULLIF(s.total_sales_qty,0),2) AS return_percentage,
    CASE 
        WHEN COALESCE(r.total_return_qty,0) > s.total_sales_qty THEN '⚠️ Incomplete sales history'
        ELSE 'Valid'
    END AS data_quality_flag,
    RANK() OVER (
        PARTITION BY s.country
        ORDER BY (COALESCE(r.total_return_qty,0)*100.0)/NULLIF(s.total_sales_qty,0) DESC
    ) AS rank_by_return
FROM sales s
LEFT JOIN returns r
    ON s.stockcode = r.stockcode
    AND s.description = r.description
    AND s.country = r.country
ORDER BY return_percentage DESC;
