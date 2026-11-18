-- ============================================================================
-- QUICK BASKET: Allow Stock Quantity Updates on Product Variants
-- Enables customer order decrements, cancellations, and staff inventory adjustments
-- ============================================================================

-- Allow updating product_variants stock_quantity
DROP POLICY IF EXISTS "Staff can update product variants" ON product_variants;
CREATE POLICY "Staff can update product variants" ON product_variants
    FOR UPDATE USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Staff can insert product variants" ON product_variants;
CREATE POLICY "Staff can insert product variants" ON product_variants
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Staff can update products" ON products;
CREATE POLICY "Staff can update products" ON products
    FOR UPDATE USING (true) WITH CHECK (true);
