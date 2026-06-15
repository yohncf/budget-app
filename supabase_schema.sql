-- Supabase Database Schema Dump
-- Generated on: 2026-06-15T21:54:22.016Z

--
-- Table structure for table "account_snapshots"
--

CREATE TABLE public."account_snapshots" (
  "id" character varying(20) NOT NULL,
  "account_id" character varying(20) NOT NULL,
  "snapshot_date" date NOT NULL,
  "balance" numeric NOT NULL,
  "currency" character varying(5) NOT NULL,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "account_snapshots_pkey" PRIMARY KEY ("id")
);

ALTER TABLE public."account_snapshots" ENABLE ROW LEVEL SECURITY;

--
-- Table structure for table "accounts"
--

CREATE TABLE public."accounts" (
  "id" character varying(20) NOT NULL,
  "name" character varying(255) NOT NULL,
  "type" character varying(50) NOT NULL,
  "institution" character varying(255) NOT NULL,
  "currency" character varying(5) NOT NULL,
  "current_balance" numeric NOT NULL DEFAULT 0.00,
  "status" character varying(20) NOT NULL DEFAULT 'active'::character varying,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at" timestamp with time zone DEFAULT now(),
  "account_group" character varying(50) NOT NULL,
  CONSTRAINT "accounts_pkey" PRIMARY KEY ("id")
);

ALTER TABLE public."accounts" ENABLE ROW LEVEL SECURITY;

--
-- Table structure for table "categories"
--

CREATE TABLE public."categories" (
  "id" character varying(20) NOT NULL,
  "name" character varying(255) NOT NULL,
  "type" character varying(50) NOT NULL,
  "parent_id" character varying(20),
  "icon" character varying(255),
  "color_hex" character varying(7),
  "created_at" timestamp with time zone DEFAULT now(),
  CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

ALTER TABLE public."categories" ENABLE ROW LEVEL SECURITY;

--
-- Table structure for table "transactions"
--

CREATE TABLE public."transactions" (
  "id" character varying(20) NOT NULL,
  "account_id" character varying(20) NOT NULL,
  "category_id" character varying(20) NOT NULL,
  "amount" numeric NOT NULL,
  "currency" character varying(5) NOT NULL,
  "exchange_rate" numeric NOT NULL DEFAULT 1.000000,
  "date" timestamp with time zone NOT NULL,
  "description" text NOT NULL,
  "status" character varying(20) DEFAULT 'cleared'::character varying,
  "is_recurring" boolean DEFAULT false,
  "recurring_id" character varying(20),
  "tags" ARRAY DEFAULT '{}'::text[],
  "sheets_row_id" integer,
  "created_at" timestamp with time zone DEFAULT now(),
  CONSTRAINT "transactions_pkey" PRIMARY KEY ("id")
);

ALTER TABLE public."transactions" ENABLE ROW LEVEL SECURITY;

--
-- Table structure for table "assets"
--

CREATE TABLE public."assets" (
  "id" character varying(20) NOT NULL,
  "symbol" character varying(50) NOT NULL,
  "name" character varying(255) NOT NULL,
  "type" character varying(50) NOT NULL,
  CONSTRAINT "assets_pkey" PRIMARY KEY ("id")
);

ALTER TABLE public."assets" ENABLE ROW LEVEL SECURITY;

--
-- Table structure for table "asset_transactions"
--

CREATE TABLE public."asset_transactions" (
  "id" character varying(20) NOT NULL,
  "transaction_id" character varying(20),
  "account_id" character varying(20) NOT NULL,
  "asset_id" character varying(20) NOT NULL,
  "type" character varying(50) NOT NULL,
  "quantity" numeric NOT NULL,
  "unit_price" numeric NOT NULL,
  "executed_at" timestamp with time zone NOT NULL,
  CONSTRAINT "asset_transactions_pkey" PRIMARY KEY ("id")
);

ALTER TABLE public."asset_transactions" ENABLE ROW LEVEL SECURITY;

--
-- Table structure for table "holdings"
--

CREATE TABLE public."holdings" (
  "id" character varying(20) NOT NULL,
  "account_id" character varying(20) NOT NULL,
  "asset_id" character varying(20) NOT NULL,
  "quantity" numeric NOT NULL,
  "avg_buy_price" numeric NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now(),
  CONSTRAINT "holdings_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "holdings_account_id_asset_id_key" UNIQUE ("account_id", "asset_id")
);

ALTER TABLE public."holdings" ENABLE ROW LEVEL SECURITY;

--
-- Table structure for table "recurring_transactions"
--

CREATE TABLE public."recurring_transactions" (
  "id" character varying(20) NOT NULL,
  "account_id" character varying(20) NOT NULL,
  "category_id" character varying(20) NOT NULL,
  "amount" numeric NOT NULL,
  "frequency" character varying(50) NOT NULL,
  "interval" integer NOT NULL DEFAULT 1,
  "start_date" date NOT NULL,
  "end_date" date,
  "next_due_date" date NOT NULL,
  "status" character varying(20) DEFAULT 'active'::character varying,
  "description" character varying(255) NOT NULL,
  CONSTRAINT "recurring_transactions_pkey" PRIMARY KEY ("id")
);

ALTER TABLE public."recurring_transactions" ENABLE ROW LEVEL SECURITY;

--
-- Table structure for table "budget_targets"
--

CREATE TABLE public."budget_targets" (
  "id" character varying(20) NOT NULL,
  "category_id" character varying(20) NOT NULL,
  "target_amount" numeric NOT NULL,
  "period" character varying(20) NOT NULL,
  "start_date" date NOT NULL,
  "end_date" date NOT NULL,
  "created_at" timestamp with time zone DEFAULT now(),
  CONSTRAINT "budget_targets_pkey" PRIMARY KEY ("id")
);

ALTER TABLE public."budget_targets" ENABLE ROW LEVEL SECURITY;

--
-- Table structure for table "system_settings"
--

CREATE TABLE public."system_settings" (
  "id" character varying(20) NOT NULL,
  "config_key" character varying(255) NOT NULL,
  "config_value" text NOT NULL,
  "data_type" character varying(50) NOT NULL,
  "description" text,
  "updated_at" timestamp with time zone DEFAULT now(),
  CONSTRAINT "system_settings_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "system_settings_config_key_key" UNIQUE ("config_key")
);

ALTER TABLE public."system_settings" ENABLE ROW LEVEL SECURITY;

--
-- Foreign Key Constraints
--

ALTER TABLE ONLY public."account_snapshots"
  ADD CONSTRAINT "account_snapshots_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES public."accounts"("id");

ALTER TABLE ONLY public."categories"
  ADD CONSTRAINT "categories_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES public."categories"("id");

ALTER TABLE ONLY public."transactions"
  ADD CONSTRAINT "transactions_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES public."accounts"("id");

ALTER TABLE ONLY public."transactions"
  ADD CONSTRAINT "transactions_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES public."categories"("id");

ALTER TABLE ONLY public."transactions"
  ADD CONSTRAINT "fk_transactions_recurring" FOREIGN KEY ("recurring_id") REFERENCES public."recurring_transactions"("id");

ALTER TABLE ONLY public."asset_transactions"
  ADD CONSTRAINT "asset_transactions_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES public."transactions"("id");

ALTER TABLE ONLY public."asset_transactions"
  ADD CONSTRAINT "asset_transactions_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES public."accounts"("id");

ALTER TABLE ONLY public."asset_transactions"
  ADD CONSTRAINT "asset_transactions_asset_id_fkey" FOREIGN KEY ("asset_id") REFERENCES public."assets"("id");

ALTER TABLE ONLY public."holdings"
  ADD CONSTRAINT "holdings_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES public."accounts"("id");

ALTER TABLE ONLY public."holdings"
  ADD CONSTRAINT "holdings_asset_id_fkey" FOREIGN KEY ("asset_id") REFERENCES public."assets"("id");

ALTER TABLE ONLY public."recurring_transactions"
  ADD CONSTRAINT "recurring_transactions_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES public."accounts"("id");

ALTER TABLE ONLY public."recurring_transactions"
  ADD CONSTRAINT "recurring_transactions_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES public."categories"("id");

ALTER TABLE ONLY public."budget_targets"
  ADD CONSTRAINT "budget_targets_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES public."categories"("id");

