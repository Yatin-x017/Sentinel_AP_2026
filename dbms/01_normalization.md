# CP1 - Normalization: OLX Buy & Sell

Team T0058 (Sentinel) - DBMS project 18. OLX Buy & Sell

## 1. Problem understanding

OLX Buy & Sell is a classifieds marketplace. Users post listings for items they want to sell, browse and search by category and city, save favourites, chat with sellers, make price offers, complete sales and rate each other. Moderators handle reports on suspicious listings.

Main entities: user, listing, category (hierarchical), city/state, listing image, favourite, conversation, message, offer, transaction, review, report.

Business rules that drive the design:

1. A user lives in one city; a city belongs to one state.
2. A listing is posted by exactly one seller, belongs to one (leaf) category and is located in one city.
3. A category can have a parent category (Mobiles > Smartphones).
4. A listing has many ordered images.
5. A user can favourite many listings; a listing can be favourited by many users.
6. A buyer has at most one conversation per listing; a conversation holds many messages.
7. A listing can receive many offers but is sold at most once.
8. After a sale, buyer and seller may each review the other once.
9. Any user can report a listing.

## 2. Starting point: one wide unnormalized table

Everything the app shows on a listing page, stored as a single sheet:

```
LISTING_SHEET(
  listing_id, title, description, price, condition, status, posted_at,
  seller_id, seller_name, seller_email, seller_phone,
  seller_city, seller_state,
  category_name, parent_category_name,
  image_urls,                      -- "a.jpg, b.jpg, c.jpg"
  favourited_by_user_ids,          -- "4, 19, 77"
  buyer_id, buyer_name, final_price, sold_at   -- only when sold
)
```

Problems (anomalies) in this design:

| Anomaly | Example |
|---|---|
| Update | Seller changes phone number: every one of their listings must be edited; miss one and the data conflicts. |
| Insert | A new category or city cannot exist until some listing uses it. |
| Delete | Deleting the only listing in "Cameras" erases the fact that the category exists. |
| Redundancy | Seller name, email, city and state repeat on every listing they post. |
| Multi-valued cells | `image_urls` and `favourited_by_user_ids` hold lists inside one cell, so they cannot be searched or constrained. |

## 3. First Normal Form (1NF)

Rule: every attribute is atomic, no repeating groups, each row identified by a key.

Changes:

- `image_urls` split into one row per image, keyed with the position.
- `favourited_by_user_ids` split into one row per (user, listing).
- Sale data (`buyer_*`, `final_price`, `sold_at`) moved out so there are no NULL-filled optional columns.

```
LISTING(listing_id, title, description, price, condition, status, posted_at,
        seller_id, seller_name, seller_email, seller_phone, seller_city, seller_state,
        category_name, parent_category_name)
LISTING_IMAGE(listing_id, position, url)
FAVORITE(user_id, listing_id, favourited_at)
SALE(listing_id, buyer_id, buyer_name, final_price, sold_at)
```

## 4. Second Normal Form (2NF)

Rule: 1NF and no partial dependency (a non-key attribute must depend on the whole key, not part of it).

Only tables with composite keys can violate this.

- `LISTING_IMAGE(listing_id, position, url)` - key (listing_id, position). `url` depends on both. OK.
- `FAVORITE(user_id, listing_id, favourited_at)` - `favourited_at` depends on the pair. OK.
- If we had kept `listing_title` or `user_name` inside FAVORITE, they would depend on only one half of the key. Those are not stored there, so no change is needed. We also replace the composite key of LISTING_IMAGE by a surrogate `image_id` (with UNIQUE(listing_id, position)) to simplify joins.

All remaining tables have single-column keys, so they are in 2NF.

## 5. Third Normal Form (3NF)

Rule: 2NF and no transitive dependency (non-key attribute depending on another non-key attribute).

Functional dependencies found in LISTING and SALE:

| Dependency | Why it is transitive | Fix |
|---|---|---|
| listing_id -> seller_id -> seller_name, seller_email, seller_phone, seller_city | seller details are determined by seller_id, not by the listing | new table `users` |
| seller_city -> seller_state | state is determined by city | tables `cities`, `states` |
| listing_id -> category_name -> parent_category_name | parent is determined by the category | table `categories` with self reference `parent_id` |
| buyer_id -> buyer_name | buyer details are determined by buyer_id | buyer stored as FK to `users` |

After decomposition:

```
states(state_id PK, name)
cities(city_id PK, state_id FK, name)
users(user_id PK, full_name, email, phone, password_hash, city_id FK, is_verified, status, created_at)
categories(category_id PK, parent_id FK -> categories, name)
listings(listing_id PK, seller_id FK, category_id FK, city_id FK, title, description, price,
         condition, is_negotiable, status, created_at, sold_at)
listing_images(image_id PK, listing_id FK, url, position)
favorites(user_id FK, listing_id FK, created_at)           PK(user_id, listing_id)
transactions(transaction_id PK, listing_id FK UNIQUE, buyer_id FK, seller_id FK, final_price, completed_at)
```

Entities that appear in the application but were missing from the sheet are modelled directly in 3NF:

```
conversations(conversation_id PK, listing_id FK, buyer_id FK, created_at)    UNIQUE(listing_id, buyer_id)
messages(message_id PK, conversation_id FK, sender_id FK, body, sent_at, is_read)
offers(offer_id PK, listing_id FK, buyer_id FK, amount, status, created_at)
reviews(review_id PK, transaction_id FK, reviewer_id FK, reviewee_id FK, rating, comment, created_at)
         UNIQUE(transaction_id, reviewer_id)
reports(report_id PK, listing_id FK, reporter_id FK, reason, status, created_at)
```

## 6. BCNF check

BCNF requires that for every non-trivial functional dependency X -> Y, X is a superkey.

| Table | Non-trivial FDs | Determinant is a key? |
|---|---|---|
| states | state_id -> name; name -> state_id | yes (PK and UNIQUE) |
| cities | city_id -> state_id, name; (state_id, name) -> city_id | yes |
| users | user_id -> all; email -> all; phone -> all | yes (PK, two candidate keys) |
| categories | category_id -> parent_id, name; (parent_id, name) -> category_id | yes |
| listings | listing_id -> all | yes |
| listing_images | image_id -> all; (listing_id, position) -> all | yes |
| favorites | (user_id, listing_id) -> created_at | yes |
| conversations | conversation_id -> all; (listing_id, buyer_id) -> all | yes |
| messages | message_id -> all | yes |
| offers | offer_id -> all | yes |
| transactions | transaction_id -> all; listing_id -> all | yes (listing_id is a candidate key) |
| reviews | review_id -> all; (transaction_id, reviewer_id) -> all | yes |
| reports | report_id -> all | yes |

Every determinant is a superkey, so all 13 tables are in BCNF (and therefore 3NF).

Design notes:

- `transactions.seller_id` is derivable from `listings.seller_id` through `listing_id`. It is kept on purpose: it is a snapshot that stays correct if a listing is ever reassigned, and it avoids a join in seller revenue reports. This is a controlled, documented denormalization; the CHECK (buyer_id <> seller_id) uses it.
- `reviews.reviewee_id` is likewise derivable (the other party of the transaction); it is stored so that "reviews about a user" can be indexed directly.

## 7. Final table list

13 tables: states, cities, users, categories, listings, listing_images, favorites, conversations, messages, offers, transactions, reviews, reports. DDL is in `03_schema.sql`, the ER diagram in `02_er_diagram.md`.
