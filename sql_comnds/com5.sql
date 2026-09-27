ALTER TABLE olist_orders
    ADD COLUMN IF NOT EXISTS is_late BOOLEAN NOT NULL DEFAULT FALSE;

WITH delivery_flags AS (
    SELECT
        order_id,
        (
            order_delivered_customer_date IS NOT NULL
            AND order_estimated_delivery_date IS NOT NULL
            AND order_delivered_customer_date::DATE > order_estimated_delivery_date::DATE
        ) AS is_late_calc
    FROM olist_orders
)
UPDATE olist_orders AS o
SET is_late = f.is_late_calc
FROM delivery_flags AS f
WHERE f.order_id = o.order_id
RETURNING o.order_id, o.customer_id, o.is_late;
