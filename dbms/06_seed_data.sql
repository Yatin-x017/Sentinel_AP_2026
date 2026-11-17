-- =====================================================================
-- Seed data: reference rows + bulk synthetic data (deterministic)
-- Run after 03_schema.sql.   Approx. 20k users, 100k listings, 200k messages
-- =====================================================================
SELECT setseed(0.42);

INSERT INTO states(name) VALUES
 ('Delhi'),('Haryana'),('Maharashtra'),('Karnataka'),('Rajasthan'),
 ('Uttar Pradesh'),('Tamil Nadu'),('Gujarat');

INSERT INTO cities(state_id, name) VALUES
 (1,'New Delhi'),(1,'Dwarka'),
 (2,'Gurugram'),(2,'Sonipat'),(2,'Faridabad'),
 (3,'Mumbai'),(3,'Pune'),
 (4,'Bengaluru'),(4,'Mysuru'),
 (5,'Jaipur'),(5,'Jodhpur'),
 (6,'Noida'),(6,'Lucknow'),
 (7,'Chennai'),(7,'Coimbatore'),
 (8,'Ahmedabad'),(8,'Surat');

-- Category tree: 8 roots, 4 children each
INSERT INTO categories(parent_id, name) VALUES
 (NULL,'Mobiles'),(NULL,'Vehicles'),(NULL,'Electronics'),(NULL,'Furniture'),
 (NULL,'Fashion'),(NULL,'Books & Sports'),(NULL,'Home Appliances'),(NULL,'Services');
INSERT INTO categories(parent_id, name)
SELECT p.category_id, c.name FROM categories p
JOIN (VALUES
 ('Mobiles','Smartphones'),('Mobiles','Tablets'),('Mobiles','Accessories'),('Mobiles','Smart Watches'),
 ('Vehicles','Cars'),('Vehicles','Motorcycles'),('Vehicles','Scooters'),('Vehicles','Bicycles'),
 ('Electronics','Laptops'),('Electronics','Cameras'),('Electronics','TVs'),('Electronics','Gaming'),
 ('Furniture','Sofas'),('Furniture','Beds'),('Furniture','Tables'),('Furniture','Wardrobes'),
 ('Fashion','Men'),('Fashion','Women'),('Fashion','Kids'),('Fashion','Footwear'),
 ('Books & Sports','Books'),('Books & Sports','Gym Equipment'),('Books & Sports','Cricket'),('Books & Sports','Musical Instruments'),
 ('Home Appliances','Refrigerators'),('Home Appliances','Washing Machines'),('Home Appliances','ACs'),('Home Appliances','Kitchen'),
 ('Services','Tuition'),('Services','Repairs'),('Services','Movers'),('Services','Events')
) AS c(parent, name) ON p.name = c.parent AND p.parent_id IS NULL;

-- Users
INSERT INTO users(full_name, email, phone, password_hash, city_id, is_verified, status, created_at)
SELECT 'User ' || g,
       'user' || g || '@example.com',
       '9' || lpad(g::text, 9, '0'),
       md5(g::text),
       1 + (random()*16)::int,
       random() < 0.6,
       CASE WHEN random() < 0.02 THEN 'suspended' ELSE 'active' END,
       now() - (random()*730) * interval '1 day'
FROM generate_series(1, 20000) g;

-- Listings (leaf categories only: ids 9..40)
INSERT INTO listings(seller_id, category_id, city_id, title, description, price, condition,
                     is_negotiable, status, created_at)
SELECT 1 + (random()*19999)::int,
       9 + (random()*31)::int,
       1 + (random()*16)::int,
       (ARRAY['iPhone','Samsung','Royal Enfield','Honda City','Dell Laptop','Study Table',
              'Sofa Set','LG Fridge','Canon DSLR','Cricket Bat','Yamaha Guitar','Cycle',
              'Wardrobe','Treadmill','Sony TV','Washing Machine'])[1 + (random()*15)::int]
         || ' #' || g,
       'Well maintained item, listing number ' || g || '. Contact for details.',
       round((50 + random()*random()*200000)::numeric, 2),
       (ARRAY['new','like_new','used','used','for_parts'])[1 + (random()*4)::int],
       random() < 0.7,
       (ARRAY['active','active','active','active','expired','removed'])[1 + (random()*5)::int],
       now() - (random()*365) * interval '1 day'
FROM generate_series(1, 100000) g;

-- Mark ~15% as sold + create the matching transactions
WITH sold AS (
    UPDATE listings SET status = 'sold', sold_at = created_at + (random()*20) * interval '1 day'
    WHERE random() < 0.15
    RETURNING listing_id, seller_id, price, sold_at
)
INSERT INTO transactions(listing_id, buyer_id, seller_id, final_price, completed_at)
SELECT s.listing_id,
       b.buyer,
       s.seller_id,
       round((s.price * (0.8 + random()*0.2))::numeric, 2),
       s.sold_at
FROM sold s
CROSS JOIN LATERAL (
    SELECT CASE WHEN x = s.seller_id THEN (x % 20000) + 1 ELSE x END AS buyer
    FROM (SELECT 1 + (random()*19999)::int AS x) q
) b;

-- Images (1-3 per listing)
INSERT INTO listing_images(listing_id, url, position)
SELECT l.listing_id, 'https://img.example.com/' || l.listing_id || '_' || p || '.jpg', p
FROM listings l, generate_series(1,3) p
WHERE p = 1 OR random() < 0.6;

-- Favourites
INSERT INTO favorites(user_id, listing_id, created_at)
SELECT DISTINCT ON (u, l) u, l, now() - (random()*200) * interval '1 day'
FROM (SELECT 1 + (random()*19999)::int AS u, 1 + (random()*99999)::int AS l
      FROM generate_series(1,170000)) t;

-- Conversations + messages
INSERT INTO conversations(listing_id, buyer_id, created_at)
SELECT DISTINCT ON (l, b) l, b, now() - (random()*200) * interval '1 day'
FROM (SELECT 1 + (random()*99999)::int AS l, 1 + (random()*19999)::int AS b
      FROM generate_series(1,50000)) t;

INSERT INTO messages(conversation_id, sender_id, body, sent_at, is_read)
SELECT c.conversation_id,
       CASE WHEN m % 2 = 1 THEN c.buyer_id ELSE l.seller_id END,
       (ARRAY['Is this still available?','What is your last price?','Can you share more photos?',
              'I can pick it up today','Deal, please confirm','Where can we meet?'])[1 + (random()*5)::int],
       c.created_at + (m * interval '37 minutes'),
       random() < 0.8
FROM conversations c
JOIN listings l ON l.listing_id = c.listing_id
CROSS JOIN generate_series(1,6) m
WHERE m <= 1 + (random()*5)::int OR m = 1;

-- Offers
INSERT INTO offers(listing_id, buyer_id, amount, status, created_at)
SELECT l.listing_id, 1 + (random()*19999)::int,
       round((l.price * (0.5 + random()*0.45))::numeric, 2),
       (ARRAY['pending','accepted','rejected','withdrawn'])[1 + (random()*3)::int],
       l.created_at + (random()*10) * interval '1 day'
FROM listings l
WHERE random() < 0.5;

-- Reviews (about 70% of transactions, buyer reviews seller)
INSERT INTO reviews(transaction_id, reviewer_id, reviewee_id, rating, comment, created_at)
SELECT t.transaction_id, t.buyer_id, t.seller_id,
       LEAST(5, GREATEST(1, 3 + (random()*2.4)::int - (random()*1.2)::int)),
       'Transaction feedback',
       t.completed_at + interval '1 day'
FROM transactions t WHERE random() < 0.7;

-- Reports
INSERT INTO reports(listing_id, reporter_id, reason, status, created_at)
SELECT 1 + (random()*99999)::int, 1 + (random()*19999)::int,
       (ARRAY['spam','fraud','prohibited','duplicate','other'])[1 + (random()*4)::int],
       (ARRAY['open','reviewed','dismissed'])[1 + (random()*2)::int],
       now() - (random()*100) * interval '1 day'
FROM generate_series(1, 4000);

ANALYZE;
