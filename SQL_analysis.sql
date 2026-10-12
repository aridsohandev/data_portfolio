/* =====================================================================
   SALES PERFORMANCE ANALYSIS - 12 SQL QUERIES  (MySQL 8.0+)
   Dataset : dataset.csv (2,707 orders, 20 columns)
   Goal    : Answer the questions a business would actually ask -
             where do we make money, what is dragging margin down,
             and what is the trend?
   ===================================================================== */


/* ---------------------------------------------------------------------
   STEP 0 - DATABASE, TABLE, LOAD, CLEAN
   (Error 1046 fix: a database must be selected with USE before CREATE TABLE.)
   --------------------------------------------------------------------- */

CREATE DATABASE IF NOT EXISTS sales_analysis;
USE sales_analysis;

DROP TABLE IF EXISTS sales_raw;
CREATE TABLE sales_raw (
    id               VARCHAR(20),
    order_date       VARCHAR(20),
    region           VARCHAR(50),
    country          VARCHAR(50),
    sales_channel    VARCHAR(50),
    customer_type    VARCHAR(50),
    product_category VARCHAR(50),
    product          VARCHAR(100),
    units_sold       VARCHAR(20),
    unit_price       VARCHAR(20),
    discount_pct     VARCHAR(20),
    unit_cost        VARCHAR(20),
    revenue          VARCHAR(20),
    cogs             VARCHAR(20),
    gross_profit     VARCHAR(20),
    gross_margin_pct VARCHAR(20),
    year             VARCHAR(10),
    quarter          VARCHAR(10),
    month_no         VARCHAR(10),
    month            VARCHAR(10)
);

/* LOADING THE CSV (uses your file path directly)

   Before the first run, LOCAL INFILE must be allowed on BOTH sides:
     1) the server  -> the SET GLOBAL line below (needs an admin account such as root)
     2) the client  -> in Workbench: Database > Manage Connections > select your
        connection > Advanced tab > in "Others" add:   OPT_LOCAL_INFILE=1
        then close and reopen the connection.
   Errors 3948 / 2068 mean one of these two is still switched off.

   If you would rather not change settings: skip the two statements below,
   right-click sales_raw in the Schemas panel -> Table Data Import Wizard ->
   pick dataset.csv -> "Use existing table: sales_analysis.sales_raw".
*/
SET GLOBAL local_infile = 1;

TRUNCATE TABLE sales_raw;   -- makes the script safe to re-run without duplicating rows

LOAD DATA LOCAL INFILE 'C:/Users/selfs/Downloads/dataset.csv'
INTO TABLE sales_raw
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'          -- also works for Windows files; stray \r is trimmed in the view
IGNORE 1 LINES;

-- Sanity check after loading: should return 2707
SELECT COUNT(*) AS rows_loaded FROM sales_raw;

/* Clean view: strips $ , % symbols and casts to proper types.
   All 12 queries below run against this view, never the raw table. */
CREATE OR REPLACE VIEW sales AS
SELECT
    CAST(id AS UNSIGNED)                                                       AS order_id,
    STR_TO_DATE(order_date, '%d-%b-%Y')                                        AS order_date,
    region,
    country,
    sales_channel,
    customer_type,
    product_category,
    product,
    CAST(units_sold AS UNSIGNED)                                               AS units_sold,
    CAST(REPLACE(REPLACE(unit_price,   '$', ''), ',', '') AS DECIMAL(12,2))    AS unit_price,
    CAST(REPLACE(discount_pct, '%', '') AS DECIMAL(5,2))                       AS discount_pct,
    CAST(REPLACE(REPLACE(unit_cost,    '$', ''), ',', '') AS DECIMAL(12,2))    AS unit_cost,
    CAST(REPLACE(REPLACE(revenue,      '$', ''), ',', '') AS DECIMAL(12,2))    AS revenue,
    CAST(REPLACE(REPLACE(cogs,         '$', ''), ',', '') AS DECIMAL(12,2))    AS cogs,
    CAST(REPLACE(REPLACE(gross_profit, '$', ''), ',', '') AS DECIMAL(12,2))    AS gross_profit,
    CAST(REPLACE(gross_margin_pct, '%', '') AS DECIMAL(6,2))                   AS gross_margin_pct,
    CAST(year AS UNSIGNED)                                                     AS year,
    quarter,
    CAST(month_no AS UNSIGNED)                                                 AS month_no,
    TRIM(REPLACE(month, '\r', ''))                                             AS month
FROM sales_raw;

-- Verify the cleaning worked (numbers, not text, and no NULL dates)
SELECT * FROM sales LIMIT 5;
SELECT COUNT(*) AS bad_dates FROM sales WHERE order_date IS NULL;


/* =====================================================================
   Q1. EXECUTIVE SUMMARY - the headline KPIs
   Business question: How big is the business and how healthy are margins?
   Note: margin is computed from totals (SUM/SUM), NOT as an average of the
   per-order margin column, which would overweight small orders.
   ===================================================================== */
SELECT
    COUNT(*)                                             AS total_orders,
    SUM(units_sold)                                      AS total_units,
    ROUND(SUM(revenue), 2)                               AS total_revenue,
    ROUND(SUM(gross_profit), 2)                          AS total_gross_profit,
    ROUND(100.0 * SUM(gross_profit) / SUM(revenue), 2)   AS gross_margin_pct,
    ROUND(AVG(revenue), 2)                               AS avg_order_value,
    ROUND(AVG(discount_pct), 2)                          AS avg_discount_pct,
    MIN(order_date)                                      AS first_order,
    MAX(order_date)                                      AS last_order
FROM sales;


/* =====================================================================
   Q2. REGIONAL PERFORMANCE WITH SHARE OF TOTAL
   Business question: Which regions drive revenue, and which are most
   profitable per dollar sold?
   Technique: aggregate + window function over the aggregate for share %.
   ===================================================================== */
SELECT
    region,
    COUNT(*)                                                       AS orders,
    ROUND(SUM(revenue), 2)                                         AS revenue,
    ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1)     AS revenue_share_pct,
    ROUND(SUM(gross_profit), 2)                                    AS gross_profit,
    ROUND(100.0 * SUM(gross_profit) / SUM(revenue), 1)             AS margin_pct,
    RANK() OVER (ORDER BY SUM(revenue) DESC)                       AS revenue_rank
FROM sales
GROUP BY region
ORDER BY revenue DESC;


/* =====================================================================
   Q3. TOP 10 PRODUCTS BY GROSS PROFIT
   Business question: Which products actually earn the money?
   Ranking by profit instead of revenue matters - a high-revenue product
   can have thin margins (see Q11).
   ===================================================================== */
SELECT
    product,
    product_category,
    SUM(units_sold)                                       AS units_sold,
    ROUND(SUM(revenue), 2)                                AS revenue,
    ROUND(SUM(gross_profit), 2)                           AS gross_profit,
    ROUND(100.0 * SUM(gross_profit) / SUM(revenue), 1)    AS margin_pct
FROM sales
GROUP BY product, product_category
ORDER BY SUM(gross_profit) DESC
LIMIT 10;


/* =====================================================================
   Q4. MONTHLY REVENUE TREND WITH MONTH-OVER-MONTH GROWTH
   Business question: Is the business growing, and is there seasonality?
   Technique: CTE + LAG() window function.
   ===================================================================== */
WITH monthly AS (
    SELECT
        year,
        month_no,
        month,
        SUM(revenue)       AS revenue,
        SUM(gross_profit)  AS gross_profit
    FROM sales
    GROUP BY year, month_no, month
)
SELECT
    year,
    month,
    ROUND(revenue, 2)       AS revenue,
    ROUND(gross_profit, 2)  AS gross_profit,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY year, month_no))
          / NULLIF(LAG(revenue) OVER (ORDER BY year, month_no), 0), 1) AS mom_growth_pct
FROM monthly
ORDER BY year, month_no;


/* =====================================================================
   Q5. QUARTERLY PERFORMANCE WITH QUARTER-OVER-QUARTER CHANGE
   Business question: How do quarters compare, in revenue and in margin?
   ===================================================================== */
WITH quarterly AS (
    SELECT
        year,
        quarter,
        COUNT(*)           AS orders,
        SUM(revenue)       AS revenue,
        SUM(gross_profit)  AS gross_profit
    FROM sales
    GROUP BY year, quarter
)
SELECT
    year,
    quarter,
    orders,
    ROUND(revenue, 2)                                   AS revenue,
    ROUND(100.0 * gross_profit / revenue, 1)            AS margin_pct,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY year, quarter))
          / NULLIF(LAG(revenue) OVER (ORDER BY year, quarter), 0), 1) AS qoq_growth_pct
FROM quarterly
ORDER BY year, quarter;


/* =====================================================================
   Q6. DISCOUNT IMPACT ANALYSIS
   Business question: Do discounts pay for themselves? Do bigger discounts
   lift order size enough to justify the margin we give up?
   ===================================================================== */
SELECT
    discount_pct,
    COUNT(*)                                              AS orders,
    ROUND(AVG(units_sold), 2)                             AS avg_units_per_order,
    ROUND(AVG(revenue), 2)                                AS avg_order_value,
    ROUND(100.0 * SUM(gross_profit) / SUM(revenue), 1)    AS margin_pct,
    ROUND(AVG(gross_profit), 2)                           AS avg_profit_per_order,
    ROUND(SUM(gross_profit), 2)                           AS total_profit
FROM sales
GROUP BY discount_pct
ORDER BY discount_pct;


/* =====================================================================
   Q7. SALES CHANNEL x CUSTOMER TYPE PROFITABILITY MATRIX
   Business question: Which combination of channel and customer segment
   is most valuable per order?
   ===================================================================== */
SELECT
    sales_channel,
    customer_type,
    COUNT(*)                                              AS orders,
    ROUND(SUM(revenue), 2)                                AS revenue,
    ROUND(AVG(revenue), 2)                                AS avg_order_value,
    ROUND(100.0 * SUM(gross_profit) / SUM(revenue), 1)    AS margin_pct,
    ROUND(AVG(discount_pct), 1)                           AS avg_discount_pct
FROM sales
GROUP BY sales_channel, customer_type
ORDER BY SUM(gross_profit) DESC;


/* =====================================================================
   Q8. CATEGORY MIX WITHIN EACH REGION
   Business question: Does each region buy a different product mix?
   Technique: SUM() OVER (PARTITION BY region) to get a share that sums
   to 100% inside each region.
   ===================================================================== */
SELECT
    region,
    product_category,
    ROUND(SUM(revenue), 2)                                               AS revenue,
    ROUND(100.0 * SUM(revenue)
          / SUM(SUM(revenue)) OVER (PARTITION BY region), 1)             AS pct_of_region_revenue,
    ROUND(100.0 * SUM(gross_profit) / SUM(revenue), 1)                   AS margin_pct
FROM sales
GROUP BY region, product_category
ORDER BY region, SUM(revenue) DESC;


/* =====================================================================
   Q9. TOP 3 PRODUCTS IN EVERY REGION
   Business question: What are the best sellers locally, so regional
   managers can prioritise stock and promotion?
   Technique: ROW_NUMBER() inside a CTE, filtered in the outer query.
   ===================================================================== */
WITH ranked AS (
    SELECT
        region,
        product,
        SUM(revenue)       AS revenue,
        SUM(gross_profit)  AS gross_profit,
        ROW_NUMBER() OVER (PARTITION BY region ORDER BY SUM(revenue) DESC) AS rn
    FROM sales
    GROUP BY region, product
)
SELECT
    region,
    rn                     AS rank_in_region,
    product,
    ROUND(revenue, 2)      AS revenue,
    ROUND(gross_profit, 2) AS gross_profit
FROM ranked
WHERE rn <= 3
ORDER BY region, rn;


/* =====================================================================
   Q10. CUMULATIVE REVENUE AND 3-MONTH MOVING AVERAGE
   Business question: Smoothing out noise, what is the underlying trend,
   and how are we tracking year to date?
   Technique: running total + moving average using window frames.
   ===================================================================== */
WITH monthly AS (
    SELECT year, month_no, month, SUM(revenue) AS revenue
    FROM sales
    GROUP BY year, month_no, month
)
SELECT
    year,
    month,
    ROUND(revenue, 2) AS revenue,
    ROUND(SUM(revenue) OVER (PARTITION BY year ORDER BY month_no), 2) AS ytd_revenue,
    ROUND(AVG(revenue) OVER (
              ORDER BY year, month_no
              ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2)           AS moving_avg_3m
FROM monthly
ORDER BY year, month_no;


/* =====================================================================
   Q11. HIGH-REVENUE, LOW-MARGIN PRODUCTS (PROFIT LEAKS)
   Business question: Which products sell a lot but earn less margin than
   the company average - candidates for repricing or cost renegotiation?
   Technique: CTEs, benchmark values, and a CASE flag.
   ===================================================================== */
WITH product_stats AS (
    SELECT
        product,
        product_category,
        SUM(revenue)                                       AS revenue,
        SUM(gross_profit)                                  AS gross_profit,
        100.0 * SUM(gross_profit) / SUM(revenue)           AS margin_pct,
        AVG(discount_pct)                                  AS avg_discount_pct
    FROM sales
    GROUP BY product, product_category
),
benchmarks AS (
    SELECT
        (SELECT 100.0 * SUM(gross_profit) / SUM(revenue) FROM sales) AS company_margin_pct,
        AVG(revenue)                                                 AS avg_product_revenue
    FROM product_stats
)
SELECT
    p.product,
    p.product_category,
    ROUND(p.revenue, 2)               AS revenue,
    ROUND(p.margin_pct, 1)            AS margin_pct,
    ROUND(b.company_margin_pct, 1)    AS company_margin_pct,
    ROUND(p.avg_discount_pct, 1)      AS avg_discount_pct,
    CASE
        WHEN p.revenue >= b.avg_product_revenue
         AND p.margin_pct < b.company_margin_pct THEN 'REVIEW PRICING'
        ELSE 'OK'
    END AS flag
FROM product_stats p
CROSS JOIN benchmarks b
ORDER BY (p.revenue >= b.avg_product_revenue AND p.margin_pct < b.company_margin_pct) DESC,
         p.revenue DESC;


/* =====================================================================
   Q12. PARETO ANALYSIS - WHICH COUNTRIES MAKE UP 80% OF REVENUE?
   Business question: How concentrated is revenue? Which markets are the
   core and which are the long tail?
   Technique: cumulative share with a running SUM window, then a label.
   ===================================================================== */
WITH country_rev AS (
    SELECT country, region, SUM(revenue) AS revenue
    FROM sales
    GROUP BY country, region
),
cumulative AS (
    SELECT
        country,
        region,
        revenue,
        100.0 * revenue / SUM(revenue) OVER ()                         AS share_pct,
        100.0 * SUM(revenue) OVER (ORDER BY revenue DESC
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
              / SUM(revenue) OVER ()                                   AS cumulative_share_pct
    FROM country_rev
)
SELECT
    country,
    region,
    ROUND(revenue, 2)               AS revenue,
    ROUND(share_pct, 1)             AS share_pct,
    ROUND(cumulative_share_pct, 1)  AS cumulative_share_pct,
    CASE WHEN cumulative_share_pct - share_pct < 80
         THEN 'Core market (top 80%)'
         ELSE 'Long tail' END       AS tier
FROM cumulative
ORDER BY revenue DESC;
