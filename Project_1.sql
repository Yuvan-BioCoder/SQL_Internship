-- Insights: Analysis should answer business questions such as monthly revenue 
-- trends, top-selling products, repeat customers, and profit margins. 

-- *** Monthly revenue trends *** --

-- 1. CREATE CTE to extract completed orders for each month
-- 2. Analyse the revenue trends comparing it to the previous months
-- 3. Convert these trend results into percentage and make it a seperate column

WITH monthly_totals AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,-- DATE_TRUNC rounds each order's exact date down to the 1st of its month...
        SUM(order_total) AS monthly_revenue
    FROM
        orders
    WHERE
        status = 'Completed'
    GROUP BY
        DATE_TRUNC('month', order_date)
)
SELECT
    month,
    monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY month) AS previous_month_revenue,-- For each row, fetches the monthly_revenue value from 
    -- the previous row — using OVER (ORDER BY month...
    ROUND
    (
        (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY month))-- The numerator — current month's revenue minus last month's revenue...
        / LAG(monthly_revenue) OVER (ORDER BY month) * 100, 2-- Divides by last month's revenue — converts the change into a proportion 
        -- and to a percentage...
    ) AS growth_percent
FROM
    monthly_totals
ORDER BY
    month;

-- *** Top - selling products *** --

-- 1. Get the products and their categories
-- 2. Also return the units sold and the total revenue
-- 3. Only get COMPLETED products, so JOIN tables to check for the status
-- 4. GROUP BY the products and ORDER BY total revenue to get the best sellers

SELECT
    products.product_name,
    products.category,
    SUM(order_items.quantity) AS total_units_sold,
    SUM(order_items.line_total) AS total_revenue
FROM
    order_items
INNER JOIN
    orders ON order_items.order_id = orders.order_id-- Needed to check status = 'Completed' —> this column lives in orders, not order_items...
INNER JOIN
    products ON order_items.product_id = products.product_id-- Needed to get product_name, category —> order_items only stores product_id...
WHERE
    orders.status = 'Completed'
GROUP BY
    products.product_name, products.category
ORDER BY
    total_revenue DESC;

-- *** Total revenue per repeat customer *** --

-- 1. Get completed orders by each customer
-- 2. INNER JOIN to combine the tables
-- 3. Returns the top spending repeat customers

SELECT
    customers.customer_id,
    customers.first_name,
    customers.last_name,
    COUNT(orders.order_id) AS total_orders,
    SUM(orders.order_total) AS total_spent
FROM
    customers
INNER JOIN
    orders 
ON 
    customers.customer_id = orders.customer_id
WHERE
    orders.status = 'Completed'
GROUP BY
    customers.customer_id, customers.first_name, customers.last_name
HAVING
    COUNT(orders.order_id) > 1
ORDER BY
    total_spent DESC;

-- *** First-time vs. repeat customers monthly trend *** --

-- 1. CREATE CTE ordering the months
-- 2. RETURN the new customers count and their conversion to repeat customers

WITH customer_order_counts AS 
(
    SELECT
        customers.customer_id,
        DATE_TRUNC('month', MIN(orders.order_date)) AS month,-- DATE_TRUNC rounds each order's exact date down to the 1st 
        -- of its month, i.e we order the data per month to analyse the trend...
        COUNT(orders.order_id) AS total_orders
    FROM
        customers
    INNER JOIN
        orders 
    ON
        customers.customer_id = orders.customer_id
    WHERE
        orders.status = 'Completed'
    GROUP BY
        customers.customer_id
)
SELECT
    month,
    COUNT(*) AS new_customers,
    COUNT(*) FILTER (WHERE total_orders > 1) AS became_repeat_customers-- FILTER(WHERE condition) is a modifier you attach to an 
    -- aggregate function that tells it to only consider rows matching that condition
FROM
    customer_order_counts
GROUP BY
    month
ORDER BY
    month;

-- *** Overall and product - wise profit margin *** --

-- 1. Join the tables to connect revenue and cost data
-- 2. Calculate revenue, cost, profit, and margin — grouped per product
-- 3. Add a grand-total row on top, using ROLLUP

SELECT
    COALESCE(products.product_name, 'ALL PRODUCTS') AS product_name,-- Since ROLLUP produces NULL for the grouping columns on that summary row,
    --  COALESCE replaces that NULL with a readable label — so the summary row shows 'ALL PRODUCTS' instead of a NULL value
    SUM(order_items.line_total) AS total_revenue,
    SUM(order_items.quantity * products.unit_cost) AS total_cost,
    SUM(order_items.line_total) - SUM(order_items.quantity * products.unit_cost) AS total_profit,
    ROUND(
        (SUM(order_items.line_total) - SUM(order_items.quantity * products.unit_cost)) 
        / SUM(order_items.line_total) * 100, 2
    ) AS profit_margin_percent
FROM
    order_items
INNER JOIN
    orders ON order_items.order_id = orders.order_id
INNER JOIN
    products ON order_items.product_id = products.product_id
WHERE
    orders.status = 'Completed'
GROUP BY
    ROLLUP(products.product_name)-- Normally, GROUP BY products.product_name, products.category gives you one row per product.
    -- ROLLUP adds extra subtotal rows on top of that — specifically, one additional row where the grouping columns collapse to NULL
ORDER BY
    total_revenue DESC NULLS FIRST;