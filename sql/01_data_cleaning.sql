-- #########################################################
-- RETAIL DATA CLEANING PIPELINE (CTE-BASED, PRODUCTION STYLE)
-- Author: Amar
-- Purpose: Produce clean, analysis-ready transaction data
-- #########################################################

-- =========================================================
-- EXCLUSION LOOKUP TABLE (EXACT REMOVALS ONLY)
-- =========================================================
DROP TABLE IF EXISTS retail_exclusion_terms;

CREATE TABLE retail_exclusion_terms (
    exclusion_type  VARCHAR(20),   -- 'stockcode' or 'description'
    exclusion_value VARCHAR(100)
);

-- Stockcode-based admin rows
INSERT INTO retail_exclusion_terms VALUES
('stockcode', 'M'),
('stockcode', 'D'),
('stockcode', 'ADJUST'),
('stockcode', 'ADJUST2'),
('stockcode', 'TEST001'),
('stockcode', 'TEST002'),
('stockcode', 'CRUK'),
('stockcode', 'S'),
('stockcode', 'AMAZONFEE');

-- Exact description-based admin rows
INSERT INTO retail_exclusion_terms VALUES
('description', 'Bank Charges'),
('description', 'Carriage'),
('description', 'Discount'),
('description', 'Postage'),
('description', 'Manual'),
('description', 'Next Day Carriage'),
('description', 'Dotcom Postage');


-- =========================================================
-- MAIN CLEANING PIPELINE (CTE → CREATE TABLE)
-- =========================================================
DROP TABLE IF EXISTS retail_sales;

CREATE TABLE retail_sales AS
WITH

-- Step 1: Deduplication
dedup AS (
    SELECT
        invoice, stockcode, description, quantity, invoicedate,
        price, customerid, country
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY invoice, stockcode, description, quantity,
                                invoicedate, price, customerid, country
                   ORDER BY invoice
               ) AS rn
        FROM retail_invoices
    ) t
    WHERE rn = 1
),

-- Step 2: Clean descriptions
desc_clean AS (
    SELECT
        invoice,
        stockcode,
        TRIM(COALESCE(NULLIF(description, ''), 'Unknown')) AS description,
        quantity,
        invoicedate,
        price,
        customerid,
        country
    FROM dedup
),

-- Step 3: Remove invalid rows
valid_rows AS (
    SELECT *
    FROM desc_clean
    WHERE price > 0
      AND quantity <> 0
),

-- Step 4: Add computed fields
calc_fields AS (
    SELECT
        invoice,
        stockcode,
        INITCAP(TRIM(description)) AS description,
        quantity,
        invoicedate,
        price,
        customerid,
        country,
        (quantity * price) AS totalamount,
        CASE WHEN invoice LIKE 'C%' OR quantity < 0 THEN 1 ELSE 0 END AS is_return
    FROM valid_rows
),

-- Step 5: Remove admin/service rows
filtered AS (
    SELECT cf.*
    FROM calc_fields cf
    LEFT JOIN retail_exclusion_terms et
      ON (
             (et.exclusion_type = 'stockcode'    AND cf.stockcode = et.exclusion_value)
          OR (et.exclusion_type = 'description' AND cf.description = et.exclusion_value)
         )
    WHERE et.exclusion_value IS NULL
)

-- Final output of pipeline → retail_sales
SELECT * FROM filtered;


-- =========================================================
-- CUSTOMER-LEVEL TABLE
-- =========================================================
DROP TABLE IF EXISTS retail_customers;

CREATE TABLE retail_customers AS
SELECT *
FROM retail_sales
WHERE customerid IS NOT NULL;


-- =========================================================
-- INDEXES (PERFORMANCE OPTIMIZATION)
-- =========================================================
CREATE INDEX idx_sales_invoice   ON retail_sales(invoice);
CREATE INDEX idx_sales_customer  ON retail_sales(customerid);
CREATE INDEX idx_sales_date      ON retail_sales(invoicedate);
CREATE INDEX idx_sales_stockcode ON retail_sales(stockcode);

-- #########################################################
-- CLEANING PIPELINE COMPLETE
-- #########################################################
