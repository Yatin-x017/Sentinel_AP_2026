# Sentinel - OLX Buy & Sell Database & Backend

**Team T0058 (Sentinel)**  
*College Capstone Project: Advanced Programming (AP) & Data Engineering (DBMS)*  
**Team Members / Contributors:** Dhaval Sethi, Puneet Goyal, Yatin  
**Target Platform:** PostgreSQL 14+ / Python 3  

---

## 📌 Project Overview

**Sentinel (OLX Buy & Sell)** is a scalable, enterprise-grade relational database backend modeled for a classifieds marketplace. The platform enables users to post listings across a hierarchical category taxonomy, browse location-aware products, save favourites, negotiate via real-time offers and messaging, complete sales, leave two-way transaction reviews, and flag fraudulent content through moderation reports.

The database architecture has been developed and validated through five rigorous engineering checkpoints (**CP1 through CP5**).

---

## 🗂️ Engineering Checkpoints

### 1. [CP1 - Normalization](dbms/01_normalization.md)
* Deconstructed an unnormalized, flat spreadsheet (`LISTING_SHEET`) prone to insertion, update, and deletion anomalies.
* Step-by-step mathematical decomposition through **1NF**, **2NF**, and **3NF**.
* Validated functional dependencies under **Boyce-Codd Normal Form (BCNF)** across all 13 relations.
* Documented controlled, intentional denormalizations (`transactions.seller_id` and `reviews.reviewee_id`) for audit snapshots and indexing efficiency.

### 2. [CP2 - Relational Schema & ER Diagram](dbms/02_er_diagram.md)
* Complete DDL in [`dbms/03_schema.sql`](dbms/03_schema.sql) with strict constraints (`CHECK`, `FOREIGN KEY`, `ON DELETE CASCADE`, `UNIQUE`).
* 13 core relational tables:
  * **Geography**: `states`, `cities`
  * **Identity**: `users`
  * **Taxonomy**: `categories` (self-referencing recursive tree)
  * **Marketplace**: `listings`, `listing_images`, `favorites`
  * **Communication**: `conversations`, `messages`
  * **Commerce**: `offers`, `transactions`, `reviews`
  * **Safety**: `reports`
* Comprehensive Entity-Relationship diagrams available in Mermaid, Graphviz DOT ([`02_er_diagram.dot`](dbms/02_er_diagram.dot)), SVG ([`02_er_diagram.svg`](dbms/02_er_diagram.svg)), and PNG ([`02_er_diagram.png`](dbms/02_er_diagram.png)).

### 3. [CP3 - 30 Real-World Business Queries](dbms/04_queries.sql)
A test suite of 30 production queries covering advanced SQL paradigms:
* **25 Read Queries (R01–R25)**:
  * `JOIN LATERAL` subqueries for latest message in seller inboxes (R11).
  * Window functions (`ROW_NUMBER() OVER PARTITION` in R17, 7-day moving averages in R18).
  * Common Table Expressions (Recursive CTE for category hierarchies in R15).
  * Multi-dimensional aggregations (`GROUP BY ROLLUP` in R14, conditional `FILTER` in R22).
  * Subquery anti-joins with single and double `NOT EXISTS` (R07, R21).
* **5 Write Queries (W01–W05)**:
  * Data-modifying CTEs for multi-table atomic inserts (W01).
  * Atomic sale checkout updates and transaction creation (W03).
  * Batch housekeeping using `DELETE ... USING` (W05).

### 4. [CP4 - Index Tuning & Performance Profiling](dbms/05_query_timings.md)
* Profiling harness built with Python ([`dbms/run_timings.py`](dbms/run_timings.py)) running `EXPLAIN (ANALYZE, BUFFERS)` over 1 warm-up and 5 timed runs per query.
* Seeded with **100,000 listings**, **20,000 users**, **300,000 images**, and **150,000 messages** ([`dbms/06_seed_data.sql`](dbms/06_seed_data.sql)).
* Targeted indexing ([`dbms/07_indexes.sql`](dbms/07_indexes.sql)) including composite indexes, partial indexes, and trigram full-text search (`pg_trgm`).
* **Key Speedup Highlights**:
  * **R11 (Seller Inbox LATERAL)**: **133.1x faster** (33.1 ms $\rightarrow$ 0.25 ms)
  * **R21 (Un-engaged Listings Anti-join)**: **49.4x faster** (95.2 ms $\rightarrow$ 1.93 ms)
  * **R01 (Geographic Listing Feed)**: **16.7x faster** (31.4 ms $\rightarrow$ 1.88 ms)
  * **R04 (Keyword Search)**: **14.9x faster** (41.0 ms $\rightarrow$ 2.75 ms)
  * **W02 (Bulk Price Adjustment)**: **12.4x faster** (9.1 ms $\rightarrow$ 0.73 ms)

### 5. [CP5 - Triggers, Stored Procedures & Materialized Views](dbms/08_triggers_and_views.sql)
* **Materialized Views**:
  * `mv_top_favourited_listings`: Eliminates full table scans on R09 (148 ms $\rightarrow$ <1 ms).
  * `mv_seller_performance`: Pre-computes response time analytics and ratings for R25 & R05 (230 ms $\rightarrow$ <1 ms).
  * `mv_category_summary`: Pre-aggregates sell-through rates and active pricing distributions.
* **Integrity Triggers**:
  * `trg_prevent_self_favorite`: Prohibits sellers from favouriting their own listings.
  * `trg_prevent_self_conversation`: Blocks sellers from initiating buyer chat threads with themselves.
  * `trg_sync_listing_sold`: Synchronizes listing status to `'sold'` automatically upon transaction insertion.
  * `trg_validate_review_parties`: Enforces that only verified buyers/sellers of a completed transaction can submit ratings.
* **Stored Procedures**:
  * `sp_complete_sale`: Concurrency-safe atomic checkout using row-level locking (`FOR UPDATE`) to prevent race conditions between simultaneous buyers.
  * `sp_mark_conversation_read`: Bulk updates unread conversation states.
  * `sp_refresh_analytics`: Concurrent asynchronous view refresh (`REFRESH MATERIALIZED VIEW CONCURRENTLY`).

---

## 🚀 Quickstart & Setup Guide

### Prerequisites
* PostgreSQL 14+ installed and running
* Python 3.8+ (for running performance timings)

### 1. Database Initialization
```bash
# Create database
createdb olx

# Execute DDL schema (13 tables)
psql -d olx -f dbms/03_schema.sql

# Load deterministic seed dataset (20k users, 100k listings)
psql -d olx -f dbms/06_seed_data.sql
```

### 2. Apply Indexes, Triggers, and Views
```bash
# Add composite & partial indexes
psql -d olx -f dbms/07_indexes.sql

# Add triggers, stored procedures, and materialized views
psql -d olx -f dbms/08_triggers_and_views.sql
```

### 3. Run Query Benchmarks
```bash
# Run baseline plan benchmark
python3 dbms/run_timings.py baseline

# Run indexed plan benchmark
python3 dbms/run_timings.py indexed
```

All execution plans will be recorded in `dbms/plans/baseline/` and `dbms/plans/indexed/` with timing summaries in `summary.csv`.
