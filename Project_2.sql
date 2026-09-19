-- The 4th project listed in the internship chosen as my 2nd project

-- *** High-value transaction flagging *** --

-- 1. Flag transactions >= 15000 as 'High risk'
-- 2. RETURN transaction details ordering large to small

SELECT
    transaction_id,
    account_id,
    transaction_date,
    transaction_type,
    amount,
    CASE
        WHEN amount >= 15000 THEN 'High Risk'
        WHEN amount >= 5000 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS amount_risk_level
FROM
    transactions
WHERE
    amount >= 5000
ORDER BY
    amount DESC;

-- *** Transactions outside normal hours *** --

-- 1. Monitor transactions happening outside normal hours, i.e from 11 - 6 as it may be a potential fraud risk
-- 2. RETURN transaction details

SELECT
    transaction_id,
    account_id,
    transaction_date,
    transaction_type,
    amount,
    EXTRACT(HOUR FROM transaction_date) AS transaction_hour
FROM
    transactions
WHERE
    EXTRACT(HOUR FROM transaction_date) < 6
    OR EXTRACT(HOUR FROM transaction_date) >= 23
ORDER BY
    transaction_date;

-- *** Time gap between consecutive large transactions (per account) *** --

-- 1. Monitor large transactions happening within a set range of days 
-- 2. RETURN transaction details

SELECT
    transaction_id,
    account_id,
    transaction_date,
    amount,
    LAG(transaction_date) OVER (PARTITION BY account_id ORDER BY transaction_date) AS previous_transaction_date,
    transaction_date - LAG(transaction_date) OVER (PARTITION BY account_id ORDER BY transaction_date) AS time_gap
FROM
    transactions
ORDER BY
    account_id, transaction_date;

-- *** Loan default analysis *** --

-- 1. Monitor the types of loan taken along with their details
-- 2. RETURN details

SELECT
    loan_type,
    COUNT(*) AS total_loans,
    COUNT(*) FILTER (WHERE status = 'Defaulted') AS defaulted_loans,
    ROUND(
        COUNT(*) FILTER (WHERE status = 'Defaulted') * 100.0 / COUNT(*), 2
    ) AS default_rate_percent
FROM
    loans
GROUP BY
    loan_type
ORDER BY
    default_rate_percent DESC;

-- *** Loan amount vs. account balance *** --

-- 1. Checks the balance in a loan account
-- 2. RETURN loan_balance_ratio

SELECT
    loans.loan_id,
    loans.customer_id,
    loans.loan_amount,
    accounts.account_id,
    accounts.balance,
    ROUND(loans.loan_amount / accounts.balance, 2) AS loan_to_balance_ratio
FROM
    loans
INNER JOIN
    accounts ON loans.customer_id = accounts.customer_id
WHERE
    loans.status IN ('Active', 'Late Payment')
ORDER BY
    loan_to_balance_ratio DESC;

-- *** Customers with multiple loans *** --

-- 1. SELECT customers with more than one loan 
-- 2. RETURN details of these customers

SELECT
    customers_fact.customer_id,
    customers_fact.first_name,
    customers_fact.last_name,
    COUNT(loans.loan_id) AS total_loans,
    SUM(loans.loan_amount) AS total_loan_exposure
FROM
    customers_fact
INNER JOIN
    loans ON customers_fact.customer_id = loans.customer_id
GROUP BY
    customers_fact.customer_id, customers_fact.first_name, customers_fact.last_name
HAVING
    COUNT(loans.loan_id) > 1
ORDER BY
    total_loan_exposure DESC;

-- *** Customers transacting across multiple accounts rapidly *** --

-- 1. Monitor accounts which rapidly transfer mid - range amounts 
-- 2. RETURN details of such transactions

WITH multi_account_customers AS (
    SELECT
        customer_id,
        COUNT(account_id) AS total_accounts
    FROM
        accounts
    GROUP BY
        customer_id
    HAVING
        COUNT(account_id) > 1
),
customer_transactions AS (
    SELECT
        accounts.customer_id,
        transactions.transaction_id,
        transactions.account_id,
        transactions.transaction_date,
        transactions.amount,
        LAG(transactions.transaction_date) OVER (PARTITION BY accounts.customer_id ORDER BY transactions.transaction_date) AS prev_txn_date,
        LAG(transactions.account_id) OVER (PARTITION BY accounts.customer_id ORDER BY transactions.transaction_date) AS prev_account_id
    FROM
        transactions
    INNER JOIN
        accounts ON transactions.account_id = accounts.account_id
    WHERE
        accounts.customer_id IN (SELECT customer_id FROM multi_account_customers)
)
SELECT
    customer_id,
    transaction_id,
    account_id,
    prev_account_id,
    transaction_date,
    prev_txn_date,
    transaction_date - prev_txn_date AS time_gap
FROM
    customer_transactions
WHERE
    account_id <> prev_account_id
    AND transaction_date - prev_txn_date < INTERVAL '10 minutes'
ORDER BY
    customer_id, transaction_date;

-- *** Combined risk-level categorization — final suspicious transaction report *** --

-- 1. CREATE CTE that pre-computes txn_hour and time_gap once, so they don't need to be repeated multiple times inside the CASE statements 
-- 2. The outer CASE combines multiple signals (amount, time-of-day, velocity) into one unified risk_level
-- 3. A second CASE gives a human-readable flag_reason, so whoever reads the report understands why each transaction was flagged
-- 4. RETURN report with these details

WITH txn_with_gap AS (
    SELECT
        transaction_id,
        account_id,
        transaction_date,
        transaction_type,
        amount,
        EXTRACT(HOUR FROM transaction_date) AS txn_hour,
        transaction_date - LAG(transaction_date) OVER (PARTITION BY account_id ORDER BY transaction_date) AS time_gap
    FROM
        transactions
)
SELECT
    transaction_id,
    account_id,
    transaction_date,
    transaction_type,
    amount,
    CASE
        WHEN amount >= 15000 THEN 'High'
        WHEN amount >= 5000 AND (txn_hour < 6 OR txn_hour >= 23) THEN 'High'
        WHEN amount >= 5000 THEN 'Medium'
        WHEN time_gap < INTERVAL '5 minutes' AND amount >= 500 THEN 'Medium'
        WHEN txn_hour < 6 OR txn_hour >= 23 THEN 'Low'
        ELSE 'Normal'
    END AS risk_level,
    CASE
        WHEN amount >= 15000 THEN 'High-value transaction'
        WHEN time_gap < INTERVAL '5 minutes' AND amount >= 500 THEN 'Rapid consecutive transaction'
        WHEN txn_hour < 6 OR txn_hour >= 23 THEN 'Off-hours activity'
        ELSE 'No flags'
    END AS flag_reason
FROM
    txn_with_gap
WHERE
    amount >= 15000
    OR (txn_hour < 6 OR txn_hour >= 23)
    OR (time_gap < INTERVAL '5 minutes' AND amount >= 500)
ORDER BY
    risk_level, transaction_date;