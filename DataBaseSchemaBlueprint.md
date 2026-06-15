# Personal Finance & Budget App Database Schema Blueprint
## Reference Document: "Budget App SQL Schema"

This document serves as the definitive reference for the relational database schema of the Personal Finance App. The single source of truth for this schema is the SQL definition in [supabase_schema.sql](file:///c:/Users/yohnathanc/budget-app/supabase_schema.sql).

All primary keys (`id`) across tables use a unique 20-character alphanumeric string. For data migrated from Google Sheets, these are generated via the Google Apps Script engine to preserve integrity.

---

## 1. System Architecture Overview

* **Frontend:** Flutter (iOS, Android, and Web)
* **Backend/Database:** Supabase (PostgreSQL with Row-Level Security)
* **Data Migration Pipeline:** Google Sheets → Google Apps Script → Supabase REST API (PostgREST)
* **Backup/Source Ledger:** Google Sheets spreadsheet

---

## 2. Table Schemas & Data Dictionaries

### 2.1 Accounts Table (`accounts`)
Tracks individual financial accounts, credit cards, and investment sweep cash containers.

| Column Name | PostgreSQL Data Type | Constraints / Default | Description |
| :--- | :--- | :--- | :--- |
| `id` | `character varying(20)` | `PRIMARY KEY`, `NOT NULL` | Unique identifier (20-char alphanumeric) |
| `name` | `character varying(255)` | `NOT NULL` | Human-readable name (e.g., "Chase Checking") |
| `type` | `character varying(50)` | `NOT NULL` | Account type (`checking`, `savings`, `credit_card`, `investment`, `crypto_wallet`) |
| `institution` | `character varying(255)` | `NOT NULL` | Bank or platform name |
| `currency` | `character varying(5)` | `NOT NULL` | Base currency code or crypto ticker (e.g., "USD", "SOL") |
| `current_balance`| `numeric` | `NOT NULL`, `DEFAULT 0.00` | Real-time liquid cash balance |
| `status` | `character varying(20)` | `NOT NULL`, `DEFAULT 'active'`| Account status (`active`, `archived`) |
| `account_group` | `character varying(50)` | `NOT NULL` | Category group (`liquid_assets`, `credit`, `capital`, `retirement`) |
| `created_at` | `timestamp with time zone`| `NOT NULL`, `DEFAULT now()` | Record creation timestamp |
| `updated_at` | `timestamp with time zone`| `DEFAULT now()` | Last update timestamp |

### 2.2 Account Snapshots Table (`account_snapshots`)
Tracks historical granular balances of individual accounts over time for net worth growth charting.

| Column Name | PostgreSQL Data Type | Constraints / Default | Description |
| :--- | :--- | :--- | :--- |
| `id` | `character varying(20)` | `PRIMARY KEY`, `NOT NULL` | Unique snapshot identifier |
| `account_id` | `character varying(20)` | `NOT NULL`, `FOREIGN KEY` | References `accounts(id)` |
| `snapshot_date`| `date` | `NOT NULL` | Date of the balance snapshot (YYYY-MM-DD) |
| `balance` | `numeric` | `NOT NULL` | Historical balance on this specific date |
| `currency` | `character varying(5)` | `NOT NULL` | Currency of the snapshotted balance |
| `created_at` | `timestamp with time zone`| `NOT NULL`, `DEFAULT now()` | Snapshot creation timestamp |

### 2.3 Categories Table (`categories`)
Hierarchical categorization for tracking expenses, income, and transfers.

| Column Name | PostgreSQL Data Type | Constraints / Default | Description |
| :--- | :--- | :--- | :--- |
| `id` | `character varying(20)` | `PRIMARY KEY`, `NOT NULL` | Unique category identifier |
| `name` | `character varying(255)` | `NOT NULL` | Category label (e.g., "Dining Out") |
| `type` | `character varying(50)` | `NOT NULL` | Category type (`income`, `expense`, `transfer`, `reimbursement`, `investment`) |
| `parent_id` | `character varying(20)` | `FOREIGN KEY`, `NULLABLE` | References `categories(id)` for nested subcategories |
| `icon` | `character varying(255)` | `NULLABLE` | Glyph identifier name for UI rendering |
| `color_hex` | `character varying(7)` | `NULLABLE` | Color hex code for UI charts (`#RRGGBB`) |
| `created_at` | `timestamp with time zone`| `DEFAULT now()` | Record creation timestamp |

### 2.4 Transactions Table (`transactions`)
The core ledger recording all physical cash movements entering or leaving an account. Decoupled from asset units.

| Column Name | PostgreSQL Data Type | Constraints / Default | Description |
| :--- | :--- | :--- | :--- |
| `id` | `character varying(20)` | `PRIMARY KEY`, `NOT NULL` | Unique transaction identifier |
| `account_id` | `character varying(20)` | `NOT NULL`, `FOREIGN KEY` | References `accounts(id)` |
| `category_id` | `character varying(20)` | `NOT NULL`, `FOREIGN KEY` | References `categories(id)` |
| `amount` | `numeric` | `NOT NULL` | Negative for expenses/outflows, positive for inflows |
| `currency` | `character varying(5)` | `NOT NULL` | Currency of the cash flow |
| `exchange_rate`| `numeric` | `NOT NULL`, `DEFAULT 1.000000` | Rate used relative to account base currency |
| `date` | `timestamp with time zone`| `NOT NULL` | Financial transaction date |
| `description` | `text` | `NOT NULL` | Merchant name, details, or notes |
| `status` | `character varying(20)` | `DEFAULT 'cleared'` | Transaction clearance (`pending`, `cleared`, `flagged`) |
| `is_recurring` | `boolean` | `DEFAULT false` | True if generated from a recurring template |
| `recurring_id` | `character varying(20)` | `FOREIGN KEY`, `NULLABLE` | References `recurring_transactions(id)` |
| `tags` | `text[]` | `DEFAULT '{}'::text[]` | Labels for tracking (e.g., transfer linking tokens) |
| `sheets_row_id`| `integer` | `NULLABLE` | Google Sheets row identifier for data auditing |
| `created_at` | `timestamp with time zone`| `DEFAULT now()` | Record creation timestamp |

### 2.5 Asset Transactions Table (`asset_transactions`)
Tracks trade executions (buys, sells, stock splits) for investment holdings.

| Column Name | PostgreSQL Data Type | Constraints / Default | Description |
| :--- | :--- | :--- | :--- |
| `id` | `character varying(20)` | `PRIMARY KEY`, `NOT NULL` | Unique trade transaction ID |
| `transaction_id`| `character varying(20)` | `FOREIGN KEY`, `NULLABLE` | References `transactions(id)` (cash flow backing the trade) |
| `account_id` | `character varying(20)` | `NOT NULL`, `FOREIGN KEY` | References `accounts(id)` (brokerage container) |
| `asset_id` | `character varying(20)` | `NOT NULL`, `FOREIGN KEY` | References `assets(id)` |
| `type` | `character varying(50)` | `NOT NULL` | Trade action (`buy`, `sell`, `dividend_reinvest`, `split`, `reward`) |
| `quantity` | `numeric` | `NOT NULL` | Amount of shares/units traded |
| `unit_price` | `numeric` | `NOT NULL` | Market price per unit at execution |
| `executed_at` | `timestamp with time zone`| `NOT NULL` | Execution date and timestamp |

### 2.6 Holdings Table (`holdings`)
Tracks current aggregated positions. Updated as asset transactions are logged.

| Column Name | PostgreSQL Data Type | Constraints / Default | Description |
| :--- | :--- | :--- | :--- |
| `id` | `character varying(20)` | `PRIMARY KEY`, `NOT NULL` | Unique holding position ID |
| `account_id` | `character varying(20)` | `NOT NULL`, `FOREIGN KEY` | References `accounts(id)` |
| `asset_id` | `character varying(20)` | `NOT NULL`, `FOREIGN KEY` | References `assets(id)` |
| `quantity` | `numeric` | `NOT NULL` | Current net units held |
| `avg_buy_price`| `numeric` | `NOT NULL` | Weighted average cost basis per unit |
| `updated_at` | `timestamp with time zone`| `DEFAULT now()` | Last inventory balance sync timestamp |

* **Unique Constraint:** `holdings_account_id_asset_id_key` on (`account_id`, `asset_id`).

### 2.7 Recurring Transactions Table (`recurring_transactions`)
Recurring templates specifying repeating transaction generation rules.

| Column Name | PostgreSQL Data Type | Constraints / Default | Description |
| :--- | :--- | :--- | :--- |
| `id` | `character varying(20)` | `PRIMARY KEY`, `NOT NULL` | Unique rule template ID |
| `account_id` | `character varying(20)` | `NOT NULL`, `FOREIGN KEY` | References `accounts(id)` |
| `category_id` | `character varying(20)` | `NOT NULL`, `FOREIGN KEY` | References `categories(id)` |
| `amount` | `numeric` | `NOT NULL` | Repeating transaction base amount |
| `frequency` | `character varying(50)` | `NOT NULL` | Frequency (`daily`, `weekly`, `biweekly`, `monthly`, `yearly`) |
| `interval` | `integer` | `NOT NULL`, `DEFAULT 1` | Period multiplier (e.g. interval `2` = bi-frequency) |
| `start_date` | `date` | `NOT NULL` | Rule commencement date |
| `end_date` | `date` | `NULLABLE` | Rule expiration date |
| `next_due_date`| `date` | `NOT NULL` | Calculated upcoming execution date |
| `status` | `character varying(20)` | `DEFAULT 'active'` | State (`active`, `paused`, `completed`) |
| `description` | `character varying(255)` | `NOT NULL` | Default transaction memo/description |

### 2.8 Budget Targets Table (`budget_targets`)
Sets period spending limits or saving floors.

| Column Name | PostgreSQL Data Type | Constraints / Default | Description |
| :--- | :--- | :--- | :--- |
| `id` | `character varying(20)` | `PRIMARY KEY`, `NOT NULL` | Unique target ID |
| `category_id` | `character varying(20)` | `NOT NULL`, `FOREIGN KEY` | References `categories(id)` |
| `target_amount`| `numeric` | `NOT NULL` | Maximum budget threshold amount |
| `period` | `character varying(20)` | `NOT NULL` | Recurrence period (`monthly`, `quarterly`, `yearly`) |
| `start_date` | `date` | `NOT NULL` | Allocation start date boundary |
| `end_date` | `date` | `NOT NULL` | Allocation end date boundary |
| `created_at` | `timestamp with time zone`| `DEFAULT now()` | Record creation timestamp |

### 2.9 System Settings Table (`system_settings`)
Global metadata, system configuration parameters, and constants.

| Column Name | PostgreSQL Data Type | Constraints / Default | Description |
| :--- | :--- | :--- | :--- |
| `id` | `character varying(20)` | `PRIMARY KEY`, `NOT NULL` | Unique setting ID |
| `config_key` | `character varying(255)` | `NOT NULL` | Unique lookup name (e.g., `base_currency`) |
| `config_value` | `text` | `NOT NULL` | Stringified value or settings JSON block |
| `data_type` | `character varying(50)` | `NOT NULL` | Parameter datatype (`string`, `int`, `boolean`, `json`) |
| `description` | `text` | `NULLABLE` | Explanatory note of what the config manages |
| `updated_at` | `timestamp with time zone`| `DEFAULT now()` | Last adjustment timestamp |

* **Unique Constraint:** `system_settings_config_key_key` on (`config_key`).

### 2.10 Assets Table (`assets`)
Reference list of supported assets for stock, ETF, and crypto investment holdings.

| Column Name | PostgreSQL Data Type | Constraints / Default | Description |
| :--- | :--- | :--- | :--- |
| `id` | `character varying(20)` | `PRIMARY KEY`, `NOT NULL` | Unique asset ID |
| `symbol` | `character varying(50)` | `NOT NULL` | Ticker symbol (e.g., `MSFT`, `BTC`) |
| `name` | `character varying(255)` | `NOT NULL` | Company or coin full name |
| `type` | `character varying(50)` | `NOT NULL` | Asset security class (`crypto`, `stock`, `etf`) |

---

## 3. Row-Level Security (RLS) & Relational Integrity

1. **Row-Level Security (RLS):** All tables have RLS enabled (via `ALTER TABLE ENABLE ROW LEVEL SECURITY`). Proper RLS policies should govern row visibility relative to the user context.
2. **Delete Cascading:** Direct table deletions of categories, accounts, or assets with transaction history are restricted via database foreign keys to maintain ledger tracking coherence.
3. **Double-Entry Linking:** Transfers use matched positive/negative entries in `transactions` linked with matching hash tokens in the `tags` array column.
4. **Brokerage Asset Value Evaluation:** Total asset holdings value for an account is derived dynamically using:
   `Total Value = account.current_balance + Sum(holding.quantity * asset_current_price)`