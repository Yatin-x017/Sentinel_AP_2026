-- =====================================================================
-- CP3: 30 queries (R01-R25 read, W01-W05 write)  |  18. OLX Buy & Sell
-- One query per reel (R01..R25, W01..W05). PostgreSQL 14+.
-- Parameters are hard-coded sample values so each query runs as-is.
-- Format: each block starts with "-- [ID] title" and ends with ";".
-- =====================================================================


-- [R01] Newest active listings in Gurugram with seller name (JOIN x3)
SELECT l.listing_id, l.title, l.price, u.full_name AS seller, l.created_at
FROM listings l
JOIN users  u ON u.user_id = l.seller_id
JOIN cities c ON c.city_id = l.city_id
WHERE c.name = 'Gurugram' AND l.status = 'active'
ORDER BY l.created_at DESC
LIMIT 20;

-- [R02] Active listing count per top-level category (self-join + GROUP BY)
SELECT p.name AS category, COUNT(*) AS active_listings
FROM listings l
JOIN categories c ON c.category_id = l.category_id
JOIN categories p ON p.category_id = c.parent_id
WHERE l.status = 'active'
GROUP BY p.name
ORDER BY active_listings DESC;

-- [R03] Negotiable smartphones priced 10,000-40,000 (filter + sort)
SELECT l.listing_id, l.title, l.price, l.condition
FROM listings l
JOIN categories c ON c.category_id = l.category_id
WHERE c.name = 'Smartphones'
  AND l.status = 'active'
  AND l.is_negotiable
  AND l.price BETWEEN 10000 AND 40000
ORDER BY l.price
LIMIT 50;

-- [R04] Keyword search on title (pattern match)
SELECT listing_id, title, price, city_id
FROM listings
WHERE status = 'active' AND title ILIKE '%iphone%'
ORDER BY created_at DESC
LIMIT 30;

-- [R05] Top 10 sellers by number of completed sales (JOIN + GROUP BY)
SELECT u.user_id, u.full_name, COUNT(*) AS sales, SUM(t.final_price) AS revenue
FROM transactions t
JOIN users u ON u.user_id = t.seller_id
GROUP BY u.user_id, u.full_name
ORDER BY sales DESC, revenue DESC
LIMIT 10;

-- [R06] Average price per category with more than 500 listings (HAVING)
SELECT c.name, COUNT(*) AS listings, ROUND(AVG(l.price), 2) AS avg_price
FROM listings l
JOIN categories c ON c.category_id = l.category_id
GROUP BY c.name
HAVING COUNT(*) > 500
ORDER BY avg_price DESC;

-- [R07] Users who have never posted a listing (NOT EXISTS)
SELECT u.user_id, u.full_name, u.email
FROM users u
WHERE NOT EXISTS (SELECT 1 FROM listings l WHERE l.seller_id = u.user_id)
ORDER BY u.user_id
LIMIT 50;

-- [R08] Best-rated sellers with at least 5 reviews (aggregate)
SELECT u.user_id, u.full_name, ROUND(AVG(r.rating), 2) AS avg_rating, COUNT(*) AS reviews
FROM reviews r
JOIN users u ON u.user_id = r.reviewee_id
GROUP BY u.user_id, u.full_name
HAVING COUNT(*) >= 5
ORDER BY avg_rating DESC, reviews DESC
LIMIT 10;

-- [R09] Ten most favourited active listings
SELECT l.listing_id, l.title, l.price, COUNT(*) AS favourites
FROM favorites f
JOIN listings l ON l.listing_id = f.listing_id
WHERE l.status = 'active'
GROUP BY l.listing_id, l.title, l.price
ORDER BY favourites DESC, l.listing_id
LIMIT 10;

-- [R10] One user's favourites with first image (JOIN + subquery)
SELECT l.listing_id, l.title, l.price, l.status,
       (SELECT i.url FROM listing_images i
        WHERE i.listing_id = l.listing_id AND i.position = 1) AS cover_image
FROM favorites f
JOIN listings l ON l.listing_id = f.listing_id
WHERE f.user_id = 42
ORDER BY f.created_at DESC;

-- [R11] Seller inbox: chats on my listings with the latest message (LATERAL)
SELECT c.conversation_id, l.title, b.full_name AS buyer, m.body AS last_message, m.sent_at
FROM listings l
JOIN conversations c ON c.listing_id = l.listing_id
JOIN users b ON b.user_id = c.buyer_id
JOIN LATERAL (
    SELECT body, sent_at FROM messages
    WHERE conversation_id = c.conversation_id
    ORDER BY sent_at DESC LIMIT 1
) m ON TRUE
WHERE l.seller_id = 7
ORDER BY m.sent_at DESC;

-- [R12] Unread messages per conversation for user 100 (buyer or seller)
SELECT m.conversation_id, COUNT(*) AS unread
FROM messages m
JOIN conversations c ON c.conversation_id = m.conversation_id
JOIN listings l ON l.listing_id = c.listing_id
WHERE NOT m.is_read
  AND m.sender_id <> 100
  AND (c.buyer_id = 100 OR l.seller_id = 100)
GROUP BY m.conversation_id
ORDER BY unread DESC;

-- [R13] Monthly sales revenue for the last 12 months (date_trunc)
SELECT date_trunc('month', completed_at)::date AS month,
       COUNT(*) AS sales, SUM(final_price) AS revenue
FROM transactions
WHERE completed_at >= now() - interval '12 months'
GROUP BY 1
ORDER BY 1;

-- [R14] Active listings and average price by state and city (ROLLUP)
SELECT s.name AS state, c.name AS city, COUNT(*) AS listings, ROUND(AVG(l.price), 0) AS avg_price
FROM listings l
JOIN cities c ON c.city_id = l.city_id
JOIN states s ON s.state_id = c.state_id
WHERE l.status = 'active'
GROUP BY ROLLUP (s.name, c.name)
ORDER BY s.name NULLS LAST, c.name NULLS LAST;

-- [R15] All sub-categories of Electronics with listing counts (recursive CTE)
WITH RECURSIVE tree AS (
    SELECT category_id, name, parent_id, 1 AS depth
    FROM categories WHERE name = 'Electronics' AND parent_id IS NULL
    UNION ALL
    SELECT c.category_id, c.name, c.parent_id, t.depth + 1
    FROM categories c JOIN tree t ON c.parent_id = t.category_id
)
SELECT t.name, t.depth, COUNT(l.listing_id) AS listings
FROM tree t
LEFT JOIN listings l ON l.category_id = t.category_id
GROUP BY t.name, t.depth
ORDER BY t.depth, t.name;

-- [R16] Accepted offers: biggest discounts versus asking price
SELECT o.offer_id, l.title, l.price AS asking, o.amount AS accepted,
       ROUND(100 * (l.price - o.amount) / NULLIF(l.price, 0), 1) AS discount_pct
FROM offers o
JOIN listings l ON l.listing_id = o.listing_id
WHERE o.status = 'accepted'
ORDER BY discount_pct DESC
LIMIT 20;

-- [R17] Three most expensive active listings in every leaf category (window)
SELECT *
FROM (
    SELECT c.name AS category, l.listing_id, l.title, l.price,
           ROW_NUMBER() OVER (PARTITION BY l.category_id ORDER BY l.price DESC) AS rn
    FROM listings l
    JOIN categories c ON c.category_id = l.category_id
    WHERE l.status = 'active'
) ranked
WHERE rn <= 3
ORDER BY category, rn;

-- [R18] Daily new listings and 7-day moving average, last 30 days (window)
SELECT day, new_listings,
       ROUND(AVG(new_listings) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1) AS moving_avg_7d
FROM (
    SELECT created_at::date AS day, COUNT(*) AS new_listings
    FROM listings
    WHERE created_at >= now() - interval '30 days'
    GROUP BY 1
) d
ORDER BY day;

-- [R19] Listings with 3 or more open reports (moderation queue)
SELECT l.listing_id, l.title, u.full_name AS seller, COUNT(*) AS open_reports
FROM reports r
JOIN listings l ON l.listing_id = r.listing_id
JOIN users u ON u.user_id = l.seller_id
WHERE r.status = 'open'
GROUP BY l.listing_id, l.title, u.full_name
HAVING COUNT(*) >= 3
ORDER BY open_reports DESC;

-- [R20] Top 10 buyers by total spend
SELECT u.user_id, u.full_name, COUNT(*) AS purchases, SUM(t.final_price) AS total_spent
FROM transactions t
JOIN users u ON u.user_id = t.buyer_id
GROUP BY u.user_id, u.full_name
ORDER BY total_spent DESC
LIMIT 10;

-- [R21] Active listings that nobody has favourited or messaged (double NOT EXISTS)
SELECT l.listing_id, l.title, l.price, l.created_at
FROM listings l
WHERE l.status = 'active'
  AND NOT EXISTS (SELECT 1 FROM favorites f WHERE f.listing_id = l.listing_id)
  AND NOT EXISTS (SELECT 1 FROM conversations c WHERE c.listing_id = l.listing_id)
ORDER BY l.created_at
LIMIT 20;

-- [R22] Sell-through rate per parent category (conditional aggregation)
SELECT p.name AS category,
       COUNT(*) AS total,
       COUNT(*) FILTER (WHERE l.status = 'sold') AS sold,
       ROUND(100.0 * COUNT(*) FILTER (WHERE l.status = 'sold') / COUNT(*), 1) AS sell_through_pct
FROM listings l
JOIN categories c ON c.category_id = l.category_id
JOIN categories p ON p.category_id = c.parent_id
GROUP BY p.name
ORDER BY sell_through_pct DESC;

-- [R23] Sellers with 10+ sales and rating above the platform average (subquery)
SELECT u.user_id, u.full_name, ROUND(AVG(r.rating), 2) AS avg_rating, COUNT(DISTINCT t.transaction_id) AS sales
FROM users u
JOIN transactions t ON t.seller_id = u.user_id
JOIN reviews r ON r.reviewee_id = u.user_id
GROUP BY u.user_id, u.full_name
HAVING COUNT(DISTINCT t.transaction_id) >= 10
   AND AVG(r.rating) > (SELECT AVG(rating) FROM reviews)
ORDER BY avg_rating DESC
LIMIT 20;

-- [R24] Active listings priced 50% above their category average (CTE + join)
WITH cat_avg AS (
    SELECT category_id, AVG(price) AS avg_price
    FROM listings WHERE status = 'active'
    GROUP BY category_id
)
SELECT l.listing_id, l.title, l.price, ROUND(a.avg_price, 0) AS category_avg
FROM listings l
JOIN cat_avg a ON a.category_id = l.category_id
WHERE l.status = 'active' AND l.price > 1.5 * a.avg_price
ORDER BY l.price DESC
LIMIT 20;

-- [R25] Average seller reply time to a buyer's first message, top 10 fastest (CTE)
WITH first_msgs AS (
    SELECT m.conversation_id,
           MIN(m.sent_at) FILTER (WHERE m.sender_id = c.buyer_id)  AS buyer_first,
           MIN(m.sent_at) FILTER (WHERE m.sender_id = l.seller_id) AS seller_first,
           l.seller_id
    FROM messages m
    JOIN conversations c ON c.conversation_id = m.conversation_id
    JOIN listings l      ON l.listing_id = c.listing_id
    GROUP BY m.conversation_id, l.seller_id
)
SELECT u.user_id, u.full_name, COUNT(*) AS chats,
       AVG(f.seller_first - f.buyer_first) AS avg_reply_time
FROM first_msgs f
JOIN users u ON u.user_id = f.seller_id
WHERE f.seller_first > f.buyer_first
GROUP BY u.user_id, u.full_name
HAVING COUNT(*) >= 3
ORDER BY avg_reply_time
LIMIT 10;

-- [W01] Post a new listing together with its cover image (data-modifying CTE)
WITH new_listing AS (
    INSERT INTO listings (seller_id, category_id, city_id, title, description, price, condition, is_negotiable)
    VALUES (77, 9, 4, 'iPhone 13 128GB', 'Single owner, with box and bill.', 38500.00, 'like_new', TRUE)
    RETURNING listing_id
)
INSERT INTO listing_images (listing_id, url, position)
SELECT listing_id, 'https://img.example.com/new_iphone13.jpg', 1 FROM new_listing;

-- [W02] Price drop: cut all of seller 123's active listings by 10%
UPDATE listings
SET price = ROUND(price * 0.90, 2)
WHERE seller_id = 123 AND status = 'active';

-- [W03] Mark a listing as sold and record the transaction (atomic CTE)
WITH pick AS (
    SELECT listing_id, seller_id, price
    FROM listings
    WHERE status = 'active' AND seller_id <> 77
    ORDER BY listing_id
    LIMIT 1
), upd AS (
    UPDATE listings l
    SET status = 'sold', sold_at = now()
    FROM pick
    WHERE l.listing_id = pick.listing_id
    RETURNING l.listing_id
)
INSERT INTO transactions (listing_id, buyer_id, seller_id, final_price)
SELECT p.listing_id, 77, p.seller_id, ROUND(p.price * 0.90, 2) FROM pick p;

-- [W04] Buyer leaves a 5-star review on a sale that has no review yet
INSERT INTO reviews (transaction_id, reviewer_id, reviewee_id, rating, comment)
SELECT t.transaction_id, t.buyer_id, t.seller_id, 5, 'Smooth deal, item as described.'
FROM transactions t
WHERE NOT EXISTS (SELECT 1 FROM reviews r WHERE r.transaction_id = t.transaction_id)
ORDER BY t.transaction_id
LIMIT 1;

-- [W05] Housekeeping: delete stale favourites of listings that are no longer active
DELETE FROM favorites f
USING listings l
WHERE l.listing_id = f.listing_id
  AND l.status <> 'active'
  AND f.created_at < now() - interval '150 days';
