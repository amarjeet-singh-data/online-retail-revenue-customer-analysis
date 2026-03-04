/*
=========================================================
PART 4: RFM SEGMENTATION
Goal: Segment customers by Recency, Frequency, Monetary value
=========================================================
*/

WITH rfm_base AS (
    SELECT
        customerid,
        MAX(invoicedate) AS last_purchase_date,
        COUNT(DISTINCT invoice) AS frequency,
        SUM(totalamount) AS monetary
    FROM retail_customers
    WHERE is_return = 0
    GROUP BY customerid
),
max_date AS (
    SELECT MAX(invoicedate) AS max_invoice_date
    FROM retail_customers
    WHERE is_return = 0
),
rfm_calc AS (
    SELECT
        r.customerid,
        DATE_PART('day', m.max_invoice_date - r.last_purchase_date) AS recency,
        r.frequency,
        r.monetary
    FROM rfm_base r
    CROSS JOIN max_date m
),
rfm_scores AS (
    SELECT
        customerid,
        recency,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_calc
),
rfm_labeled AS (
    SELECT
        customerid,
        recency,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        CAST((r_score::text || f_score::text || m_score::text) AS INTEGER) AS rfm_segment,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'VIP'
            WHEN f_score >= 4 AND m_score >= 4 THEN 'Loyal'
            WHEN r_score <= 2 THEN 'At-Risk'
            WHEN f_score <= 2 OR m_score <= 2 THEN 'Need Attention'
            ELSE 'Regular'
        END AS segment
    FROM rfm_scores
)
SELECT
    segment,
    COUNT(customerid) AS num_customers,
    ROUND(SUM(monetary),0) AS total_revenue,
    CAST(AVG(recency) AS INTEGER) AS avg_recency,
    ROUND(AVG(frequency),0) AS avg_frequency,
    ROUND(AVG(monetary),0) AS avg_monetary
FROM rfm_labeled
GROUP BY segment
ORDER BY total_revenue DESC;