# Google Antigravity Agent Instructions: Budget App Workspace Core
## System Context & Architectural Source of Truth

This document outlines the strict business logic, database relationships, validation invariants, and historical execution context for building the Personal Finance App using Flutter (Frontend), Firebase Firestore (Backend), and Google Apps Script (Migration Engine). 

Ingest this context, along with `budget_app_schema_blueprint.md` and `budget_app_system_config.json`, before writing, refactoring, or running automated test code.

---

## 1. Source Data & Migration Pipeline Context

### 1.1 Legacy Ledger Source
- **Source Spreadsheet Link:** [Google Sheets Budget Ledger](https://docs.google.com/spreadsheets/d/1tWqJbIsyPrFSWcQumrRdCaK8C2SrncmTPaVuVqBNtnY/edit?gid=614738190#gid=614738190)
- **Engine Layer:** Google Apps Script reads from this spreadsheet, normalizes rows, generates a unique 20-character alphanumeric string ID for each entity, and uploads them to Firebase Firestore collections.
- **Traceability:** Cash transactions written to Firestore must preserve the original row number inside the `sheets_row_id` field for logging and reconciliation audits.

### 1.2 Schema Synchronization Warning
- **Account Type Sync:** Ensure that native Dart/TypeScript definitions include the `retirement` type enum in addition to `checking`, `savings`, `credit_card`, `investment`, and `crypto_wallet`.

---

## 2. Core Architectural & Financial Business Rules

### Rule 2.1: The Unified "Accounts" Paradigm (Cash Settlement vs. Securities)
- **Credit Cards Are Accounts:** Credit cards are treated as an account with `type: "credit_card"`. An expense transaction ($amount < 0$) increases outstanding card debt.
- **Brokerage Accounts:** Accounts with `type: "investment"` or `"retirement"` act as a dual container representing the **Uninvested Cash Settlement/Sweep Fund**. The `current_balance` field of these accounts tracks *only* this cash liquid state.
- **Net Worth Aggregation:** Global metrics must evaluate net wealth using the following formula:
  Net Worth = Sum(Asset Cash Balances) + Sum(Live Value of All Holdings) - Sum(Credit Card Outstanding Debts)

### Rule 2.2: Pure Ledger Initialization (Opening Balances)
- **No Floating Baselines:** Do not store initial historical starting balances as standalone properties inside account configurations. 
- **Enforcement Pattern:** The pipeline initializes accounts by writing an entry to the `transactions` table with a system category identifier `System: Opening Balance` on the chosen cutoff migration date.
- **Invariant:** An account's `current_balance` must always equal the absolute mathematical sum of all cash transaction logs associated with its ID.

### Rule 2.3: Structural 4-Type Category Engine
Every category inside the system maps explicitly to one of four types, dictating strict math rules:
1. **`expense`:** Strictly Negative values ($< 0$). Used for standard outflows (e.g., Groceries, Dining Out).
2. **`income`:** Strictly Positive values ($> 0$). Used for personal core inflows (e.g., Salary, Peer Deposits, Gifts).
3. **`transfer`:** Paired Balancing Rows ($-\text{value}$ and $+\text{value}$). Used for moving money you own (e.g., Checking to Savings, Funding a Brokerage, Credit Card Payments).
4. **`reimbursement`:** Strictly Positive values ($> 0$). Used for split bills, refunds, or corporate cash-backs.

### Rule 2.4: Credit Card Payments & Savings Isolation
- Credit card payments and transfers to savings are **Internal Transfers**, never expenses or income.
- They generate balanced transaction line item pairs sharing a unified linking token inside their `tags` array.
- **UI Filtering Requirement:** The Flutter state machine must completely filter out categories where `type == "transfer"` from monthly spending pie charts and income bars to prevent artificial double-counting of wealth metrics.

---

## 3. Relational Split Ledger Architecture (Path 2)

To accurately handle brokerage accounts that hold both cash and stock assets simultaneously without data degradation, cash movements are fully decoupled from asset trading receipts using two distinct collections.

### 3.1 The Cash Impact Ledger (`transactions` collection)
- Records any cash entering or leaving an account.
- When buying a stock using cash inside a brokerage account, a transaction is written with a negative amount (e.g., `-4200.00`) pointing to an asset purchase category (`type: "transfer"`). This drops the uninvested cash balance of the brokerage container.

### 3.2 The Trade Execution Ledger (`asset_transactions` collection)
This collection preserves historical trade execution receipts. Every trade must write a document to this table following this strict schema:

| Field Name | Data Type | Constraints / Format | Description |
| :--- | :--- | :--- | :--- |
| `id` | String | PK, 20-char Alphanumeric | Unique asset transaction record ID. |
| `transaction_id` | String | FK (`transactions.id`), Nullable | Maps directly to the cash flow ledger entry that funded the trade. Nullable to support corporate stock splits or crypto airdrops. |
| `account_id` | String | FK (`accounts.id`), Required | The brokerage or crypto wallet container holding the asset. |
| `asset_symbol` | String | Required | Ticker asset identifier (e.g., `MSFT`, `SOL`). |
| `asset_name` | String | Required | Full name of the asset (e.g., `Microsoft Corp`). |
| `type` | String | Enum | `buy`, `sell`, `split`, `dividend_reinvest` |
| `quantity` | Decimal/Double | Required, Positive | Number of units traded. Must support high decimal lengths for crypto. |
| `unit_price` | Decimal/Double | Required, Positive | Market execution price per single unit at time of trade. |
| `executed_at` | Timestamp | Required | High-precision trade execution timestamp. |

### 3.3 The Inventory State (`holdings` collection)
- Represents the current aggregated inventory state. 
- Buying an asset appends/increments the `quantity` in this table and recalculates the `avg_buy_price` cost basis. Selling decrements the `quantity`.

---

## 4. Implementation Directives for Antigravity Agents

When generating or refactoring code bases across the stack, ensure the following constraints are honored:
1. **Google Apps Script Verification:** Implement validation logic checking transaction amounts against their category types before running Firestore write operations.
2. **Firestore Security Validation:** Ensure database rule definitions mirror these logic constraints, automatically rejecting any document where an `expense` amount is positive or an `income` amount is negative.
3. **Flutter Portfolio Aggregation:** When rendering an investment account card, calculate its total value by combining the cash balance with the live value of its holdings:
   Total Account Value = account.current_balance + Sum(holding.quantity * holding.current_price)