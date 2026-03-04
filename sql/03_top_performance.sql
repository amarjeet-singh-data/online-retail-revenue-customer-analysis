/*
=========================================================
PART 2: TOP PERFORMERS (Customers, Products, Countries)
Goal: Identify key revenue contributors
=========================================================
*/

-- 2.1 Top 10 Customers by Revenue (Global)
SELECT
    customerid AS customer_id,
    INITCAP(country) AS country_name,
    ROUND(SUM(totalamount), 2) AS total_revenue
FROM retail_customers
GROUP BY customer_id, country_name
ORDER BY total_revenue DESC
LIMIT 10;

-- 2.2 Top 10 Products by Revenue
SELECT
    INITCAP(description) AS product_name,
    INITCAP(country) AS country_name,
    ROUND(SUM(totalamount), 2) AS total_revenue
FROM retail_sales
GROUP BY product_name, country_name
ORDER BY total_revenue DESC
LIMIT 10;

-- 2.3 Top 10 Products by Quantity Sold
SELECT
    INITCAP(description) AS product_name,
    INITCAP(country) AS country_name,
    ROUND(SUM(quantity), 0) AS total_quantity
FROM retail_sales
GROUP BY product_name, country_name
ORDER BY total_quantity DESC
LIMIT 10;

-- 2.4 Top 10 Countries by Revenue
SELECT
    INITCAP(country) AS country_name,
    ROUND(SUM(totalamount), 2) AS total_revenue
FROM retail_Sales
GROUP BY country_name
ORDER BY total_revenue DESC
LIMIT 10;

-- 2.5 Top 10 Customers per Country
SELECT *
FROM (
    SELECT 
        customerid AS customer_id,
        INITCAP(country) AS country_name,
        ROUND(SUM(totalamount), 2) AS total_revenue,
        RANK() OVER (
            PARTITION BY country
            ORDER BY SUM(totalamount) DESC
        ) AS rank_per_country
    FROM retail_customers
    GROUP BY customerid, country
) sub
WHERE rank_per_country <= 10
ORDER BY country_name, rank_per_country;
