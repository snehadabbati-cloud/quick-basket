-- ============================================================================
-- QUICK BASKET: Order Cancellation, Refund Status & Supabase Order Persistence
-- Conforming to Requirements:
-- 1. Store cancellation details (cancelled_by, cancellation_reason, cancelled_at)
-- 2. Store refund status (none, pending, initiated, processed)
-- 3. Allow guest & customer order insertion and cancellation updates
-- 4. Never delete cancelled orders from Supabase
-- 5. Maintain order status history across all stages
-- ============================================================================

-- 1. Add cancellation and refund columns to 'orders' table
DO $$
BEGIN
    -- cancellation details
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' AND column_name = 'cancelled_by'
    ) THEN
        ALTER TABLE orders ADD COLUMN cancelled_by TEXT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' AND column_name = 'cancellation_reason'
    ) THEN
        ALTER TABLE orders ADD COLUMN cancellation_reason TEXT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' AND column_name = 'cancelled_at'
    ) THEN
        ALTER TABLE orders ADD COLUMN cancelled_at TIMESTAMPTZ;
    END IF;

    -- refund status: 'none', 'pending', 'initiated', 'processed'
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' AND column_name = 'refund_status'
    ) THEN
        ALTER TABLE orders ADD COLUMN refund_status TEXT DEFAULT 'none';
    END IF;
END $$;

-- 2. Ensure guest orders can be inserted without strict foreign key failure
-- If user_id is guest (00000000-0000-0000-0000-000000000000 or null), allow it
ALTER TABLE orders ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_user_id_fkey;
ALTER TABLE orders ADD CONSTRAINT orders_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE SET NULL;

-- 3. Row Level Security (RLS) Policies on 'orders'
-- Ensure orders can be viewed, created, and updated (cancelled/advanced), but NEVER deleted
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public and staff can view orders" ON orders;
DROP POLICY IF EXISTS "Users can read own orders" ON orders;
CREATE POLICY "Public and staff can view orders" ON orders
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can insert orders" ON orders;
DROP POLICY IF EXISTS "Users can create own orders" ON orders;
CREATE POLICY "Anyone can insert orders" ON orders
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can update orders" ON orders;
CREATE POLICY "Anyone can update orders" ON orders
    FOR UPDATE USING (true) WITH CHECK (true);

-- Explicitly DO NOT create a DELETE policy on orders, guaranteeing cancelled orders are preserved.

-- 4. RLS Policies on 'order_items'
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public and staff can view order items" ON order_items;
DROP POLICY IF EXISTS "Users can read own order items" ON order_items;
CREATE POLICY "Public and staff can view order items" ON order_items
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can insert order items" ON order_items;
DROP POLICY IF EXISTS "Users can insert own order items" ON order_items;
CREATE POLICY "Anyone can insert order items" ON order_items
    FOR INSERT WITH CHECK (true);

-- 5. RLS Policies on 'order_status_history'
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public and staff can view order status history" ON order_status_history;
DROP POLICY IF EXISTS "Users can read own order status history" ON order_status_history;
CREATE POLICY "Public and staff can view order status history" ON order_status_history
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Anyone can insert order status history" ON order_status_history;
CREATE POLICY "Anyone can insert order status history" ON order_status_history
    FOR INSERT WITH CHECK (true);
