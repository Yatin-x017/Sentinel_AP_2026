-- =====================================================================
-- CP5: Triggers, Stored Procedures, and Materialized Views
-- DBMS project: 18. OLX Buy & Sell  |  Team T0058 (Sentinel)
-- Contributors: Dhaval Sethi, Puneet Goyal, Yatin
-- Target: PostgreSQL 14+
-- =====================================================================

-- =====================================================================
-- 1. MATERIALIZED VIEWS (Solving CP4 Analytical Bottlenecks)
-- Addresses queries R09, R25, and high-cost whole-table aggregations
-- documented in 05_query_timings.md.
-- =====================================================================

-- [MV01] Top favourited active listings (Replaces slow R09 148ms aggregate)
DROP MATERIALIZED VIEW IF EXISTS mv_top_favourited_listings;
CREATE MATERIALIZED VIEW mv_top_favourited_listings AS
SELECT 
    l.listing_id,
    l.title,
    l.price,
    l.city_id,
    l.category_id,
    COUNT(f.user_id) AS favourite_count,
    l.created_at
FROM listings l
JOIN favorites f ON f.listing_id = l.listing_id
WHERE l.status = 'active'
GROUP BY l.listing_id, l.title, l.price, l.city_id, l.category_id, l.created_at
ORDER BY favourite_count DESC, l.listing_id;

-- Unique index required for REFRESH MATERIALIZED VIEW CONCURRENTLY
CREATE UNIQUE INDEX idx_mv_top_fav_listing ON mv_top_favourited_listings (listing_id);
CREATE INDEX idx_mv_top_fav_count ON mv_top_favourited_listings (favourite_count DESC);


-- [MV02] Seller Performance & First-Reply Analytics (Replaces R05, R08, R25 230ms aggregate)
DROP MATERIALIZED VIEW IF EXISTS mv_seller_performance;
CREATE MATERIALIZED VIEW mv_seller_performance AS
WITH first_replies AS (
    SELECT 
        l.seller_id,
        AVG(m_seller.sent_at - m_buyer.sent_at) AS avg_reply_interval
    FROM conversations c
    JOIN listings l ON l.listing_id = c.listing_id
    CROSS JOIN LATERAL (
        SELECT MIN(sent_at) AS sent_at 
        FROM messages 
        WHERE conversation_id = c.conversation_id AND sender_id = c.buyer_id
    ) m_buyer
    CROSS JOIN LATERAL (
        SELECT MIN(sent_at) AS sent_at 
        FROM messages 
        WHERE conversation_id = c.conversation_id AND sender_id = l.seller_id
    ) m_seller
    WHERE m_seller.sent_at > m_buyer.sent_at
    GROUP BY l.seller_id
),
seller_reviews AS (
    SELECT 
        reviewee_id AS user_id,
        ROUND(AVG(rating), 2) AS avg_rating,
        COUNT(*) AS total_reviews
    FROM reviews
    GROUP BY reviewee_id
),
seller_sales AS (
    SELECT 
        seller_id AS user_id,
        COUNT(*) AS completed_sales,
        SUM(final_price) AS total_revenue
    FROM transactions
    GROUP BY seller_id
)
SELECT 
    u.user_id,
    u.full_name,
    COALESCE(ss.completed_sales, 0) AS completed_sales,
    COALESCE(ss.total_revenue, 0.00) AS total_revenue,
    COALESCE(sr.avg_rating, 0.00) AS avg_rating,
    COALESCE(sr.total_reviews, 0) AS total_reviews,
    fr.avg_reply_interval
FROM users u
LEFT JOIN seller_sales ss ON ss.user_id = u.user_id
LEFT JOIN seller_reviews sr ON sr.user_id = u.user_id
LEFT JOIN first_replies fr ON fr.seller_id = u.user_id;

CREATE UNIQUE INDEX idx_mv_seller_perf_user ON mv_seller_performance (user_id);
CREATE INDEX idx_mv_seller_perf_sales ON mv_seller_performance (completed_sales DESC);


-- [MV03] Category Sell-Through Rates & Pricing Summary (Replaces R02, R06, R22)
DROP MATERIALIZED VIEW IF EXISTS mv_category_summary;
CREATE MATERIALIZED VIEW mv_category_summary AS
SELECT 
    c.category_id,
    c.name AS category_name,
    p.category_id AS parent_category_id,
    p.name AS parent_category_name,
    COUNT(l.listing_id) AS total_listings,
    COUNT(l.listing_id) FILTER (WHERE l.status = 'active') AS active_listings,
    COUNT(l.listing_id) FILTER (WHERE l.status = 'sold') AS sold_listings,
    ROUND(AVG(l.price) FILTER (WHERE l.status = 'active'), 2) AS avg_active_price,
    ROUND(100.0 * COUNT(l.listing_id) FILTER (WHERE l.status = 'sold') / NULLIF(COUNT(l.listing_id), 0), 1) AS sell_through_pct
FROM categories c
LEFT JOIN categories p ON p.category_id = c.parent_id
LEFT JOIN listings l ON l.category_id = c.category_id
GROUP BY c.category_id, c.name, p.category_id, p.name;

CREATE UNIQUE INDEX idx_mv_cat_summary_id ON mv_category_summary (category_id);


-- =====================================================================
-- 2. BUSINESS INTEGRITY TRIGGERS
-- Automating business rules and preventing invalid states
-- =====================================================================

-- [TR01] Prevent users from favouriting their own listings
CREATE OR REPLACE FUNCTION fn_prevent_self_favorite()
RETURNS TRIGGER AS $$
DECLARE
    v_seller_id INT;
BEGIN
    SELECT seller_id INTO v_seller_id FROM listings WHERE listing_id = NEW.listing_id;
    IF v_seller_id = NEW.user_id THEN
        RAISE EXCEPTION 'Constraint Violation: User % cannot favourite their own listing %', NEW.user_id, NEW.listing_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_self_favorite ON favorites;
CREATE TRIGGER trg_prevent_self_favorite
BEFORE INSERT ON favorites
FOR EACH ROW
EXECUTE FUNCTION fn_prevent_self_favorite();


-- [TR02] Prevent sellers from initiating chat with themselves
CREATE OR REPLACE FUNCTION fn_prevent_self_conversation()
RETURNS TRIGGER AS $$
DECLARE
    v_seller_id INT;
BEGIN
    SELECT seller_id INTO v_seller_id FROM listings WHERE listing_id = NEW.listing_id;
    IF v_seller_id = NEW.buyer_id THEN
        RAISE EXCEPTION 'Constraint Violation: Buyer and Seller cannot be the same user (%) for listing %', NEW.buyer_id, NEW.listing_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_self_conversation ON conversations;
CREATE TRIGGER trg_prevent_self_conversation
BEFORE INSERT ON conversations
FOR EACH ROW
EXECUTE FUNCTION fn_prevent_self_conversation();


-- [TR03] Auto-synchronize listing status on completed transaction
CREATE OR REPLACE FUNCTION fn_sync_listing_sold()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE listings
    SET status = 'sold',
        sold_at = NEW.completed_at
    WHERE listing_id = NEW.listing_id
      AND status <> 'sold';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_listing_sold ON transactions;
CREATE TRIGGER trg_sync_listing_sold
AFTER INSERT ON transactions
FOR EACH ROW
EXECUTE FUNCTION fn_sync_listing_sold();


-- [TR04] Enforce that reviewers must be actual participants of the completed transaction
CREATE OR REPLACE FUNCTION fn_validate_review_parties()
RETURNS TRIGGER AS $$
DECLARE
    v_buyer_id INT;
    v_seller_id INT;
BEGIN
    SELECT buyer_id, seller_id INTO v_buyer_id, v_seller_id 
    FROM transactions 
    WHERE transaction_id = NEW.transaction_id;

    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Transaction % does not exist', NEW.transaction_id;
    END IF;

    -- Reviewer must be either the buyer or seller
    IF NEW.reviewer_id NOT IN (v_buyer_id, v_seller_id) THEN
        RAISE EXCEPTION 'User % is not a participant in transaction %', NEW.reviewer_id, NEW.transaction_id;
    END IF;

    -- Reviewee must be the opposite party
    IF NEW.reviewer_id = v_buyer_id AND NEW.reviewee_id <> v_seller_id THEN
        RAISE EXCEPTION 'Buyer reviewee must be the seller (%) of transaction %', v_seller_id, NEW.transaction_id;
    END IF;

    IF NEW.reviewer_id = v_seller_id AND NEW.reviewee_id <> v_buyer_id THEN
        RAISE EXCEPTION 'Seller reviewee must be the buyer (%) of transaction %', v_buyer_id, NEW.transaction_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_review_parties ON reviews;
CREATE TRIGGER trg_validate_review_parties
BEFORE INSERT ON reviews
FOR EACH ROW
EXECUTE FUNCTION fn_validate_review_parties();


-- =====================================================================
-- 3. STORED PROCEDURES (Transactional Workflows)
-- =====================================================================

-- [SP01] Safely complete a listing sale with row-level concurrency lock (ACID)
CREATE OR REPLACE PROCEDURE sp_complete_sale(
    p_listing_id INT,
    p_buyer_id INT,
    p_final_price NUMERIC(12,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_seller_id INT;
    v_status VARCHAR(10);
BEGIN
    -- Acquire exclusive row lock to prevent race condition (two concurrent buyers)
    SELECT seller_id, status INTO v_seller_id, v_status
    FROM listings
    WHERE listing_id = p_listing_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Listing % not found', p_listing_id;
    END IF;

    IF v_status <> 'active' THEN
        RAISE EXCEPTION 'Cannot complete sale: Listing % is not active (current status: %)', p_listing_id, v_status;
    END IF;

    IF v_seller_id = p_buyer_id THEN
        RAISE EXCEPTION 'Seller % cannot purchase their own listing', v_seller_id;
    END IF;

    -- Insert completed transaction (triggers trg_sync_listing_sold automatically)
    INSERT INTO transactions (listing_id, buyer_id, seller_id, final_price, completed_at)
    VALUES (p_listing_id, p_buyer_id, v_seller_id, p_final_price, now());

    -- Reject any remaining pending offers for this listing
    UPDATE offers
    SET status = 'rejected'
    WHERE listing_id = p_listing_id
      AND status = 'pending';
END;
$$;


-- [SP02] Mark all messages in a conversation as read for the recipient
CREATE OR REPLACE PROCEDURE sp_mark_conversation_read(
    p_conversation_id INT,
    p_user_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE messages
    SET is_read = TRUE
    WHERE conversation_id = p_conversation_id
      AND sender_id <> p_user_id
      AND is_read = FALSE;
END;
$$;


-- [SP03] Concurrent refresh of all analytical materialized views
CREATE OR REPLACE PROCEDURE sp_refresh_analytics()
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_favourited_listings;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_seller_performance;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_category_summary;
END;
$$;
