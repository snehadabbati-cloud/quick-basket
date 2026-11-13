-- Fix INSERT policy for order_items and user_addresses
-- Allows authenticated users to insert items for orders they own

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'order_items' 
        AND policyname = 'Users can insert own order items'
    ) THEN
        CREATE POLICY "Users can insert own order items" ON order_items
            FOR INSERT WITH CHECK (
                order_id IN (SELECT id FROM orders WHERE user_id = auth.uid())
            );
    END IF;
END $$;
