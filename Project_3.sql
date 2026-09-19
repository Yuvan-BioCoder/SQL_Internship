-- The 5th project listed in the internship chosen as my 3rd project

-- *** Revenue & profit by category *** --
-- 1. Join order_items -> orders (filter Completed) -> products, to connect revenue and cost data
-- 2. Sum line_total (revenue) and quantity * unit_cost (cost) per category
-- 3. Derive profit and profit margin %, grouped by category

SELECT
    products_e_commerce.category,
    SUM(order_items_e_commerce.line_total) AS total_revenue,
    SUM(order_items_e_commerce.quantity * products_e_commerce.unit_cost) AS total_cost,
    SUM(order_items_e_commerce.line_total) - SUM(order_items_e_commerce.quantity * products_e_commerce.unit_cost) AS total_profit,
    ROUND(
        (SUM(order_items_e_commerce.line_total) - SUM(order_items_e_commerce.quantity * products_e_commerce.unit_cost))
        / SUM(order_items_e_commerce.line_total) * 100, 2
    ) AS profit_margin_percent
FROM
    order_items_e_commerce
INNER JOIN
    orders_e_commerce ON order_items_e_commerce.order_id = orders_e_commerce.order_id
INNER JOIN
    products_e_commerce ON order_items_e_commerce.product_id = products_e_commerce.product_id
WHERE
    orders_e_commerce.status = 'Completed'
GROUP BY
    products_e_commerce.category
ORDER BY
    total_profit DESC;

-- *** Cancellation & return rate *** --
-- 1. Count total orders, and separately count how many fall into 'Cancelled' and 'Returned' using FILTER
-- 2. Divide each filtered count by the total count to get a percentage
-- 3. Run once overall, then again grouped by month to see if the rate is trending up/down

-- Overall
SELECT
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE status = 'Cancelled') AS cancelled_orders,
    COUNT(*) FILTER (WHERE status = 'Returned') AS returned_orders,
    ROUND(COUNT(*) FILTER (WHERE status = 'Cancelled') * 100.0 / COUNT(*), 2) AS cancellation_rate_percent,
    ROUND(COUNT(*) FILTER (WHERE status = 'Returned') * 100.0 / COUNT(*), 2) AS return_rate_percent
FROM
    orders_e_commerce;

-- By month
SELECT
    DATE_TRUNC('month', order_date) AS month,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE status = 'Cancelled') AS cancelled_orders,
    ROUND(COUNT(*) FILTER (WHERE status = 'Cancelled') * 100.0 / COUNT(*), 2) AS cancellation_rate_percent
FROM
    orders_e_commerce
GROUP BY
    DATE_TRUNC('month', order_date)
ORDER BY
    month;

-- *** Average Order Value (AOV)*** --
-- 1. Filter to only Completed orders, since cancelled/pending shouldn't count toward real order value
-- 2. Apply AVG() on order_total using FILTER so it's computed in the same pass as other stats if needed later
-- 3. Run once overall, then again grouped by month to track AOV trend

-- Overall
SELECT
    ROUND(AVG(order_total) FILTER (WHERE status = 'Completed'), 2) AS avg_order_value
FROM
    orders_e_commerce;

-- By month
SELECT
    DATE_TRUNC('month', order_date) AS month,
    ROUND(AVG(order_total) FILTER (WHERE status = 'Completed'), 2) AS avg_order_value
FROM
    orders_e_commerce
GROUP BY
    DATE_TRUNC('month', order_date)
ORDER BY
    month;

-- *** Peak sales time *** --
-- 1. Extract just the hour (0-23) from each order's full timestamp
-- 2. Group all orders by that hour, regardless of which day/month they happened on
-- 3. Count orders and sum revenue per hour, sorted to show the busiest hours first

SELECT
    EXTRACT(HOUR FROM order_date) AS order_hour,
    COUNT(*) AS total_orders,
    SUM(order_total) AS total_revenue
FROM
    orders_e_commerce
WHERE
    status = 'Completed'
GROUP BY
    EXTRACT(HOUR FROM order_date)
ORDER BY
    total_orders DESC;

-- *** Conversion rate *** --
-- 1. Count all sessions, and separately count only the ones where converted = TRUE
-- 2. Divide converted count by total count to get the overall conversion rate %
-- 3. Repeat the same logic grouped by device_type, then again by traffic_source

-- Overall
SELECT
    COUNT(*) AS total_sessions,
    COUNT(*) FILTER (WHERE converted = TRUE) AS converted_sessions,
    ROUND(COUNT(*) FILTER (WHERE converted = TRUE) * 100.0 / COUNT(*), 2) AS conversion_rate_percent
FROM
    website_sessions_e_commerce;

-- By device type
SELECT
    device_type,
    COUNT(*) AS total_sessions,
    COUNT(*) FILTER (WHERE converted = TRUE) AS converted_sessions,
    ROUND(COUNT(*) FILTER (WHERE converted = TRUE) * 100.0 / COUNT(*), 2) AS conversion_rate_percent
FROM
    website_sessions_e_commerce
GROUP BY
    device_type
ORDER BY
    conversion_rate_percent DESC;

-- By traffic source
SELECT
    traffic_source,
    COUNT(*) AS total_sessions,
    COUNT(*) FILTER (WHERE converted = TRUE) AS converted_sessions,
    ROUND(COUNT(*) FILTER (WHERE converted = TRUE) * 100.0 / COUNT(*), 2) AS conversion_rate_percent
FROM
    website_sessions_e_commerce
GROUP BY
    traffic_source
ORDER BY
    conversion_rate_percent DESC;

-- *** Delivery performance *** --
-- 1. For delivered orders, subtract expected_delivery_date from actual delivery_date to get a lateness gap
-- 2. Count how many deliveries were Delayed or Failed per courier
-- 3. Divide those counts by each courier's total deliveries to get % Delayed and % Failed

-- Late deliveries (delivered, but later than expected)
SELECT
    delivery_id,
    order_id,
    courier,
    expected_delivery_date,
    delivery_date,
    delivery_date - expected_delivery_date AS days_late
FROM
    deliveries_e_commerce
WHERE
    delivery_status = 'Delivered'
    AND delivery_date > expected_delivery_date
ORDER BY
    days_late DESC;

-- % Delayed and % Failed, by courier
SELECT
    courier,
    COUNT(*) AS total_deliveries,
    COUNT(*) FILTER (WHERE delivery_status = 'Delayed') AS delayed_count,
    COUNT(*) FILTER (WHERE delivery_status = 'Failed') AS failed_count,
    ROUND(COUNT(*) FILTER (WHERE delivery_status = 'Delayed') * 100.0 / COUNT(*), 2) AS delayed_percent,
    ROUND(COUNT(*) FILTER (WHERE delivery_status = 'Failed') * 100.0 / COUNT(*), 2) AS failed_percent
FROM
    deliveries_e_commerce
GROUP BY
    courier
ORDER BY
    delayed_percent DESC;

-- *** Top products & categories by revenue *** --
-- 1. Join order_items -> orders (filter Completed) -> products, connecting each sold line item to its product
-- 2. Sum quantity and line_total per product, so each product has one total-units and one total-revenue figure
-- 3. Sort by revenue descending and limit to the top 10

SELECT
    products_e_commerce.product_name,
    products_e_commerce.category,
    SUM(order_items_e_commerce.quantity) AS total_units_sold,
    SUM(order_items_e_commerce.line_total) AS total_revenue
FROM
    order_items_e_commerce
INNER JOIN
    orders_e_commerce ON order_items_e_commerce.order_id = orders_e_commerce.order_id
INNER JOIN
    products_e_commerce ON order_items_e_commerce.product_id = products_e_commerce.product_id
WHERE
    orders_e_commerce.status = 'Completed'
GROUP BY
    products_e_commerce.product_name, products_e_commerce.category
ORDER BY
    total_revenue DESC
LIMIT 10;

-- *** Combined KPI dashboard query *** --
-- 1. Build 4 separate CTEs, one per KPI (AOV, cancellation rate, conversion rate, on-time delivery rate) —
--    each computed independently since they come from different tables/filters
-- 2. Each CTE collapses down to exactly ONE row, containing just that single KPI's value
-- 3. CROSS JOIN all 4 one-row CTEs together into a single summary row

WITH aov AS (
    SELECT ROUND(AVG(order_total) FILTER (WHERE status = 'Completed'), 2) AS avg_order_value
    FROM orders_e_commerce
),
cancellation AS (
    SELECT ROUND(COUNT(*) FILTER (WHERE status = 'Cancelled') * 100.0 / COUNT(*), 2) AS cancellation_rate_percent
    FROM orders_e_commerce
),
conversion AS (
    SELECT ROUND(COUNT(*) FILTER (WHERE converted = TRUE) * 100.0 / COUNT(*), 2) AS conversion_rate_percent
    FROM website_sessions_e_commerce
),
delivery AS (
    SELECT ROUND(COUNT(*) FILTER (WHERE delivery_status = 'Delivered' AND delivery_date <= expected_delivery_date) * 100.0 / COUNT(*), 2) AS on_time_delivery_rate_percent
    FROM deliveries_e_commerce
)
SELECT
    aov.avg_order_value,
    cancellation.cancellation_rate_percent,
    conversion.conversion_rate_percent,
    delivery.on_time_delivery_rate_percent
FROM
    aov, cancellation, conversion, delivery;