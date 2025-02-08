-- A. Customer Journey
SELECT 
    customer_id,
    plan_name,
    price,
    start_date
FROM subscriptions AS S
INNER JOIN plans AS P ON S.plan_id = P.plan_id
WHERE customer_id <= 8;

-- B. Data Analysis Questions
-- 1. Total number of customers
SELECT COUNT(DISTINCT customer_id) AS customer_count FROM subscriptions;

-- 2. Monthly distribution of trial plan starts
SELECT 
    DATE_FORMAT(start_date, '%Y-%m-01') AS month,
    COUNT(customer_id) AS trial_starts
FROM subscriptions
WHERE plan_id = 0
GROUP BY month;

-- 3. Plan start_date values after 2020 grouped by plan_name
SELECT 
    plan_name,
    COUNT(*) AS count_of_events
FROM subscriptions AS S
INNER JOIN plans AS P ON S.plan_id = P.plan_id
WHERE YEAR(start_date) > 2020
GROUP BY plan_name;

-- 4. Customer count and percentage of churned customers
SELECT 
    (SELECT COUNT(DISTINCT customer_id) FROM subscriptions) AS customer_count,
    ROUND((COUNT(DISTINCT customer_id) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions)) * 100, 1) AS churned_customers_percent
FROM subscriptions 
WHERE plan_id = 4;

-- 5. Customers who churned right after the free trial
WITH CTE AS (
    SELECT 
        customer_id,
        plan_name,
        ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date ASC) AS rn
    FROM subscriptions AS S
    INNER JOIN plans AS P ON S.plan_id = P.plan_id
)
SELECT 
    COUNT(DISTINCT customer_id) AS churned_after_trial_customers,
    ROUND((COUNT(DISTINCT customer_id) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions)) * 100, 0) AS percent_churn_after_trial
FROM CTE
WHERE rn = 2 AND plan_name = 'churn';

-- 6. Number and percentage of customer plans after the free trial
WITH CTE AS (
    SELECT
        customer_id,
        plan_name,
        ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date ASC) AS rn
    FROM subscriptions AS S
    INNER JOIN plans AS P ON P.plan_id = S.plan_id
)
SELECT 
    plan_name,
    COUNT(customer_id) AS customer_count,
    ROUND((COUNT(customer_id) / (SELECT COUNT(DISTINCT customer_id) FROM CTE)) * 100, 1) AS customer_percent
FROM CTE
WHERE rn = 2
GROUP BY plan_name;

-- 7. Customer count and percentage breakdown of all plan names at 2020-12-31
WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY start_date DESC) AS rn
    FROM subscriptions
    WHERE start_date <= '2020-12-31'
)
SELECT 
    plan_name,
    COUNT(customer_id) AS customer_count,
    ROUND((COUNT(customer_id) / (SELECT COUNT(DISTINCT customer_id) FROM CTE)) * 100, 1) AS percent_of_customers
FROM CTE
INNER JOIN plans AS P ON CTE.plan_id = P.plan_id
WHERE rn = 1
GROUP BY plan_name;

-- 8. Customers who upgraded to an annual plan in 2020
SELECT COUNT(customer_id) AS annual_upgrade_customers
FROM subscriptions AS S
INNER JOIN plans AS P ON P.plan_id = S.plan_id
WHERE YEAR(start_date) = 2020 AND plan_name = 'pro annual';

-- Monthly customers upgrading to annual in 2020
WITH MONTHLY_CUSTOMERS AS (
    SELECT customer_id, start_date
    FROM subscriptions
    WHERE YEAR(start_date) <= 2020 AND plan_id IN (1, 2)
),
ANNUAL_CUSTOMERS AS (
    SELECT customer_id, start_date
    FROM subscriptions
    WHERE YEAR(start_date) = 2020 AND plan_id = 3
)
SELECT COUNT(DISTINCT A.customer_id) AS annual_upgrade_customers
FROM MONTHLY_CUSTOMERS AS M
INNER JOIN ANNUAL_CUSTOMERS AS A 
    ON M.customer_id = A.customer_id AND M.start_date < A.start_date;

-- 9. Average days to upgrade to an annual plan
WITH TRIAL AS (
    SELECT customer_id, start_date AS trial_start
    FROM subscriptions WHERE plan_id = 0
),
ANNUAL AS (
    SELECT customer_id, start_date AS annual_start
    FROM subscriptions WHERE plan_id = 3
)
SELECT ROUND(AVG(DATEDIFF(annual_start, trial_start)), 0) AS average_days_from_trial_to_annual
FROM TRIAL AS T
INNER JOIN ANNUAL AS A ON T.customer_id = A.customer_id;

-- 10. Breakdown of upgrade time into 30-day bins
WITH TRIAL AS (
    SELECT customer_id, start_date AS trial_start
    FROM subscriptions WHERE plan_id = 0
),
ANNUAL AS (
    SELECT customer_id, start_date AS annual_start
    FROM subscriptions WHERE plan_id = 3
)
SELECT 
    CASE
        WHEN DATEDIFF(annual_start, trial_start) <= 30  THEN '0-30'
        WHEN DATEDIFF(annual_start, trial_start) <= 60  THEN '31-60'
        WHEN DATEDIFF(annual_start, trial_start) <= 90  THEN '61-90'
        WHEN DATEDIFF(annual_start, trial_start) <= 120 THEN '91-120'
        WHEN DATEDIFF(annual_start, trial_start) <= 150 THEN '121-150'
        WHEN DATEDIFF(annual_start, trial_start) <= 180 THEN '151-180'
        WHEN DATEDIFF(annual_start, trial_start) <= 210 THEN '181-210'
        WHEN DATEDIFF(annual_start, trial_start) <= 240 THEN '211-240'
        WHEN DATEDIFF(annual_start, trial_start) <= 270 THEN '241-270'
        WHEN DATEDIFF(annual_start, trial_start) <= 300 THEN '271-300'
        WHEN DATEDIFF(annual_start, trial_start) <= 330 THEN '301-330'
        WHEN DATEDIFF(annual_start, trial_start) <= 360 THEN '331-360'
    END AS bin,
    COUNT(T.customer_id) AS customer_count
FROM TRIAL AS T
INNER JOIN ANNUAL AS A ON T.customer_id = A.customer_id
GROUP BY bin;

-- 11. Customers who downgraded from pro monthly to basic monthly in 2020
WITH PRO_MON AS (
    SELECT customer_id, start_date AS pro_monthly_start
    FROM subscriptions WHERE plan_id = 2
),
BASIC_MON AS (
    SELECT customer_id, start_date AS basic_monthly_start
    FROM subscriptions WHERE plan_id = 1
)
SELECT 
    P.customer_id,
    pro_monthly_start,
    basic_monthly_start
FROM PRO_MON AS P
INNER JOIN BASIC_MON AS B ON P.customer_id = B.customer_id
WHERE pro_monthly_start < basic_monthly_start
AND YEAR(basic_monthly_start) = 2020;
