DROP TABLE IF EXISTS seller_alerts CASCADE;


CREATE TABLE seller_alerts (
    alert_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id  TEXT NOT NULL REFERENCES olist_sellers(seller_id),
    alert_type TEXT NOT NULL CHECK (alert_type IN ('late_delivery', 'low_rating', 'data_quality')),
    severity   SMALLINT NOT NULL CHECK (severity BETWEEN 1 AND 5),
    details    TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


WITH seller_orders AS (
    SELECT DISTINCT
        oi.seller_id,
        oi.order_id
    FROM olist_order_items AS oi
),
late_sellers AS (
    SELECT
        so.seller_id,
        COUNT(DISTINCT o.order_id) AS late_orders
    FROM seller_orders AS so
    JOIN olist_orders AS o
        ON o.order_id = so.order_id
    WHERE o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
      AND o.order_delivered_customer_date::DATE > o.order_estimated_delivery_date::DATE
    GROUP BY so.seller_id
    ORDER BY late_orders DESC, so.seller_id
    LIMIT 1
)
INSERT INTO seller_alerts (seller_id, alert_type, severity, details)
SELECT
    seller_id,
    'late_delivery',
    4,
    'Seller has ' || late_orders || ' late delivered orders in the loaded dataset'
FROM late_sellers
RETURNING alert_id, seller_id, alert_type, severity, created_at;
