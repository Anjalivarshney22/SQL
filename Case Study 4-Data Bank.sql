-- A. Customer Nodes Exploration

-- 1. How many unique nodes are there on the Data Bank system?
SELECT 
    COUNT(DISTINCT node_id) AS unique_nodes
FROM customer_nodes;

-- 2. What is the number of nodes per region?
SELECT 
    region_name,
    COUNT(DISTINCT node_id) AS nodes
FROM customer_nodes AS C
INNER JOIN regions AS R ON C.region_id = R.region_id
GROUP BY region_name;

-- 3. How many customers are allocated to each region?
SELECT 
    region_name,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM customer_nodes AS C
INNER JOIN regions AS R ON C.region_id = R.region_id
GROUP BY region_name;

-- 4. How many days on average are customers reallocated to a different node?
WITH DAYS_IN_NODE AS (
    SELECT 
        customer_id,
        node_id,
        SUM(DATEDIFF(end_date, start_date)) AS days_in_node
    FROM customer_nodes
    WHERE end_date <> '9999-12-31'
    GROUP BY customer_id, node_id
)
SELECT 
    ROUND(AVG(days_in_node), 0) AS average_days_in_node
FROM DAYS_IN_NODE;

-- 5. What is the median, 80th, and 95th percentile for this same reallocation days metric for each region?
WITH DAYS_IN_NODE AS (
    SELECT 
        region_name,
        customer_id,
        node_id,
        SUM(DATEDIFF(end_date, start_date)) AS days_in_node
    FROM customer_nodes AS C
    INNER JOIN regions AS R ON R.region_id = C.region_id
    WHERE end_date <> '9999-12-31'
    GROUP BY region_name, customer_id, node_id
),
ORDERED AS (
    SELECT 
        region_name,
        days_in_node,
        ROW_NUMBER() OVER(PARTITION BY region_name ORDER BY days_in_node) AS rn,
        COUNT(*) OVER(PARTITION BY region_name) AS total_count
    FROM DAYS_IN_NODE
)
SELECT 
    region_name,
    CASE 
        WHEN rn = ROUND(total_count / 2, 0) THEN 'Median'
        WHEN rn = ROUND(total_count * 0.8, 0) THEN '80th Percentile'
        WHEN rn = ROUND(total_count * 0.95, 0) THEN '95th Percentile'
    END AS metric,
    days_in_node AS value
FROM ORDERED
WHERE rn IN (
    ROUND(total_count / 2, 0),
    ROUND(total_count * 0.8, 0),
    ROUND(total_count * 0.95, 0)
);
 -- B. Customer Transactions
-- 1. What is the unique count and total amount for each transaction type?
SELECT 
txn_type,
SUM(txn_amount) AS total_amount,
COUNT(*) AS transaction_count
FROM customer_transactions
GROUP BY txn_type;

-- 2. What is the average total historical deposit counts and amounts for all customers
WITH CTE AS (
SELECT 
customer_id,
AVG(txn_amount) AS avg_deposit,
COUNT(*) AS transaction_count
FROM customer_transactions
WHERE txn_type = 'deposit'
GROUP BY customer_id
)
SELECT 
ROUND(AVG(avg_deposit),2) AS avg_deposit_amount,
ROUND(AVG(transaction_count),0) AS avg_transactions
FROM CTE;

-- 3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
WITH CTE AS (
SELECT 
DATE_FORMAT(txn_date, '%Y-%m-01') AS month,
customer_id,
SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) AS deposits,
SUM(CASE WHEN txn_type <> 'deposit' THEN 1 ELSE 0 END) AS purchase_or_withdrawal
FROM customer_transactions
GROUP BY month, customer_id
HAVING SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) > 1
AND SUM(CASE WHEN txn_type <> 'deposit' THEN 1 ELSE 0 END) = 1
)
SELECT 
month,
COUNT(customer_id) AS customers
FROM CTE
GROUP BY month;

-- 4. What is the closing balance for each customer at the end of the month?
WITH CTE AS (
SELECT 
DATE_FORMAT(txn_date, '%Y-%m-01') AS txn_month,
txn_date,
customer_id,
SUM(CASE WHEN txn_type ='deposit' THEN txn_amount ELSE -txn_amount END) AS balance
FROM customer_transactions
GROUP BY txn_month, txn_date, customer_id
)
, BALANCES AS (
SELECT 
*,
SUM(balance) OVER (PARTITION BY customer_id ORDER BY txn_date) AS running_sum,
ROW_NUMBER() OVER (PARTITION BY customer_id, txn_month ORDER BY txn_date DESC) AS rn
FROM CTE
ORDER BY txn_date
)
SELECT 
customer_id,
LAST_DAY(txn_month) AS end_of_month,
running_sum AS closing_balance
FROM BALANCES 
WHERE rn = 1;

-- 5. What is the percentage of customers who increase their closing balance by more than 5%?
WITH CTE AS (
SELECT 
DATE_FORMAT(txn_date, '%Y-%m-01') AS txn_month,
txn_date,
customer_id,
SUM(CASE WHEN txn_type ='deposit' THEN txn_amount ELSE -txn_amount END) AS balance
FROM customer_transactions
GROUP BY txn_month, txn_date, customer_id
)
, BALANCES AS (
SELECT 
*,
SUM(balance) OVER (PARTITION BY customer_id ORDER BY txn_date) AS running_sum,
ROW_NUMBER() OVER (PARTITION BY customer_id, txn_month ORDER BY txn_date DESC) AS rn
FROM CTE
ORDER BY txn_date
)
, CLOSING_BALANCES AS (
SELECT 
customer_id,
LAST_DAY(txn_month) AS end_of_month,
LAG(LAST_DAY(txn_month)) OVER (PARTITION BY customer_id ORDER BY txn_month) AS previous_end_of_month,
running_sum AS closing_balance
FROM BALANCES 
WHERE rn = 1
ORDER BY end_of_month
)
, PERCENT_INCREASE AS (
SELECT 
CB1.customer_id,
CB1.end_of_month,
CB1.closing_balance,
CB2.closing_balance AS next_month_closing_balance,
(CB2.closing_balance / CB1.closing_balance) - 1 AS percentage_increase,
CASE WHEN CB2.closing_balance > CB1.closing_balance AND (CB2.closing_balance / CB1.closing_balance) - 1 > 0.05 THEN 1 ELSE 0 END AS percentage_increase_flag
FROM CLOSING_BALANCES AS CB1
INNER JOIN CLOSING_BALANCES AS CB2 ON CB1.end_of_month = CB2.previous_end_of_month 
AND CB1.customer_id = CB2.customer_id
WHERE CB1.closing_balance <> 0
)
SELECT 
SUM(percentage_increase_flag) / COUNT(*) AS percentage_of_customers_increasing_balance
FROM PERCENT_INCREASE;