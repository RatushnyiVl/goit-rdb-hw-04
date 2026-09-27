-- дедуплікований customer dimension
DROP TABLE IF EXISTS customer_segments CASCADE;
DROP TABLE IF EXISTS olist_customer_dim CASCADE;

CREATE TABLE olist_customer_dim (
    customer_unique_id TEXT PRIMARY KEY,
    latest_customer_id TEXT REFERENCES olist_customers(customer_id),
    customer_state     CHAR(2),
    customer_city      TEXT
);

INSERT INTO olist_customer_dim (
    customer_unique_id,
    latest_customer_id,
    customer_state,
    customer_city
)
SELECT DISTINCT ON (c.customer_unique_id)
    c.customer_unique_id,
    c.customer_id AS latest_customer_id,
    c.customer_state,
    c.customer_city
FROM olist_customers AS c
LEFT JOIN olist_orders AS o
    ON o.customer_id = c.customer_id
ORDER BY
    c.customer_unique_id,
    o.order_purchase_timestamp DESC NULLS LAST,
    c.customer_id;


-- customer_segments з production-подібним DDL
CREATE TABLE customer_segments (
    segment_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    customer_unique_id  TEXT NOT NULL,
    segment_name        TEXT NOT NULL
        CHECK (segment_name IN ('VIP', 'regular', 'new', 'inactive')),

    rfm_score           SMALLINT NOT NULL
        CHECK (rfm_score BETWEEN 1 AND 5),

    recency_days        INTEGER
        CHECK (recency_days IS NULL OR recency_days >= 0),

    monetary_value      NUMERIC(12, 2) NOT NULL DEFAULT 0
        CHECK (monetary_value >= 0),

    n_orders            INTEGER NOT NULL DEFAULT 0
        CHECK (n_orders >= 0),

    assigned_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (customer_unique_id)
);

ALTER TABLE customer_segments
    ADD CONSTRAINT fk_customer_segments_customer_unique
    FOREIGN KEY (customer_unique_id)
    REFERENCES olist_customer_dim(customer_unique_id)
    ON DELETE CASCADE;


-- Наповніть таблицю через INSERT ... SELECT ... ON CONFLICT
WITH reference_date AS (
    SELECT (MAX(order_purchase_timestamp)::DATE + 1) AS as_of_date
    FROM olist_orders
),
order_totals AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_purchase_timestamp::DATE AS order_date,
        COALESCE(SUM(oi.price + oi.freight_value), 0)::NUMERIC(12, 2) AS order_total
    FROM olist_orders AS o
    LEFT JOIN olist_order_items AS oi
        ON oi.order_id = o.order_id
    GROUP BY
        o.order_id,
        o.customer_id,
        o.order_purchase_timestamp
),
customer_stats AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT ot.order_id) AS n_orders,
        COALESCE(SUM(ot.order_total), 0)::NUMERIC(12, 2) AS monetary_value,
        MAX(ot.order_date) AS last_order_date
    FROM olist_customer_dim AS cd
    JOIN olist_customers AS c
        ON c.customer_unique_id = cd.customer_unique_id
    LEFT JOIN order_totals AS ot
        ON ot.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
),
segmented AS (
    SELECT
        cs.customer_unique_id,
        cs.n_orders,
        cs.monetary_value,
        CASE
            WHEN cs.last_order_date IS NULL THEN NULL
            ELSE (rd.as_of_date - cs.last_order_date)::INTEGER
        END AS recency_days,
        CASE
            WHEN cs.monetary_value >= 1000 THEN 'VIP'
            WHEN cs.last_order_date IS NOT NULL
                 AND (rd.as_of_date - cs.last_order_date)::INTEGER <= 90
                 AND cs.n_orders = 1 THEN 'new'
            WHEN cs.n_orders >= 2 OR cs.monetary_value >= 100 THEN 'regular'
            ELSE 'inactive'
        END AS segment_name,
        CASE
            WHEN cs.monetary_value >= 1000 THEN 5
            WHEN cs.monetary_value >= 500  THEN 4
            WHEN cs.n_orders >= 2          THEN 3
            WHEN cs.n_orders = 1           THEN 2
            ELSE 1
        END::SMALLINT AS rfm_score
    FROM customer_stats AS cs
    CROSS JOIN reference_date AS rd
)
INSERT INTO customer_segments (
    customer_unique_id,
    segment_name,
    rfm_score,
    recency_days,
    monetary_value,
    n_orders
)
SELECT
    customer_unique_id,
    segment_name,
    rfm_score,
    recency_days,
    monetary_value,
    n_orders
FROM segmented
ON CONFLICT (customer_unique_id) DO UPDATE
SET segment_name   = EXCLUDED.segment_name,
    rfm_score      = EXCLUDED.rfm_score,
    recency_days   = EXCLUDED.recency_days,
    monetary_value = EXCLUDED.monetary_value,
    n_orders       = EXCLUDED.n_orders,
    assigned_at    = NOW()
RETURNING
    customer_unique_id,
    segment_name,
    rfm_score,
    recency_days,
    monetary_value,
    n_orders;
