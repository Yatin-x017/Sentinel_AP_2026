-- =====================================================================
-- CP2: Relational schema  |  DBMS project: 18. OLX Buy & Sell
-- Team T0058 (Sentinel)   |  Target: PostgreSQL 14+
-- All tables are in 3NF (see 01_normalization.md)
-- =====================================================================

DROP TABLE IF EXISTS reports, reviews, transactions, offers, messages,
    conversations, favorites, listing_images, listings, categories,
    users, cities, states CASCADE;

-- ---------- Location ----------
CREATE TABLE states (
    state_id    SERIAL       PRIMARY KEY,
    name        VARCHAR(60)  NOT NULL UNIQUE
);

CREATE TABLE cities (
    city_id     SERIAL       PRIMARY KEY,
    state_id    INT          NOT NULL REFERENCES states(state_id),
    name        VARCHAR(80)  NOT NULL,
    UNIQUE (state_id, name)
);

-- ---------- Users ----------
CREATE TABLE users (
    user_id        SERIAL        PRIMARY KEY,
    full_name      VARCHAR(100)  NOT NULL,
    email          VARCHAR(120)  NOT NULL UNIQUE,
    phone          VARCHAR(15)   NOT NULL UNIQUE,
    password_hash  VARCHAR(255)  NOT NULL,
    city_id        INT           NOT NULL REFERENCES cities(city_id),
    is_verified    BOOLEAN       NOT NULL DEFAULT FALSE,
    status         VARCHAR(10)   NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active','suspended','deleted')),
    created_at     TIMESTAMP     NOT NULL DEFAULT now()
);

-- ---------- Categories (self-referencing tree) ----------
CREATE TABLE categories (
    category_id  SERIAL       PRIMARY KEY,
    parent_id    INT          REFERENCES categories(category_id),
    name         VARCHAR(80)  NOT NULL,
    UNIQUE (parent_id, name)
);

-- ---------- Listings ----------
CREATE TABLE listings (
    listing_id     SERIAL         PRIMARY KEY,
    seller_id      INT            NOT NULL REFERENCES users(user_id),
    category_id    INT            NOT NULL REFERENCES categories(category_id),
    city_id        INT            NOT NULL REFERENCES cities(city_id),
    title          VARCHAR(150)   NOT NULL,
    description    TEXT,
    price          NUMERIC(12,2)  NOT NULL CHECK (price >= 0),
    condition      VARCHAR(10)    NOT NULL
                   CHECK (condition IN ('new','like_new','used','for_parts')),
    is_negotiable  BOOLEAN        NOT NULL DEFAULT TRUE,
    status         VARCHAR(10)    NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active','sold','expired','removed')),
    created_at     TIMESTAMP      NOT NULL DEFAULT now(),
    sold_at        TIMESTAMP,
    CHECK ((status = 'sold') = (sold_at IS NOT NULL))
);

CREATE TABLE listing_images (
    image_id    SERIAL        PRIMARY KEY,
    listing_id  INT           NOT NULL REFERENCES listings(listing_id) ON DELETE CASCADE,
    url         VARCHAR(300)  NOT NULL,
    position    SMALLINT      NOT NULL DEFAULT 1,
    UNIQUE (listing_id, position)
);

-- ---------- Favourites (M:N users <-> listings) ----------
CREATE TABLE favorites (
    user_id     INT        NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    listing_id  INT        NOT NULL REFERENCES listings(listing_id) ON DELETE CASCADE,
    created_at  TIMESTAMP  NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, listing_id)
);

-- ---------- Chat ----------
CREATE TABLE conversations (
    conversation_id  SERIAL     PRIMARY KEY,
    listing_id       INT        NOT NULL REFERENCES listings(listing_id) ON DELETE CASCADE,
    buyer_id         INT        NOT NULL REFERENCES users(user_id),
    created_at       TIMESTAMP  NOT NULL DEFAULT now(),
    UNIQUE (listing_id, buyer_id)
);

CREATE TABLE messages (
    message_id       BIGSERIAL  PRIMARY KEY,
    conversation_id  INT        NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    sender_id        INT        NOT NULL REFERENCES users(user_id),
    body             TEXT       NOT NULL,
    sent_at          TIMESTAMP  NOT NULL DEFAULT now(),
    is_read          BOOLEAN    NOT NULL DEFAULT FALSE
);

-- ---------- Offers ----------
CREATE TABLE offers (
    offer_id    SERIAL         PRIMARY KEY,
    listing_id  INT            NOT NULL REFERENCES listings(listing_id) ON DELETE CASCADE,
    buyer_id    INT            NOT NULL REFERENCES users(user_id),
    amount      NUMERIC(12,2)  NOT NULL CHECK (amount > 0),
    status      VARCHAR(10)    NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','accepted','rejected','withdrawn')),
    created_at  TIMESTAMP      NOT NULL DEFAULT now()
);

-- ---------- Completed sales ----------
CREATE TABLE transactions (
    transaction_id  SERIAL         PRIMARY KEY,
    listing_id      INT            NOT NULL UNIQUE REFERENCES listings(listing_id),
    buyer_id        INT            NOT NULL REFERENCES users(user_id),
    seller_id       INT            NOT NULL REFERENCES users(user_id),
    final_price     NUMERIC(12,2)  NOT NULL CHECK (final_price >= 0),
    completed_at    TIMESTAMP      NOT NULL DEFAULT now(),
    CHECK (buyer_id <> seller_id)
);

CREATE TABLE reviews (
    review_id       SERIAL       PRIMARY KEY,
    transaction_id  INT          NOT NULL REFERENCES transactions(transaction_id),
    reviewer_id     INT          NOT NULL REFERENCES users(user_id),
    reviewee_id     INT          NOT NULL REFERENCES users(user_id),
    rating          SMALLINT     NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment         TEXT,
    created_at      TIMESTAMP    NOT NULL DEFAULT now(),
    UNIQUE (transaction_id, reviewer_id),
    CHECK (reviewer_id <> reviewee_id)
);

-- ---------- Moderation ----------
CREATE TABLE reports (
    report_id    SERIAL       PRIMARY KEY,
    listing_id   INT          NOT NULL REFERENCES listings(listing_id) ON DELETE CASCADE,
    reporter_id  INT          NOT NULL REFERENCES users(user_id),
    reason       VARCHAR(20)  NOT NULL
                 CHECK (reason IN ('spam','fraud','prohibited','duplicate','other')),
    status       VARCHAR(10)  NOT NULL DEFAULT 'open'
                 CHECK (status IN ('open','reviewed','dismissed')),
    created_at   TIMESTAMP    NOT NULL DEFAULT now()
);
