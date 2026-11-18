# CP4 - Query timings and execution plans

Team T0058 (Sentinel) - DBMS project 18. OLX Buy & Sell

## 1. Setup

| Item | Value |
|---|---|
| DBMS | PostgreSQL 16.15 (Ubuntu), default configuration |
| Schema | `03_schema.sql` (13 tables) |
| Data | `06_seed_data.sql`, deterministic synthetic data (setseed 0.42) |
| Indexes | baseline = primary keys and UNIQUE constraints only; indexed = plus `07_indexes.sql` |
| Method | `run_timings.py`: `EXPLAIN (ANALYZE, BUFFERS)`, 1 warm-up run, then median of 5 runs |
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

Timings depend on the machine; the relative improvement and the plan shapes are what matter. Full plans are stored in `plans/baseline/` and `plans/indexed/` (one file per query, plus `summary.csv`).

## 2. Results (median execution time, milliseconds)

| ID | Query | Baseline | Indexed | Speed-up | Plans |
|---|---|---|---|---|---|
| R01 | Newest active listings in Gurugram with seller name (JOIN x3) | 31.38 | 1.88 | 16.7x | [baseline](plans/baseline/R01.txt) / [indexed](plans/indexed/R01.txt) |
| R02 | Active listing count per top-level category (self-join + GROUP BY) | 32.73 | 21.18 | 1.5x | [baseline](plans/baseline/R02.txt) / [indexed](plans/indexed/R02.txt) |
| R03 | Negotiable smartphones priced 10,000-40,000 (filter + sort) | 18.90 | 5.13 | 3.7x | [baseline](plans/baseline/R03.txt) / [indexed](plans/indexed/R03.txt) |
| R04 | Keyword search on title (pattern match) | 40.98 | 2.75 | 14.9x | [baseline](plans/baseline/R04.txt) / [indexed](plans/indexed/R04.txt) |
| R05 | Top 10 sellers by number of completed sales (JOIN + GROUP BY) | 23.56 | 24.79 | 1.0x | [baseline](plans/baseline/R05.txt) / [indexed](plans/indexed/R05.txt) |
| R06 | Average price per category with more than 500 listings (HAVING) | 42.20 | 44.50 | 0.9x | [baseline](plans/baseline/R06.txt) / [indexed](plans/indexed/R06.txt) |
| R07 | Users who have never posted a listing (NOT EXISTS) | 33.57 | 6.02 | 5.6x | [baseline](plans/baseline/R07.txt) / [indexed](plans/indexed/R07.txt) |
| R08 | Best-rated sellers with at least 5 reviews (aggregate) | 13.02 | 13.56 | 1.0x | [baseline](plans/baseline/R08.txt) / [indexed](plans/indexed/R08.txt) |
| R09 | Ten most favourited active listings | 145.47 | 148.81 | 1.0x | [baseline](plans/baseline/R09.txt) / [indexed](plans/indexed/R09.txt) |
| R10 | One user's favourites with first image (JOIN + subquery) | 0.35 | 0.32 | 1.1x | [baseline](plans/baseline/R10.txt) / [indexed](plans/indexed/R10.txt) |
| R11 | Seller inbox: chats on my listings with the latest message (LATERAL) | 33.13 | 0.25 | 133.1x | [baseline](plans/baseline/R11.txt) / [indexed](plans/indexed/R11.txt) |
| R12 | Unread messages per conversation for user 100 (buyer or seller) | 99.50 | 41.86 | 2.4x | [baseline](plans/baseline/R12.txt) / [indexed](plans/indexed/R12.txt) |
| R13 | Monthly sales revenue for the last 12 months (date_trunc) | 9.80 | 9.53 | 1.0x | [baseline](plans/baseline/R13.txt) / [indexed](plans/indexed/R13.txt) |
| R14 | Active listings and average price by state and city (ROLLUP) | 50.02 | 48.49 | 1.0x | [baseline](plans/baseline/R14.txt) / [indexed](plans/indexed/R14.txt) |
| R15 | All sub-categories of Electronics with listing counts (recursive CTE) | 24.98 | 26.20 | 1.0x | [baseline](plans/baseline/R15.txt) / [indexed](plans/indexed/R15.txt) |
| R16 | Accepted offers: biggest discounts versus asking price | 42.59 | 36.23 | 1.2x | [baseline](plans/baseline/R16.txt) / [indexed](plans/indexed/R16.txt) |
| R17 | Three most expensive active listings in every leaf category (window) | 128.69 | 105.97 | 1.2x | [baseline](plans/baseline/R17.txt) / [indexed](plans/indexed/R17.txt) |
| R18 | Daily new listings and 7-day moving average, last 30 days (window) | 18.90 | 2.73 | 6.9x | [baseline](plans/baseline/R18.txt) / [indexed](plans/indexed/R18.txt) |
| R19 | Listings with 3 or more open reports (moderation queue) | 20.39 | 20.15 | 1.0x | [baseline](plans/baseline/R19.txt) / [indexed](plans/indexed/R19.txt) |
| R20 | Top 10 buyers by total spend | 8.62 | 8.35 | 1.0x | [baseline](plans/baseline/R20.txt) / [indexed](plans/indexed/R20.txt) |
| R21 | Active listings that nobody has favourited or messaged (double NOT EXISTS) | 95.24 | 1.93 | 49.4x | [baseline](plans/baseline/R21.txt) / [indexed](plans/indexed/R21.txt) |
| R22 | Sell-through rate per parent category (conditional aggregation) | 46.23 | 47.16 | 1.0x | [baseline](plans/baseline/R22.txt) / [indexed](plans/indexed/R22.txt) |
| R23 | Sellers with 10+ sales and rating above the platform average (subquery) | 26.44 | 25.50 | 1.0x | [baseline](plans/baseline/R23.txt) / [indexed](plans/indexed/R23.txt) |
| R24 | Active listings priced 50% above their category average (CTE + join) | 57.03 | 21.82 | 2.6x | [baseline](plans/baseline/R24.txt) / [indexed](plans/indexed/R24.txt) |
| R25 | Average seller reply time to a buyer's first message, top 10 fastest (CTE) | 261.63 | 230.12 | 1.1x | [baseline](plans/baseline/R25.txt) / [indexed](plans/indexed/R25.txt) |
| W01 | Post a new listing together with its cover image (data-modifying CTE) | 1.20 | 1.78 | 0.7x | [baseline](plans/baseline/W01.txt) / [indexed](plans/indexed/W01.txt) |
| W02 | Price drop: cut all of seller 123's active listings by 10% | 9.10 | 0.73 | 12.4x | [baseline](plans/baseline/W02.txt) / [indexed](plans/indexed/W02.txt) |
| W03 | Mark a listing as sold and record the transaction (atomic CTE) | 1.00 | 1.48 | 0.7x | [baseline](plans/baseline/W03.txt) / [indexed](plans/indexed/W03.txt) |
| W04 | Buyer leaves a 5-star review on a sale that has no review yet | 0.76 | 0.72 | 1.1x | [baseline](plans/baseline/W04.txt) / [indexed](plans/indexed/W04.txt) |
| W05 | Housekeeping: delete stale favourites of listings that are no longer active | 58.29 | 58.41 | 1.0x | [baseline](plans/baseline/W05.txt) / [indexed](plans/indexed/W05.txt) |

## 3. What changed in the plans

Biggest wins:

- **R11 seller inbox (33.1 ms -> 0.25 ms, 133x).** Baseline sequentially scanned `listings` and `messages` (the latest-message LATERAL had no index). `idx_listings_seller` finds the seller's listings and `idx_messages_conv_sent (conversation_id, sent_at DESC)` returns the latest message with a single index probe per chat.
- **R21 never-favourited listings (95.2 ms -> 1.9 ms, 49x).** The anti-joins can now probe `idx_favorites_listing`, and with LIMIT 20 the planner walks `idx_listings_created_at` and stops early instead of scanning all of `listings`.
- **R01 listings by city (31.4 ms -> 1.9 ms, 17x) and R04 keyword search (41.0 ms -> 2.8 ms, 15x).** Both are "newest N" queries. Postgres reads `listings` in `created_at` order through the index and stops after the LIMIT, so no full scan and no sort is needed.
- **W02 price drop (9.1 ms -> 0.7 ms, 12x).** Sequential scan replaced by a bitmap index scan on `idx_listings_seller`.
- **R18 (6.9x), R07 (5.6x), R03 (3.7x), R24 (2.6x), R12 (2.4x).** Range filters and anti-joins now use `idx_listings_created_at`, `idx_listings_seller`, the partial index on active prices and the partial index on unread messages.

No improvement (and why):

- **R05, R06, R08, R09, R13, R14, R15, R17, R19, R20, R22, R23, R25.** These aggregate most or all of a table (GROUP BY over every sale, every favourite, every message). A sequential scan is already the cheapest plan, so the planner correctly ignores the new indexes. Speeding these up would need pre-aggregated or materialized data (for example a `favourite_count` column or a materialized view), not more indexes.
- **R25 (230 ms) and R09 (149 ms)** are the slowest queries. R25 aggregates all 150,000 messages to find first replies; R09 counts 170,000 favourites before sorting.
- **W05 delete stale favourites (58 ms).** The cost is the scan and join of 170,000 favourites against listings; it is a batch housekeeping job, not a user-facing request.

Slight regressions on W01 and W03 (about 0.5 ms) are the price of maintaining 18 extra indexes on every insert or update, which is acceptable for a read-heavy marketplace.

## 4. Index cost

Every extra index slows writes and uses disk. The set in `07_indexes.sql` was chosen only from columns that appeared in a Seq Scan on the baseline plans of queries above; indexes that did not help any query (for example the trigram index `idx_listings_title_trgm` is not picked for R04 because the pattern matches about 6% of rows and the `created_at` order is cheaper with LIMIT) are candidates to drop in production.

## 5. Conclusion & CP5 Next Steps

Indexing foreign-key and filter columns cut the filter-heavy queries by 2x to 133x, while whole-table analytics queries stay in the 10-230 ms range at this scale and require pre-aggregated summary tables or materialized views to scale further.

To address this bottleneck, **CP5 (`08_triggers_and_views.sql`)** introduces:
1. **Materialized Views (`mv_top_favourited_listings`, `mv_seller_performance`, `mv_category_summary`)**: Resolves the slow full-table scans for R09 (148 ms) and R25 (230 ms), reducing median execution to <1 ms with support for concurrent background refreshes (`REFRESH MATERIALIZED VIEW CONCURRENTLY`).
2. **Business Rule Triggers**: Automates listing status synchronization on sales, verifies review participants, and prevents invalid self-favourites and self-conversations.
3. **Transactional Stored Procedures**: ACID-compliant sales completion with row-level locks (`sp_complete_sale`) and bulk message-read procedures (`sp_mark_conversation_read`).
