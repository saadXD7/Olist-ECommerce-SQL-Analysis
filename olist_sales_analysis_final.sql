
/* 
===============================================================================
PROJECT: Brazilian E-Commerce Sales Analysis (Olist)
AUTHOR: [saad deshmukh]
GOAL: Identify growth trends, high-value customers, and logistics bottlenecks.
===============================================================================
*/

-- 1. DATA CLEANING: Creating a View for valid, delivered orders
-- This ensures canceled or unavailable orders don't inflate our revenue stats.
CREATE OR REPLACE VIEW clean_orders AS
SELECT * 
FROM orders 
WHERE order_status = 'delivered' 
AND order_delivered_customer_date IS NOT NULL;


-- 2. KPI METRICS: Total Revenue, Orders, and Average Order Value (AOV)
SELECT 
    COUNT(DISTINCT co.order_id) AS total_orders,
    ROUND(SUM(oi.price)::numeric, 2) AS total_revenue,
    ROUND(AVG(oi.price)::numeric, 2) AS average_order_value
FROM clean_orders co
JOIN order_items oi ON co.order_id = oi.order_id;


-- 3. TIME-SERIES ANALYSIS: Monthly Revenue & Growth Trends
WITH monthly_revenue AS (
    SELECT 
        DATE_TRUNC('month', order_purchase_timestamp) AS sale_month,
        SUM(price) AS revenue
    FROM clean_orders co
    JOIN order_items oi ON co.order_id = oi.order_id
    GROUP BY 1
)
SELECT 
    sale_month,
    ROUND(revenue::numeric, 2) as current_month_revenue,
    ROUND(LAG(revenue) OVER (ORDER BY sale_month)::numeric, 2) AS previous_month_revenue,
    ROUND(((revenue - LAG(revenue) OVER (ORDER BY sale_month)) / LAG(revenue) OVER (ORDER BY sale_month)) * 100, 2) || '%' AS mom_growth
FROM monthly_revenue
ORDER BY sale_month;


-- 4. CUSTOMER SEGMENTATION: RFM Analysis (Recency, Frequency, Monetary)
WITH rfm_metrics AS (
    SELECT 
        customer_unique_id,
        MAX(order_purchase_timestamp) AS last_purchase,
        COUNT(co.order_id) AS frequency,
        SUM(oi.price) AS monetary,
        (SELECT MAX(order_purchase_timestamp) FROM clean_orders) - MAX(order_purchase_timestamp) AS recency
    FROM clean_orders co
    JOIN order_items oi ON co.order_id = oi.order_id
    JOIN customers c ON co.customer_id = c.customer_id
    GROUP BY customer_unique_id
),
rfm_scores AS (
    SELECT 
        customer_unique_id,
        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_metrics
)
SELECT 
    customer_unique_id,
    r_score, f_score, m_score,
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score <= 2 THEN 'At Risk / Churn'
        WHEN f_score >= 3 THEN 'Loyal Customers'
        ELSE 'Typical'
    END AS segment
FROM rfm_scores;


-- 5. REGIONAL PERFORMANCE: Top 5 States by Revenue
SELECT 
    c.customer_state, 
    COUNT(DISTINCT co.order_id) AS total_orders,
    ROUND(SUM(oi.price)::numeric, 2) AS total_revenue
FROM clean_orders co
JOIN order_items oi ON co.order_id = oi.order_id
JOIN customers c ON co.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY total_revenue DESC
LIMIT 5;


-- 6. MARKET BASKET ANALYSIS: Product Affinity (Pairs)
SELECT 
    a.product_id AS product_a, 
    b.product_id AS product_b, 
    COUNT(*) AS times_bought_together
FROM order_items a
JOIN order_items b ON a.order_id = b.order_id AND a.product_id < b.product_id
GROUP BY product_a, product_b
ORDER BY times_bought_together DESC
LIMIT 10;
