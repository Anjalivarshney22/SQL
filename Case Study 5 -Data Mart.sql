-- Data Cleansing and Transformation
CREATE TABLE data_mart.clean_weekly_sales AS 
WITH date_cte AS (
    SELECT 
        STR_TO_DATE(week_date, '%d/%m/%Y') AS formatted_date,
        segment,
        region,
        platform,
        customer_type,
        sales,
        transactions
    FROM weekly_sales
)
SELECT 
    formatted_date AS week_date,
    WEEK(formatted_date) AS week_number,
    MONTH(formatted_date) AS month_number,
    YEAR(formatted_date) AS calendar_year,
    segment,
    CASE 
        WHEN RIGHT(segment, 1) = '1' THEN 'Young Adults'
        WHEN RIGHT(segment, 1) = '2' THEN 'Middle Aged'
        WHEN RIGHT(segment, 1) IN ('3', '4') THEN 'Retirees'
        ELSE 'unknown'
    END AS age_band,
    CASE 
        WHEN LEFT(segment, 1) = 'C' THEN 'Couples'
        WHEN LEFT(segment, 1) = 'F' THEN 'Families'
        ELSE 'unknown'
    END AS demographic,
    ROUND(sales / NULLIF(transactions, 0), 2) AS avg_transaction,
    region,
    platform,
    customer_type,
    sales,
    transactions
FROM date_cte;

---B--- Data Exploration----

--1--
SELECT 
  DISTINCT(DAYNAME(week_date)) AS week_date_day 
FROM clean_weekly_sales;

--2.
SELECT 
  calendar_year, COUNT(transactions) AS transcations_count 
FROM clean_weekly_sales 
GROUP BY calendar_year 
ORDER BY calendar_year;

--3.
SELECT 
  region, month_number, SUM(sales) AS total_sales_amount 
FROM clean_weekly_sales 
GROUP BY region, month_number 
ORDER BY region, month_number;

--4.
SELECT
  platform, COUNT(*) AS transactions_count_for_platform
FROM clean_weekly_sales
GROUP BY platform;

--5.
WITH monthly_sales AS (
    SELECT 
        calendar_year, 
        month_number, 
        platform, 
        SUM(sales) AS monthly_sales 
    FROM clean_weekly_sales 
    GROUP BY calendar_year, month_number, platform
), 
platform_sales AS (
    SELECT 
        calendar_year, 
        month_number,
        MAX(CASE WHEN platform = 'Retail' THEN monthly_sales ELSE NULL END) AS retail_sales,
        MAX(CASE WHEN platform = 'Shopify' THEN monthly_sales ELSE NULL END) AS shopify_sales,
        SUM(monthly_sales) AS total_sales
    FROM monthly_sales
    GROUP BY calendar_year, month_number
),
final_calc AS (
    SELECT 
        calendar_year, 
        month_number,
        ROUND(100 * retail_sales / NULLIF(total_sales, 0), 2) AS retail_sales_percentage,
        ROUND(100 * shopify_sales / NULLIF(total_sales, 0), 2) AS shopify_sales_percentage
    FROM platform_sales
)
SELECT * FROM final_calc;

--6.
WITH yearly_sales AS
(SELECT 
  calendar_year, demographic, SUM(sales) AS yearly_sales 
FROM clean_weekly_sales 
GROUP BY calendar_year, demographic 
ORDER BY calendar_year)

SELECT 
  calendar_year,
  ROUND(100*MAX(CASE WHEN demographic="Couples" THEN yearly_sales ELSE NULL END)/SUM(yearly_sales), 2) AS couples_percentage,
  ROUND(100*MAX(CASE WHEN demographic="Families" THEN yearly_sales ELSE NULL END)/SUM(yearly_sales), 2) AS Families_percentage,
  ROUND(100*MAX(CASE WHEN demographic="unknown" THEN yearly_sales ELSE NULL END)/SUM(yearly_sales), 2) AS unknown_percentage
FROM yearly_sales
GROUP BY calendar_year;

--7.
WITH retail_sales AS 
(SELECT 
  age_band, demographic, SUM(sales) AS total_retail_sales 
FROM clean_weekly_sales 
WHERE platform = "Retail" 
GROUP BY age_band, demographic 
ORDER BY total_retail_sales DESC)

SELECT 
  age_band, demographic, total_retail_sales, 
  ROUND(100*(total_retail_sales/SUM(total_retail_sales) OVER()), 2) AS retail_sales_contribution_pct 
FROM retail_sales 
ORDER BY retail_sales_contribution_pct DESC;

--8.
SELECT 
  calendar_year, platform, ROUND(SUM(sales)/SUM(transactions), 0) AS transaction_size 
FROM clean_weekly_sales 
GROUP BY calendar_year, platform 
ORDER BY calendar_year;

-- We can use the 'avg_transaction' column to calculate the 'average transaction size'
-- Average Transaction Size can be calculated by - total sales for the entire dataset/total number of transactions for the entire dataset