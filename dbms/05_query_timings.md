# CP4 - Query timings and execution plans

Team T0058 (Sentinel) - DBMS project 18. OLX Buy & Sell

## 1. Setup

| Item | Value |
|---|---|
| DBMS | PostgreSQL 16.15 (Ubuntu), default configuration |
| Schema | `03_schema.sql` (13 tables) |
| Data | `06_seed_data.sql`, deterministic synthetic data (setseed 0.42) |
| Queries | `04_queries.sql`: 25 `-- READ` queries (R01-R25) and 5 `-- WRITE` queries (W01-W05) |
| Indexes | baseline = primary keys and UNIQUE constraints only; indexed = plus `07_indexes.sql` |
| Method | `run_timings.py`: `EXPLAIN (ANALYZE, BUFFERS)`, 1 warm-up run (discarded), then **3 timed runs (Run 1, Run 2, Run 3)**; **Average (ms)** = mean of the 3 runs |
| Writes (W01-W05) | executed inside BEGIN ... ROLLBACK so data is not changed between runs |

Row counts:

| Table | Rows | Table | Rows |
|---|---|---|---|
| users | 20,000 | favorites | 169,993 |
| listings | 100,000 | conversations | 50,000 |
| listing_images | 300,000 | messages | 150,000 |
| transactions | 15,086 | offers | 49,994 |
| reviews | 10,511 | reports | 4,000 |

Reproduce:

```
createdb olx
psql -d olx -f dbms/03_schema.sql
psql -d olx -f dbms/06_seed_data.sql
python3 dbms/run_timings.py baseline
psql -d olx -f dbms/07_indexes.sql
python3 dbms/run_timings.py indexed
```

Timings depend on the machine; the relative improvement and the plan shapes are what matter. Full plans are stored in `plans/baseline/` and `plans/indexed/` (one file per query, plus `summary.csv` with Run 1, Run 2, Run 3 and the average).

## 2. Results

### 2.1 Baseline (primary keys and UNIQUE constraints only)

| ID | Type | Query | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Plan |
|---|---|---|---|---|---|---|---|
| R01 | READ | Newest active listings in Gurugram with seller name (JOIN x3) | 27.073 | 26.874 | 27.047 | **26.998** | [baseline](plans/baseline/R01.txt) |
| R02 | READ | Active listing count per top-level category (self-join + GROUP BY) | 45.407 | 41.338 | 40.795 | **42.513** | [baseline](plans/baseline/R02.txt) |
| R03 | READ | Negotiable smartphones priced 10,000-40,000 (filter + sort) | 23.253 | 23.509 | 23.041 | **23.268** | [baseline](plans/baseline/R03.txt) |
| R04 | READ | Keyword search on title (pattern match) | 60.866 | 53.253 | 52.253 | **55.457** | [baseline](plans/baseline/R04.txt) |
| R05 | READ | Top 10 sellers by number of completed sales (JOIN + GROUP BY) | 26.084 | 27.074 | 35.282 | **29.480** | [baseline](plans/baseline/R05.txt) |
| R06 | READ | Average price per category with more than 500 listings (HAVING) | 52.033 | 52.269 | 52.635 | **52.312** | [baseline](plans/baseline/R06.txt) |
| R07 | READ | Users who have never posted a listing (anti-join: LEFT JOIN ... IS NULL) | 43.805 | 34.954 | 32.340 | **37.033** | [baseline](plans/baseline/R07.txt) |
| R08 | READ | Best-rated sellers with at least 5 reviews (aggregate) | 14.643 | 14.461 | 15.107 | **14.737** | [baseline](plans/baseline/R08.txt) |
| R09 | READ | Ten most favourited active listings | 140.977 | 163.885 | 149.483 | **151.448** | [baseline](plans/baseline/R09.txt) |
| R10 | READ | One user's favourites with first image (JOIN + LEFT JOIN) | 0.373 | 0.430 | 0.347 | **0.383** | [baseline](plans/baseline/R10.txt) |
| R11 | READ | Seller inbox: chats on my listings with the latest message (LATERAL) | 44.484 | 47.311 | 45.653 | **45.816** | [baseline](plans/baseline/R11.txt) |
| R12 | READ | Unread messages per conversation for user 100 (buyer or seller) | 94.102 | 93.166 | 90.958 | **92.742** | [baseline](plans/baseline/R12.txt) |
| R13 | READ | Monthly sales revenue for the last 12 months (date_trunc) | 10.861 | 11.558 | 11.869 | **11.429** | [baseline](plans/baseline/R13.txt) |
| R14 | READ | Active listings and average price by state and city (ROLLUP) | 62.544 | 63.292 | 60.990 | **62.275** | [baseline](plans/baseline/R14.txt) |
| R15 | READ | All sub-categories of Electronics with listing counts (recursive CTE) | 29.824 | 29.281 | 29.846 | **29.650** | [baseline](plans/baseline/R15.txt) |
| R16 | READ | Accepted offers: biggest discounts versus asking price | 47.962 | 46.897 | 84.649 | **59.836** | [baseline](plans/baseline/R16.txt) |
| R17 | READ | Three most expensive active listings in every leaf category (window) | 143.509 | 151.736 | 150.640 | **148.628** | [baseline](plans/baseline/R17.txt) |
| R18 | READ | Daily new listings and 7-day moving average, last 30 days (window) | 24.879 | 24.109 | 27.918 | **25.635** | [baseline](plans/baseline/R18.txt) |
| R19 | READ | Listings with 3 or more open reports (moderation queue) | 23.452 | 23.321 | 23.150 | **23.308** | [baseline](plans/baseline/R19.txt) |
| R20 | READ | Top 10 buyers by total spend | 9.735 | 9.801 | 9.765 | **9.767** | [baseline](plans/baseline/R20.txt) |
| R21 | READ | Active listings that nobody has favourited or messaged (double anti-join) | 117.512 | 138.774 | 115.233 | **123.840** | [baseline](plans/baseline/R21.txt) |
| R22 | READ | Sell-through rate per parent category (conditional aggregation) | 65.641 | 66.924 | 67.388 | **66.651** | [baseline](plans/baseline/R22.txt) |
| R23 | READ | Sellers with 10+ sales and rating above the platform average (JOIN on a one-row aggregate) | 38.134 | 37.556 | 38.221 | **37.970** | [baseline](plans/baseline/R23.txt) |
| R24 | READ | Active listings priced 50% above their category average (CTE + join) | 69.785 | 93.927 | 69.102 | **77.605** | [baseline](plans/baseline/R24.txt) |
| R25 | READ | Average seller reply time to a buyer's first message, top 10 fastest (CTE) | 304.433 | 233.939 | 231.446 | **256.606** | [baseline](plans/baseline/R25.txt) |
| W01 | WRITE | Post a new listing together with its cover image (data-modifying CTE) | 1.203 | 1.123 | 1.111 | **1.146** | [baseline](plans/baseline/W01.txt) |
| W02 | WRITE | Price drop: cut all of seller 123's active listings by 10% | 11.427 | 11.445 | 11.460 | **11.444** | [baseline](plans/baseline/W02.txt) |
| W03 | WRITE | Mark a listing as sold and record the transaction (atomic CTE) | 0.794 | 0.816 | 0.795 | **0.802** | [baseline](plans/baseline/W03.txt) |
| W04 | WRITE | Buyer leaves a 5-star review on a sale that has no review yet | 0.602 | 0.601 | 0.589 | **0.597** | [baseline](plans/baseline/W04.txt) |
| W05 | WRITE | Housekeeping: delete stale favourites of listings that are no longer active | 73.602 | 69.772 | 75.119 | **72.831** | [baseline](plans/baseline/W05.txt) |

### 2.2 Indexed (after `07_indexes.sql`)

| ID | Type | Query | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Plan |
|---|---|---|---|---|---|---|---|
| R01 | READ | Newest active listings in Gurugram with seller name (JOIN x3) | 1.797 | 1.655 | 1.675 | **1.709** | [indexed](plans/indexed/R01.txt) |
| R02 | READ | Active listing count per top-level category (self-join + GROUP BY) | 45.208 | 38.800 | 38.279 | **40.762** | [indexed](plans/indexed/R02.txt) |
| R03 | READ | Negotiable smartphones priced 10,000-40,000 (filter + sort) | 4.632 | 4.510 | 4.706 | **4.616** | [indexed](plans/indexed/R03.txt) |
| R04 | READ | Keyword search on title (pattern match) | 2.777 | 2.732 | 2.640 | **2.716** | [indexed](plans/indexed/R04.txt) |
| R05 | READ | Top 10 sellers by number of completed sales (JOIN + GROUP BY) | 39.622 | 28.973 | 24.069 | **30.888** | [indexed](plans/indexed/R05.txt) |
| R06 | READ | Average price per category with more than 500 listings (HAVING) | 50.444 | 51.575 | 51.732 | **51.250** | [indexed](plans/indexed/R06.txt) |
| R07 | READ | Users who have never posted a listing (anti-join: LEFT JOIN ... IS NULL) | 11.260 | 10.738 | 10.725 | **10.908** | [indexed](plans/indexed/R07.txt) |
| R08 | READ | Best-rated sellers with at least 5 reviews (aggregate) | 13.634 | 13.449 | 13.336 | **13.473** | [indexed](plans/indexed/R08.txt) |
| R09 | READ | Ten most favourited active listings | 127.625 | 130.867 | 132.412 | **130.301** | [indexed](plans/indexed/R09.txt) |
| R10 | READ | One user's favourites with first image (JOIN + LEFT JOIN) | 0.308 | 0.334 | 0.305 | **0.316** | [indexed](plans/indexed/R10.txt) |
| R11 | READ | Seller inbox: chats on my listings with the latest message (LATERAL) | 0.261 | 0.245 | 0.231 | **0.246** | [indexed](plans/indexed/R11.txt) |
| R12 | READ | Unread messages per conversation for user 100 (buyer or seller) | 42.956 | 43.291 | 43.356 | **43.201** | [indexed](plans/indexed/R12.txt) |
| R13 | READ | Monthly sales revenue for the last 12 months (date_trunc) | 11.087 | 11.174 | 10.663 | **10.975** | [indexed](plans/indexed/R13.txt) |
| R14 | READ | Active listings and average price by state and city (ROLLUP) | 59.686 | 60.189 | 60.588 | **60.154** | [indexed](plans/indexed/R14.txt) |
| R15 | READ | All sub-categories of Electronics with listing counts (recursive CTE) | 29.975 | 29.186 | 29.700 | **29.620** | [indexed](plans/indexed/R15.txt) |
| R16 | READ | Accepted offers: biggest discounts versus asking price | 42.903 | 44.778 | 46.739 | **44.807** | [indexed](plans/indexed/R16.txt) |
| R17 | READ | Three most expensive active listings in every leaf category (window) | 135.261 | 134.836 | 134.049 | **134.715** | [indexed](plans/indexed/R17.txt) |
| R18 | READ | Daily new listings and 7-day moving average, last 30 days (window) | 8.586 | 8.282 | 10.173 | **9.014** | [indexed](plans/indexed/R18.txt) |
| R19 | READ | Listings with 3 or more open reports (moderation queue) | 21.826 | 38.738 | 22.705 | **27.756** | [indexed](plans/indexed/R19.txt) |
| R20 | READ | Top 10 buyers by total spend | 10.045 | 9.795 | 9.727 | **9.856** | [indexed](plans/indexed/R20.txt) |
| R21 | READ | Active listings that nobody has favourited or messaged (double anti-join) | 1.801 | 1.751 | 2.087 | **1.880** | [indexed](plans/indexed/R21.txt) |
| R22 | READ | Sell-through rate per parent category (conditional aggregation) | 65.432 | 60.985 | 59.059 | **61.825** | [indexed](plans/indexed/R22.txt) |
| R23 | READ | Sellers with 10+ sales and rating above the platform average (JOIN on a one-row aggregate) | 48.539 | 38.028 | 69.425 | **51.997** | [indexed](plans/indexed/R23.txt) |
| R24 | READ | Active listings priced 50% above their category average (CTE + join) | 53.136 | 51.315 | 28.165 | **44.205** | [indexed](plans/indexed/R24.txt) |
| R25 | READ | Average seller reply time to a buyer's first message, top 10 fastest (CTE) | 209.043 | 214.070 | 239.120 | **220.744** | [indexed](plans/indexed/R25.txt) |
| W01 | WRITE | Post a new listing together with its cover image (data-modifying CTE) | 3.540 | 1.817 | 1.545 | **2.301** | [indexed](plans/indexed/W01.txt) |
| W02 | WRITE | Price drop: cut all of seller 123's active listings by 10% | 1.085 | 1.126 | 0.825 | **1.012** | [indexed](plans/indexed/W02.txt) |
| W03 | WRITE | Mark a listing as sold and record the transaction (atomic CTE) | 1.346 | 1.479 | 1.366 | **1.397** | [indexed](plans/indexed/W03.txt) |
| W04 | WRITE | Buyer leaves a 5-star review on a sale that has no review yet | 0.667 | 0.613 | 0.840 | **0.707** | [indexed](plans/indexed/W04.txt) |
| W05 | WRITE | Housekeeping: delete stale favourites of listings that are no longer active | 64.856 | 68.643 | 66.788 | **66.762** | [indexed](plans/indexed/W05.txt) |

### 2.3 Comparison (average of 3 runs)

| ID | Type | Baseline average (ms) | Indexed average (ms) | Speed-up |
|---|---|---|---|---|
| R01 | READ | 27.00 | 1.71 | 15.8x |
| R02 | READ | 42.51 | 40.76 | 1.0x |
| R03 | READ | 23.27 | 4.62 | 5.0x |
| R04 | READ | 55.46 | 2.72 | 20.4x |
| R05 | READ | 29.48 | 30.89 | 1.0x |
| R06 | READ | 52.31 | 51.25 | 1.0x |
| R07 | READ | 37.03 | 10.91 | 3.4x |
| R08 | READ | 14.74 | 13.47 | 1.1x |
| R09 | READ | 151.45 | 130.30 | 1.2x |
| R10 | READ | 0.38 | 0.32 | 1.2x |
| R11 | READ | 45.82 | 0.25 | 186.2x |
| R12 | READ | 92.74 | 43.20 | 2.1x |
| R13 | READ | 11.43 | 10.97 | 1.0x |
| R14 | READ | 62.27 | 60.15 | 1.0x |
| R15 | READ | 29.65 | 29.62 | 1.0x |
| R16 | READ | 59.84 | 44.81 | 1.3x |
| R17 | READ | 148.63 | 134.72 | 1.1x |
| R18 | READ | 25.64 | 9.01 | 2.8x |
| R19 | READ | 23.31 | 27.76 | 0.8x |
| R20 | READ | 9.77 | 9.86 | 1.0x |
| R21 | READ | 123.84 | 1.88 | 65.9x |
| R22 | READ | 66.65 | 61.83 | 1.1x |
| R23 | READ | 37.97 | 52.00 | 0.7x |
| R24 | READ | 77.61 | 44.20 | 1.8x |
| R25 | READ | 256.61 | 220.74 | 1.2x |
| W01 | WRITE | 1.15 | 2.30 | 0.5x |
| W02 | WRITE | 11.44 | 1.01 | 11.3x |
| W03 | WRITE | 0.80 | 1.40 | 0.6x |
| W04 | WRITE | 0.60 | 0.71 | 0.8x |
| W05 | WRITE | 72.83 | 66.76 | 1.1x |

Total over all 30 queries: **1592 ms baseline -> 1110 ms indexed**.

## 3. What changed in the plans

Biggest wins:

- **R11 seller inbox (45.8 ms -> 0.25 ms, 186x).** Baseline sequentially scanned `listings` and `messages` (the latest-message LATERAL join had no index). `idx_listings_seller` finds the seller's listings and `idx_messages_conv_sent (conversation_id, sent_at DESC)` returns the latest message with a single index probe per chat.
- **R21 never-favourited listings (123.8 ms -> 1.88 ms, 66x).** The two LEFT JOIN ... IS NULL anti-joins can now probe `idx_favorites_listing`, and with LIMIT 20 the planner walks `idx_listings_created_at` and stops early instead of scanning all of `listings`.
- **R01 listings by city (27.0 ms -> 1.71 ms) and R04 keyword search (55.5 ms -> 2.72 ms).** Both are "newest N" queries. Postgres reads `listings` in `created_at` order through the index and stops after the LIMIT, so no full scan and no sort is needed.
- **W02 price drop (11.4 ms -> 1.01 ms).** Sequential scan replaced by an index scan on `idx_listings_seller`.
- **R03, R07, R18, R12, R24.** Range filters and anti-joins now use `idx_listings_created_at`, `idx_listings_seller`, the partial index on active prices and the partial index on unread messages (2x to 5x).

JOIN rewrites made for CP3 (results verified identical to the earlier subquery versions): R07, R21 and W04 use `LEFT JOIN ... IS NULL` anti-joins instead of `NOT EXISTS`; R10 joins `listing_images` instead of a scalar subquery; R23 joins a one-row aggregate instead of a subquery in `HAVING`. The anti-join tests the join-key column (`l.seller_id IS NULL`) so PostgreSQL plans a real Anti Join, which lets R07 stop early with LIMIT once indexed.

No meaningful improvement (and why):

- **R02, R05, R06, R08, R09, R13, R14, R15, R17, R19, R20, R22, R23, R25.** These aggregate most or all of a table (GROUP BY over every sale, every favourite, every message). A sequential scan is already the cheapest plan, so the planner correctly ignores the new indexes. Speeding these up would need pre-aggregated or materialized data (for example a `favourite_count` column or a materialized view), not more indexes. Differences of a few ms either way (for example R19 and R23) are run-to-run noise.
- **R25 (221 ms) and R09 (130 ms)** are the slowest queries. R25 aggregates all 150,000 messages to find first replies; R09 counts 170,000 favourites before sorting.
- **W05 delete stale favourites (67 ms).** The cost is the scan and join of 170,000 favourites against listings; it is a batch housekeeping job, not a user-facing request.

Slight regressions on W01 and W03 (about 1 ms) are the price of maintaining 18 extra indexes on every insert or update, which is acceptable for a read-heavy marketplace.

## 4. Index cost

Every extra index slows writes and uses disk. The set in `07_indexes.sql` was chosen only from columns that appeared in a Seq Scan on the baseline plans of the queries above; indexes that did not help any query (for example the trigram index `idx_listings_title_trgm` is not picked for R04 because the pattern matches about 6% of rows and the `created_at` order is cheaper with LIMIT) are candidates to drop in production.

## 5. Conclusion & CP5 Next Steps

Indexing foreign-key and filter columns cut the filter-heavy queries by 2x to 186x, while whole-table analytics queries stay in the 10-260 ms range at this scale and require pre-aggregated summary tables or materialized views to scale further.

To address this bottleneck, **CP5 (`08_triggers_and_views.sql`)** introduces:
1. **Materialized Views (`mv_top_favourited_listings`, `mv_seller_performance`, `mv_category_summary`)**: Resolves the slow full-table scans for R09 (130 ms) and R25 (221 ms), reducing median execution to <1 ms with support for concurrent background refreshes (`REFRESH MATERIALIZED VIEW CONCURRENTLY`).
2. **Business Rule Triggers**: Automates listing status synchronization on sales, verifies review participants, and prevents invalid self-favourites and self-conversations.
3. **Transactional Stored Procedures**: ACID-compliant sales completion with row-level locks (`sp_complete_sale`) and bulk message-read procedures (`sp_mark_conversation_read`).
