-- =====================================================================
-- CP4: Indexes added after profiling the baseline plans (see 05_query_timings.md)
-- PostgreSQL does not index foreign keys automatically, so most of these
-- cover FK / filter columns used by the 30 queries.
-- =====================================================================
CREATE INDEX idx_listings_city_status_created ON listings (city_id, status, created_at DESC);
CREATE INDEX idx_listings_category_status     ON listings (category_id, status);
CREATE INDEX idx_listings_seller              ON listings (seller_id);
CREATE INDEX idx_listings_created_at          ON listings (created_at);
CREATE INDEX idx_listings_active_price        ON listings (price) WHERE status = 'active';
CREATE INDEX idx_favorites_listing            ON favorites (listing_id);
CREATE INDEX idx_conversations_buyer          ON conversations (buyer_id);
CREATE INDEX idx_messages_conv_sent           ON messages (conversation_id, sent_at DESC);
CREATE INDEX idx_messages_unread              ON messages (conversation_id) WHERE NOT is_read;
CREATE INDEX idx_offers_listing               ON offers (listing_id);
CREATE INDEX idx_offers_accepted              ON offers (listing_id) WHERE status = 'accepted';
CREATE INDEX idx_transactions_seller          ON transactions (seller_id);
CREATE INDEX idx_transactions_buyer           ON transactions (buyer_id);
CREATE INDEX idx_transactions_completed       ON transactions (completed_at);
CREATE INDEX idx_reviews_reviewee             ON reviews (reviewee_id);
CREATE INDEX idx_reports_open_listing         ON reports (listing_id) WHERE status = 'open';
CREATE INDEX idx_categories_parent            ON categories (parent_id);
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_listings_title_trgm          ON listings USING gin (title gin_trgm_ops);
ANALYZE;
