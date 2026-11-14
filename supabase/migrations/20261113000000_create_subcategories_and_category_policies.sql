-- ============================================================================
-- QUICK BASKET: Dynamic Category & Subcategory Management
-- Creates subcategories table, RLS policies, and storage setup
-- ============================================================================

-- 1. Create subcategories table linked to categories
CREATE TABLE IF NOT EXISTS subcategories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    slug TEXT NOT NULL,
    image_url TEXT,
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(category_id, slug)
);

-- Index for fast category-based subcategory lookups
CREATE INDEX IF NOT EXISTS idx_subcategories_category_id ON subcategories(category_id);
CREATE INDEX IF NOT EXISTS idx_subcategories_is_active ON subcategories(is_active);

-- 2. Add subcategory_id to products if not present
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'subcategory_id'
    ) THEN
        ALTER TABLE products ADD COLUMN subcategory_id UUID REFERENCES subcategories(id) ON DELETE SET NULL;
        CREATE INDEX IF NOT EXISTS idx_products_subcategory_id ON products(subcategory_id);
    END IF;
END $$;

-- 3. Enable RLS on subcategories
ALTER TABLE subcategories ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for categories (Allow public read, and staff/admin management)
DROP POLICY IF EXISTS "Public can view active categories" ON categories;
CREATE POLICY "Public can view active categories" ON categories
    FOR SELECT USING (is_active = true OR auth.role() = 'authenticated' OR auth.role() = 'anon');

DROP POLICY IF EXISTS "Staff can insert categories" ON categories;
CREATE POLICY "Staff can insert categories" ON categories
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Staff can update categories" ON categories;
CREATE POLICY "Staff can update categories" ON categories
    FOR UPDATE USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Staff can delete categories" ON categories;
CREATE POLICY "Staff can delete categories" ON categories
    FOR DELETE USING (true);

-- 5. RLS Policies for subcategories
DROP POLICY IF EXISTS "Public can view active subcategories" ON subcategories;
CREATE POLICY "Public can view active subcategories" ON subcategories
    FOR SELECT USING (is_active = true OR auth.role() = 'authenticated' OR auth.role() = 'anon');

DROP POLICY IF EXISTS "Staff can insert subcategories" ON subcategories;
CREATE POLICY "Staff can insert subcategories" ON subcategories
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Staff can update subcategories" ON subcategories;
CREATE POLICY "Staff can update subcategories" ON subcategories
    FOR UPDATE USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Staff can delete subcategories" ON subcategories;
CREATE POLICY "Staff can delete subcategories" ON subcategories
    FOR DELETE USING (true);

-- 6. Setup Supabase Storage Bucket for Category & Subcategory Images
INSERT INTO storage.buckets (id, name, public)
VALUES ('categories', 'categories', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage RLS Policies
DROP POLICY IF EXISTS "Public can view category images" ON storage.objects;
CREATE POLICY "Public can view category images" ON storage.objects
    FOR SELECT USING (bucket_id = 'categories');

DROP POLICY IF EXISTS "Anyone can upload category images" ON storage.objects;
CREATE POLICY "Anyone can upload category images" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'categories');

DROP POLICY IF EXISTS "Anyone can update category images" ON storage.objects;
CREATE POLICY "Anyone can update category images" ON storage.objects
    FOR UPDATE USING (bucket_id = 'categories');

DROP POLICY IF EXISTS "Anyone can delete category images" ON storage.objects;
CREATE POLICY "Anyone can delete category images" ON storage.objects
    FOR DELETE USING (bucket_id = 'categories');

-- 7. Seed Initial Subcategories for Existing Categories
INSERT INTO subcategories (category_id, name, slug, display_order, is_active)
SELECT id, 'Fresh Vegetables', 'fresh-vegetables', 1, TRUE FROM categories WHERE slug = 'fruits-vegetables'
ON CONFLICT (category_id, slug) DO NOTHING;

INSERT INTO subcategories (category_id, name, slug, display_order, is_active)
SELECT id, 'Fresh Fruits', 'fresh-fruits', 2, TRUE FROM categories WHERE slug = 'fruits-vegetables'
ON CONFLICT (category_id, slug) DO NOTHING;

INSERT INTO subcategories (category_id, name, slug, display_order, is_active)
SELECT id, 'Exotics', 'exotics', 3, TRUE FROM categories WHERE slug = 'fruits-vegetables'
ON CONFLICT (category_id, slug) DO NOTHING;

INSERT INTO subcategories (category_id, name, slug, display_order, is_active)
SELECT id, 'Herbs & Seasonings', 'herbs-seasonings', 4, TRUE FROM categories WHERE slug = 'fruits-vegetables'
ON CONFLICT (category_id, slug) DO NOTHING;

INSERT INTO subcategories (category_id, name, slug, display_order, is_active)
SELECT id, 'Milk', 'milk', 1, TRUE FROM categories WHERE slug = 'dairy-bread-eggs'
ON CONFLICT (category_id, slug) DO NOTHING;

INSERT INTO subcategories (category_id, name, slug, display_order, is_active)
SELECT id, 'Bread & Pav', 'bread-pav', 2, TRUE FROM categories WHERE slug = 'dairy-bread-eggs'
ON CONFLICT (category_id, slug) DO NOTHING;

INSERT INTO subcategories (category_id, name, slug, display_order, is_active)
SELECT id, 'Eggs', 'eggs', 3, TRUE FROM categories WHERE slug = 'dairy-bread-eggs'
ON CONFLICT (category_id, slug) DO NOTHING;

INSERT INTO subcategories (category_id, name, slug, display_order, is_active)
SELECT id, 'Paneer & Curd', 'paneer-curd', 4, TRUE FROM categories WHERE slug = 'dairy-bread-eggs'
ON CONFLICT (category_id, slug) DO NOTHING;

INSERT INTO subcategories (category_id, name, slug, display_order, is_active)
SELECT id, 'Butter & Cheese', 'butter-cheese', 5, TRUE FROM categories WHERE slug = 'dairy-bread-eggs'
ON CONFLICT (category_id, slug) DO NOTHING;

INSERT INTO subcategories (category_id, name, slug, display_order, is_active)
SELECT id, 'Atta & Flours', 'atta-flours', 1, TRUE FROM categories WHERE slug = 'atta-rice-pulses'
ON CONFLICT (category_id, slug) DO NOTHING;

INSERT INTO subcategories (category_id, name, slug, display_order, is_active)
SELECT id, 'Rice & Rice Products', 'rice-products', 2, TRUE FROM categories WHERE slug = 'atta-rice-pulses'
ON CONFLICT (category_id, slug) DO NOTHING;

INSERT INTO subcategories (category_id, name, slug, display_order, is_active)
SELECT id, 'Dals & Pulses', 'dals-pulses', 3, TRUE FROM categories WHERE slug = 'atta-rice-pulses'
ON CONFLICT (category_id, slug) DO NOTHING;

INSERT INTO subcategories (category_id, name, slug, display_order, is_active)
SELECT id, 'Chips & Crisps', 'chips-crisps', 1, TRUE FROM categories WHERE slug = 'snacks-munchies'
ON CONFLICT (category_id, slug) DO NOTHING;

INSERT INTO subcategories (category_id, name, slug, display_order, is_active)
SELECT id, 'Namkeen & Mixtures', 'namkeen-mixtures', 2, TRUE FROM categories WHERE slug = 'snacks-munchies'
ON CONFLICT (category_id, slug) DO NOTHING;

INSERT INTO subcategories (category_id, name, slug, display_order, is_active)
SELECT id, 'Biscuits & Cookies', 'biscuits-cookies', 3, TRUE FROM categories WHERE slug = 'snacks-munchies'
ON CONFLICT (category_id, slug) DO NOTHING;
