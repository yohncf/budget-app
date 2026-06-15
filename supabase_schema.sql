-- Supabase PostgreSQL Relational Schema Migration
-- Targets Supabase/PostgreSQL schema matching database_schema.json blueprint

-- Enable clean shutdowns/recreates
DROP TRIGGER IF EXISTS update_account_balance_trigger ON transactions;
DROP TRIGGER IF EXISTS check_transaction_amount_type ON transactions;
DROP FUNCTION IF EXISTS update_account_balance();
DROP FUNCTION IF EXISTS validate_transaction_amount_type();

DROP TABLE IF EXISTS system_settings;
DROP TABLE IF EXISTS budget_targets;
DROP TABLE IF EXISTS recurring_transactions;
DROP TABLE IF EXISTS holdings;
DROP TABLE IF EXISTS asset_transactions;
DROP TABLE IF EXISTS assets;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS account_snapshots;
DROP TABLE IF EXISTS accounts;

-- 1. Accounts Table
CREATE TABLE accounts (
    id VARCHAR(20) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('checking', 'savings', 'credit_card', 'investment', 'crypto_wallet')),
    institution VARCHAR(255),
    currency VARCHAR(5) NOT NULL,
    current_balance NUMERIC(20, 4) DEFAULT 0.00,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'archived')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Account Snapshots Table (granular historical balances)
CREATE TABLE account_snapshots (
    id VARCHAR(20) PRIMARY KEY,
    account_id VARCHAR(20) REFERENCES accounts(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    balance NUMERIC(20, 4) NOT NULL,
    currency VARCHAR(5) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Categories Table
CREATE TABLE categories (
    id VARCHAR(20) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('income', 'expense', 'transfer', 'reimbursement', 'investment')),
    parent_id VARCHAR(20) REFERENCES categories(id) ON DELETE RESTRICT, -- RESTRICT deletion if subcategories exist
    icon VARCHAR(255),
    color_hex VARCHAR(7) CHECK (color_hex ~ '^#[0-9a-fA-F]{6}$'),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Transactions Table (physical cash movements)
CREATE TABLE transactions (
    id VARCHAR(20) PRIMARY KEY,
    account_id VARCHAR(20) NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    category_id VARCHAR(20) NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    amount NUMERIC(20, 4) NOT NULL CHECK (amount <> 0),
    currency VARCHAR(5) NOT NULL,
    exchange_rate NUMERIC(10, 6) DEFAULT 1.000000,
    date TIMESTAMPTZ NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'cleared' CHECK (status IN ('pending', 'cleared', 'flagged')),
    is_recurring BOOLEAN DEFAULT FALSE,
    recurring_id VARCHAR(20), -- references recurring_transactions(id) if resolved later
    tags TEXT[] DEFAULT '{}',
    sheets_row_id INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Assets Table
CREATE TABLE assets (
    id VARCHAR(20) PRIMARY KEY,
    symbol VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('crypto', 'stock', 'etf'))
);

-- 6. Asset Transactions Table (execution receipts)
CREATE TABLE asset_transactions (
    id VARCHAR(20) PRIMARY KEY,
    transaction_id VARCHAR(20) REFERENCES transactions(id) ON DELETE SET NULL,
    account_id VARCHAR(20) NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    asset_id VARCHAR(20) NOT NULL REFERENCES assets(id) ON DELETE RESTRICT,
    type VARCHAR(50) NOT NULL CHECK (type IN ('buy', 'sell', 'dividend_reinvest', 'split', 'reward')),
    quantity NUMERIC(28, 18) NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(20, 4) NOT NULL CHECK (unit_price > 0),
    executed_at TIMESTAMPTZ NOT NULL
);

-- 7. Holdings Table (aggregated positions)
CREATE TABLE holdings (
    id VARCHAR(20) PRIMARY KEY,
    account_id VARCHAR(20) NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    asset_id VARCHAR(20) NOT NULL REFERENCES assets(id) ON DELETE RESTRICT,
    quantity NUMERIC(28, 18) NOT NULL CHECK (quantity >= 0),
    avg_buy_price NUMERIC(20, 4) NOT NULL CHECK (avg_buy_price >= 0),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(account_id, asset_id)
);

-- 8. Recurring Transactions Table
CREATE TABLE recurring_transactions (
    id VARCHAR(20) PRIMARY KEY,
    account_id VARCHAR(20) NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    category_id VARCHAR(20) NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    amount NUMERIC(20, 4) NOT NULL,
    frequency VARCHAR(50) NOT NULL CHECK (frequency IN ('daily', 'weekly', 'biweekly', 'monthly', 'yearly')),
    interval INTEGER DEFAULT 1,
    start_date DATE NOT NULL,
    end_date DATE,
    next_due_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed')),
    description VARCHAR(255) NOT NULL
);

-- Add foreign key constraint to transactions if needed
ALTER TABLE transactions ADD CONSTRAINT fk_transactions_recurring 
FOREIGN KEY (recurring_id) REFERENCES recurring_transactions(id) ON DELETE SET NULL;

-- 9. Budget Targets Table
CREATE TABLE budget_targets (
    id VARCHAR(20) PRIMARY KEY,
    category_id VARCHAR(20) NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    target_amount NUMERIC(20, 4) NOT NULL CHECK (target_amount > 0),
    period VARCHAR(20) NOT NULL CHECK (period IN ('monthly', 'quarterly', 'yearly')),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. System Settings Table
CREATE TABLE system_settings (
    id VARCHAR(20) PRIMARY KEY,
    config_key VARCHAR(255) UNIQUE NOT NULL,
    config_value TEXT NOT NULL,
    data_type VARCHAR(50) NOT NULL CHECK (data_type IN ('string', 'int', 'boolean', 'json')),
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==========================================
-- Triggers & Business Logic Invariant Rules
-- ==========================================

-- Rule 2.3 & Rule 4.2 Enforcer: Reject transaction signs matching incorrect category types
CREATE OR REPLACE FUNCTION validate_transaction_amount_type()
RETURNS TRIGGER AS $$
DECLARE
    cat_type VARCHAR(50);
BEGIN
    SELECT type INTO cat_type FROM categories WHERE id = NEW.category_id;
    IF cat_type = 'expense' AND NEW.amount >= 0 THEN
        RAISE EXCEPTION 'Expense amount must be negative (< 0)';
    ELSIF cat_type = 'income' AND NEW.amount <= 0 THEN
        RAISE EXCEPTION 'Income amount must be positive (> 0)';
    ELSIF cat_type = 'reimbursement' AND NEW.amount <= 0 THEN
        RAISE EXCEPTION 'Reimbursement amount must be positive (> 0)';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_transaction_amount_type
BEFORE INSERT OR UPDATE ON transactions
FOR EACH ROW EXECUTE FUNCTION validate_transaction_amount_type();

-- Rule 2.2 Enforcer: Current balance is the sum of transaction logs
CREATE OR REPLACE FUNCTION update_account_balance()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE accounts 
        SET current_balance = current_balance + NEW.amount, updated_at = NOW()
        WHERE id = NEW.account_id;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.account_id = NEW.account_id THEN
            UPDATE accounts 
            SET current_balance = current_balance - OLD.amount + NEW.amount, updated_at = NOW()
            WHERE id = NEW.account_id;
        ELSE
            UPDATE accounts 
            SET current_balance = current_balance - OLD.amount, updated_at = NOW()
            WHERE id = OLD.account_id;
            UPDATE accounts 
            SET current_balance = current_balance + NEW.amount, updated_at = NOW()
            WHERE id = NEW.account_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE accounts 
        SET current_balance = current_balance - OLD.amount, updated_at = NOW()
        WHERE id = OLD.account_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_account_balance_trigger
AFTER INSERT OR UPDATE OR DELETE ON transactions
FOR EACH ROW EXECUTE FUNCTION update_account_balance();
