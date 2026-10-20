-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 1. CUSTOMERS TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    workplace TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==============================================================================
-- 2. BAKERY SETTINGS TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS bakery_settings (
    id TEXT PRIMARY KEY DEFAULT 'default',
    is_booking_open BOOLEAN NOT NULL DEFAULT true,
    sound_alerts_enabled BOOLEAN NOT NULL DEFAULT true,
    announcement TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Insert default bakery configuration
INSERT INTO bakery_settings (id, is_booking_open, sound_alerts_enabled)
VALUES ('default', true, true)
ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- 3. ORDERS TABLE
-- ==============================================================================
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_code TEXT NOT NULL DEFAULT 'BCC-' || LPAD(FLOOR(RANDOM() * 90000 + 10000)::TEXT, 5, '0'),
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    customer_name TEXT NOT NULL,
    customer_phone TEXT NOT NULL,
    customer_workplace TEXT NOT NULL,
    amount_sdg NUMERIC(12, 2) NOT NULL CHECK (amount_sdg > 0),
    shift TEXT NOT NULL CHECK (shift IN ('morning', 'evening', 'الوردية الصباحية (7:00 ص)', 'الوردية المسائية (4:00 م)')),
    payment_method TEXT NOT NULL CHECK (payment_method IN ('نقدي', 'آجل', 'cash', 'credit')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'ready', 'completed', 'cancelled')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for fast querying, filtering, and reporting
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_customer_phone ON orders(customer_phone);
CREATE INDEX IF NOT EXISTS idx_orders_workplace ON orders(customer_workplace);
CREATE INDEX IF NOT EXISTS idx_orders_shift ON orders(shift);
CREATE INDEX IF NOT EXISTS idx_orders_payment ON orders(payment_method);

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) & ANON POLICIES
-- ==============================================================================

-- Enable RLS
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE bakery_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Customers Policies (Anon)
CREATE POLICY "anon_select_customers" ON customers
    FOR SELECT TO anon USING (true);

CREATE POLICY "anon_insert_customers" ON customers
    FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "anon_update_customers" ON customers
    FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "anon_delete_customers" ON customers
    FOR DELETE TO anon USING (true);

-- Bakery Settings Policies (Anon)
CREATE POLICY "anon_select_bakery_settings" ON bakery_settings
    FOR SELECT TO anon USING (true);

CREATE POLICY "anon_insert_bakery_settings" ON bakery_settings
    FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "anon_update_bakery_settings" ON bakery_settings
    FOR UPDATE TO anon USING (true) WITH CHECK (true);

-- Orders Policies (Anon)
CREATE POLICY "anon_select_orders" ON orders
    FOR SELECT TO anon USING (true);

CREATE POLICY "anon_insert_orders" ON orders
    FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "anon_update_orders" ON orders
    FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY "anon_delete_orders" ON orders
    FOR DELETE TO anon USING (true);
