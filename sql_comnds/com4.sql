DROP TABLE IF EXISTS seller_score CASCADE;

CREATE TABLE seller_score (
    seller_id   TEXT PRIMARY KEY REFERENCES olist_sellers(seller_id),
    avg_rating  NUMERIC(3, 2),
    n_reviews   INTEGER NOT NULL DEFAULT 0 CHECK (n_reviews >= 0),
    tier        TEXT CHECK (tier IN ('gold', 'silver', 'bronze')),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

WITH seller_orders AS (
    SELECT DISTINCT
        oi.seller_id,
        oi.order_id
    FROM olist_order_items AS oi
),
review_per_order AS (
    SELECT
        rv.order_id,
        AVG(rv.review_score)::NUMERIC(3, 2) AS order_review_score
    FROM olist_order_reviews AS rv
    WHERE rv.review_score IS NOT NULL
    GROUP BY rv.order_id
),
seller_rating AS (
    SELECT
        so.seller_id,
        AVG(rpo.order_review_score)::NUMERIC(3, 2) AS avg_rating,
        COUNT(rpo.order_id) AS n_reviews
    FROM seller_orders AS so
    LEFT JOIN review_per_order AS rpo
        ON rpo.order_id = so.order_id
    GROUP BY so.seller_id
)
INSERT INTO seller_score (seller_id, avg_rating, n_reviews, tier)
SELECT
    seller_id,
    avg_rating,
    n_reviews,
    CASE
        WHEN avg_rating IS NULL THEN NULL
        WHEN avg_rating >= 4.5 THEN 'gold'
        WHEN avg_rating >= 3.5 THEN 'silver'
        ELSE 'bronze'
    END AS tier
FROM seller_rating
ON CONFLICT (seller_id) DO UPDATE
SET avg_rating = EXCLUDED.avg_rating,
    n_reviews  = EXCLUDED.n_reviews,
    tier       = EXCLUDED.tier,
    updated_at = NOW()
RETURNING seller_id, avg_rating, n_reviews, tier, updated_at;
