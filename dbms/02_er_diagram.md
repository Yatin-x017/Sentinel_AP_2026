# CP2 - ER diagram: OLX Buy & Sell

Image versions: [02_er_diagram.png](02_er_diagram.png), [02_er_diagram.svg](02_er_diagram.svg) (source: `02_er_diagram.dot`).

![ER diagram](02_er_diagram.png)

## Mermaid version (renders on GitHub)

```mermaid
erDiagram
    states ||--o{ cities : "belongs to"
    cities ||--o{ users : "lives in"
    categories ||--o{ categories : "parent of"
    users ||--o{ listings : "posts"
    categories ||--o{ listings : "classified as"
    cities ||--o{ listings : "located in"
    listings ||--o{ listing_images : "has"
    users ||--o{ favorites : "saves"
    listings ||--o{ favorites : "saved in"
    listings ||--o{ conversations : "about"
    users ||--o{ conversations : "starts (buyer)"
    conversations ||--o{ messages : "contains"
    users ||--o{ messages : "sends"
    listings ||--o{ offers : "receives"
    users ||--o{ offers : "makes"
    listings ||--o| transactions : "closes"
    users ||--o{ transactions : "buys"
    transactions ||--o{ reviews : "rates"
    users ||--o{ reviews : "writes"
    listings ||--o{ reports : "flagged by"
    users ||--o{ reports : "files"
    states {
        SERIAL state_id PK
        VARCHAR_60 name
    }
    cities {
        SERIAL city_id PK
        INT state_id FK
        VARCHAR_80 name
    }
    users {
        SERIAL user_id PK
        VARCHAR_100 full_name
        VARCHAR_120 email
        VARCHAR_15 phone
        VARCHAR_255 password_hash
        INT city_id FK
        BOOLEAN is_verified
        VARCHAR_10 status
        TIMESTAMP created_at
    }
    categories {
        SERIAL category_id PK
        INT parent_id FK
        VARCHAR_80 name
    }
    listings {
        SERIAL listing_id PK
        INT seller_id FK
        INT category_id FK
        INT city_id FK
        VARCHAR_150 title
        TEXT description
        NUMERIC_12_2 price
        VARCHAR_10 condition
        BOOLEAN is_negotiable
        VARCHAR_10 status
        TIMESTAMP created_at
        TIMESTAMP sold_at
    }
    listing_images {
        SERIAL image_id PK
        INT listing_id FK
        VARCHAR_300 url
        SMALLINT position
    }
    favorites {
        INT user_id PK,FK
        INT listing_id PK,FK
        TIMESTAMP created_at
    }
    conversations {
        SERIAL conversation_id PK
        INT listing_id FK
        INT buyer_id FK
        TIMESTAMP created_at
    }
    messages {
        BIGSERIAL message_id PK
        INT conversation_id FK
        INT sender_id FK
        TEXT body
        TIMESTAMP sent_at
        BOOLEAN is_read
    }
    offers {
        SERIAL offer_id PK
        INT listing_id FK
        INT buyer_id FK
        NUMERIC_12_2 amount
        VARCHAR_10 status
        TIMESTAMP created_at
    }
    transactions {
        SERIAL transaction_id PK
        INT listing_id FK
        INT buyer_id FK
        INT seller_id FK
        NUMERIC_12_2 final_price
        TIMESTAMP completed_at
    }
    reviews {
        SERIAL review_id PK
        INT transaction_id FK
        INT reviewer_id FK
        INT reviewee_id FK
        SMALLINT rating
        TEXT comment
        TIMESTAMP created_at
    }
    reports {
        SERIAL report_id PK
        INT listing_id FK
        INT reporter_id FK
        VARCHAR_20 reason
        VARCHAR_10 status
        TIMESTAMP created_at
    }
```

## Relationships and cardinalities

| Parent (1) | Child (N) | Meaning |
|---|---|---|
| states | cities | belongs to |
| cities | users | lives in |
| categories | categories | parent of |
| users | listings | posts |
| categories | listings | classified as |
| cities | listings | located in |
| listings | listing_images | has |
| users | favorites | saves |
| listings | favorites | saved in |
| listings | conversations | about |
| users | conversations | starts (buyer) |
| conversations | messages | contains |
| users | messages | sends |
| listings | offers | receives |
| users | offers | makes |
| listings | transactions | closes |
| users | transactions | buys |
| transactions | reviews | rates |
| users | reviews | writes |
| listings | reports | flagged by |
| users | reports | files |

- `favorites` is the associative table for the many-to-many relationship between users and listings (composite PK).
- `transactions.listing_id` is UNIQUE: a listing is sold at most once (1:1 with a sale).
- `reviews` has UNIQUE (transaction_id, reviewer_id): each party reviews a sale once.
- `conversations` has UNIQUE (listing_id, buyer_id): one chat thread per buyer per listing.
- `categories.parent_id` is a recursive (self) relationship that forms the category tree.
