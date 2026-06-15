# Personal Finance & Budget App Database Schema Blueprint
## Reference Document: "Budget App Blueprint: Sheets to App"

This document serves as the definitive reference for migrating from a legacy Google Sheets implementation to a normalized, enterprise-grade relational schema on Firebase/Firestore, with an eventual target of a SQL-based relational database. 

All primary keys (`id`) across collections use a unique 20-character alphanumeric string. For data migrated from Google Sheets, these are deterministically or sequentially generated via Google Apps Script to maintain reference integrity during the upload pipeline.

---

## 1. System Architecture Overview

- **Frontend:** Flutter (Cross-platform iOS, Android, and Web)
- **Backend/Database:** Firebase Firestore (NoSQL structured with relational paradigms)
- **Data Migration Pipeline:** Google Sheets → Google Apps Script Pipeline (generates 20-char IDs) → Firestore
- **Backup Strategy:** Google Sheets as human-readable manual audit and historical ledger

---

## 2. Table Schemas & Data Dictionaries

### 2.1 Accounts Table (`accounts`)
Tracks individual financial accounts, credit cards, and investment wallets.

| Field Name | Data Type | Constraints / Format | Description |
| :--- | :--- | :--- | :--- |
| `id` | String | PK, 20-char Alphanumeric | Unique identifier (Apps Script / Firestore native) |
| `name` | String | Required, Non-empty | Human-readable name (e.g., "Chase Sapphire", "Solana Cold Wallet") |
| `type` | String | Enum | `checking`, `savings`, `credit_card`, `investment`, `crypto_wallet` |
| `institution` | String | Optional | Bank or institution name (e.g., "Chase", "Kamino Vault") |
| `currency` | String | 3-to-5 char Alphanumeric | Base currency code or crypto ticker (e.g., "USD", "MXN", "SOL") |
| `current_balance`| Decimal/Double | Default: `0.00` | Real-time liquid cash or sweep fund balance of the account |
| `account_group` | String | Enum | `liquid_assets`,`credit`, `capital`, `retirement` |
| `status` | String | Enum | `active`, `archived` |
| `created_at` | Timestamp | Required | Record creation timestamp |
| `updated_at` | Timestamp | Required | Last modification timestamp |

### 2.2 Account Snapshots Table (`account_snapshots`)
Tracks historical granular balances of individual accounts over time (e.g., daily or monthly increments) to allow individual account growth charting before global net worth aggregation.

| Field Name | Data Type | Constraints / Format | Description |
| :--- | :--- | :--- | :--- |
| `id` | String | PK, 20-char Alphanumeric | Unique snapshot identifier |
| `account_id` | String | FK (`accounts.id`), Required | The specific account being snapshotted |
| `snapshot_date`| Date | Required | Target date for the balance capture (e.g., `2026-06-30`) |
| `balance` | Decimal/Double | Required | Historical cash balance on this specific date in the account's base currency |
| `currency` | String | 3-to-5 char Alphanumeric | Base currency code or crypto ticker of the snapshot balance |
| `created_at` | Timestamp | Required | System generation execution timestamp |

### 2.3 Categories Table (`categories`)
Hierarchical categorization for tracking expenses, income, and transfers.

| Field Name | Data Type | Constraints / Format | Description |
| :--- | :--- | :--- | :--- |
| `id` | String | PK, 20-char Alphanumeric | Unique identifier |
| `name` | String | Required, Non-empty | Category name (e.g., "Groceries", "Retirement PPR") |
| `type` | String | Enum | `income`, `expense`, `transfer`, `reimbursement`, `investment` |
| `parent_id` | String | FK (`categories.id`), Nullable | Enables subcategories (e.g., "Dining Out" under "Food") |
| `icon` | String | Optional | Vector icon glyph name identifier for Flutter frontend |
| `color_hex` | String | 7-char Hex (`#RRGGBB`) | Visual identifier color code for UI charts |
| `created_at` | Timestamp | Required | Record creation timestamp |

### 2.4 Transactions Table (`transactions`)
The core ledger recording all physical cash movements entering or leaving an account. Fully decoupled from asset units.

| Field Name | Data Type | Constraints / Format | Description |
| :--- | :--- | :--- | :--- |
| `id` | String | PK, 20-char Alphanumeric | Unique transaction identifier |
| `account_id` | String | FK (`accounts.id`), Required | Account associated with this cash movement |
| `category_id` | String | FK (`categories.id`), Required | Category for budget and reporting breakdown |
| `amount` | Decimal/Double | Non-zero | Negative for expenses/outflows, positive for income/inflows |
| `currency` | String | 3-to-5 char Alphanumeric | Currency or ticker of the transaction cash flow |
| `exchange_rate`| Decimal/Double | Default: `1.00000` | Rate used if different from account base currency |
| `date` | Date/Timestamp| Required | Effective financial date of the transaction |
| `description` | String | Optional | Merchant name, details, or notes |
| `status` | String | Enum | `pending`, `cleared`, `flagged` |
| `is_recurring` | Boolean | Default: `false` | Indicates if generated by a recurring template |
| `recurring_id` | String | FK (`recurring_transactions.id`) | Reference to parent recurring pattern template if applicable |
| `tags` | Array (String) | Optional | Arbitrary labels for granular tracking (e.g., transfer linking tokens) |
| `sheets_row_id`| Integer | Optional, Nullable | Original row number in Google Sheets (for migration debugging) |
| `created_at` | Timestamp | Required | Record creation timestamp |

### 2.5 Asset Transactions Table (`asset_transactions`)
The trading ledger preserving granular execution receipts for stock, ETF, and crypto investment trades. Decoupled from core cash ledgers.

| Field Name | Data Type | Constraints / Format | Description |
| :--- | :--- | :--- | :--- |
| `id` | String | PK, 20-char Alphanumeric | Unique asset transaction record ID |
| `transaction_id`| String | FK (`transactions.id`), Nullable| Links directly to the cash flow entry that funded or resulted from the trade |
| `account_id` | String | FK (`accounts.id`), Required | The brokerage or crypto wallet container holding the asset |
| `asset_id` | String | FK (`assets.id`), Required | Asset's unique identifier |
| `type` | String | Enum | `buy`, `sell`, `dividend_reinvest`, `split`, `reward` |
| `quantity` | Decimal/Double | Required, Positive | Number of units traded (supports high decimal precision for crypto) |
| `unit_price` | Decimal/Double | Required, Positive | Execution market price per single unit at time of trade |
| `executed_at` | Timestamp | Required | High-precision trade execution timestamp |

### 2.6 Holdings Table (`holdings`)
Tracks current aggregated investment positions, crypto assets, and stocks. Updated by trade executions.

| Field Name | Data Type | Constraints / Format | Description |
| :--- | :--- | :--- | :--- |
| `id` | String | PK, 20-char Alphanumeric | Unique identifier |
| `account_id` | String | FK (`accounts.id`), Required | Investment account/wallet where asset is held |
| `asset_id` | String | FK (`assets.id`), Required | Asset's unique identifier |
| `quantity` | Decimal/Double | Positive | Net units currently held (supports high decimal precision) |
| `avg_buy_price`| Decimal/Double | Positive | Recalculated average cost basis per unit in account base currency |
| `updated_at` | Timestamp | Required | Timestamp of the last market price or quantity sync |

### 2.7 Recurring Transactions Table (`recurring_transactions`)
Templates defining automated or expected repeating financial events.

| Field Name | Data Type | Constraints / Format | Description |
| :--- | :--- | :--- | :--- |
| `id` | String | PK, 20-char Alphanumeric | Unique template identifier |
| `account_id` | String | FK (`accounts.id`), Required | Target account for generated transactions |
| `category_id` | String | FK (`categories.id`), Required | Target category |
| `amount` | Decimal/Double | Required | Base transaction template amount |
| `frequency` | String | Enum | `daily`, `weekly`, `biweekly`, `monthly`, `yearly` |
| `interval` | Integer | Default: `1` | Multiplier for frequency (e.g., interval `2` + weekly = every 2 weeks) |
| `start_date` | Date | Required | Commencement date of the repeating rule |
| `end_date` | Date | Nullable | Termination date of the rule if fixed-term |
| `next_due_date`| Date | Required | Evaluated upcoming transaction date for engine triggers |
| `status` | String | Enum | `active`, `paused`, `completed` |
| `description` | String | Required | Default description text for generated transactions |

### 2.8 Budget Targets Table (`budget_targets`)
Configures threshold ceilings for expense categories or floor goals for savings/investments.

| Field Name | Data Type | Constraints / Format | Description |
| :--- | :--- | :--- | :--- |
| `id` | String | PK, 20-char Alphanumeric | Unique target identifier |
| `category_id` | String | FK (`categories.id`), Required | Category targeted by this constraint rule |
| `target_amount`| Decimal/Double | Positive | Limit amount allocated for the period |
| `period` | String | Enum | `monthly`, `quarterly`, `yearly` |
| `start_date` | Date | Required | Active start boundary date |
| `end_date` | Date | Required | Active end boundary date |
| `created_at` | Timestamp | Required | Creation record timestamp |

### 2.9 System Settings Table (`system_settings`)
Application configurations, features, parameters, and metadata hooks.

| Field Name | Data Type | Constraints / Format | Description |
| :--- | :--- | :--- | :--- |
| `id` | String | PK, 20-char Alphanumeric | Unique parameter identifier |
| `config_key` | String | Unique, Alphanumeric | System configuration identifier key (e.g., `base_currency`) |
| `config_value` | String | Required | Stringified value or JSON object string representing settings |
| `data_type` | String | Enum | `string`, `int`, `boolean`, `json` |
| `description` | String | Optional | Contextual definition of what the setting drives |
| `updated_at` | Timestamp | Required | Date the parameter was last adjusted |

### 2.10 Assets Table (`assets`)
Reference list of supported assets (stocks, cryptocurrencies, etc.) available for trading and tracking.

| Field Name | Data Type | Constraints / Format | Description |
| :--- | :--- | :--- | :--- |
| `id` | String | PK, 20-char Alphanumeric | Unique asset identifier |
| `symbol` | String | Required | Ticker symbol of the asset (e.g., `MSFT`) |
| `name` | String | Required | Full name of the asset (e.g., `Microsoft Corporation`) |
| `type` | String | Enum | `crypto`, `stock`, `etf` |

---

## 3. Entity-Relationship & Schema Constraints

1. **Cascading Logic:** Deleting a `category` containing active transaction histories is blocked (`RESTRICT`). Transactions must be reassigned to an "Uncategorized" bucket (`id: system_fallback_uncat`) first.
2. **Double-Entry Simulation via Transfers:** Internal transfers between accounts utilize two ledger line entries in the `transactions` table pointing to the same custom category type `transfer`, sharing an internal lookup metadata key inside `tags`.
3. **High-Precision Numeric Fields:** Monetary volumes, currency values, and token amounts use floating precision conversions or multi-decimal scaling to ensure no rounding drift occurs across decentralized ledger components.
4. **Split-Ledger Portfolio Valuation:** To calculate total brokerage or crypto account value, the application engine evaluates: `account.current_balance` (cash sweep) + `Sum(holding.quantity * holding.current_price)` for all holdings referencing that specific `account_id`.