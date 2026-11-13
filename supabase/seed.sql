-- ============================================================================
-- QUICK BASKET: Initial Database Seed Data (PRD Section 4.4, 4.5, 5.12)
-- ============================================================================

-- 1. Initial Store (Single Store Model)
INSERT INTO stores (id, name, code, address, latitude, longitude, phone_number, is_active)
VALUES (
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'Quick Basket Dark Store 01',
    'QB-BLR-01',
    '42, 80 Feet Road, Koramangala 4th Block, Bangalore',
    12.9343,
    77.6252,
    '+918041234567',
    TRUE
) ON CONFLICT (code) DO NOTHING;

-- 2. Delivery Areas (PRD Section 4.2)
INSERT INTO delivery_areas (store_id, name, pincode, min_order_value, delivery_fee, free_delivery_above, estimated_delivery_mins)
VALUES 
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Koramangala', '560034', 99.00, 25.00, 199.00, 12),
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'HSR Layout', '560102', 99.00, 25.00, 199.00, 15),
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'BTM Layout', '560076', 99.00, 25.00, 199.00, 18);

-- 3. Product Categories (PRD Section 4.4)
INSERT INTO categories (id, name, slug, icon_name, color_hex, display_order, is_active)
VALUES
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380001', 'Fruits & Vegetables', 'fruits-vegetables', 'eco', '#E8F5E9', 1, TRUE),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380002', 'Dairy, Bread & Eggs', 'dairy-bread-eggs', 'egg', '#FFF8E1', 2, TRUE),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380003', 'Atta, Rice & Pulses', 'atta-rice-pulses', 'grain', '#FFF3E0', 3, TRUE),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380004', 'Snacks & Munchies', 'snacks-munchies', 'fastfood', '#FBE9E7', 4, TRUE),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380005', 'Cold Drinks & Juices', 'cold-drinks-juices', 'local_drink', '#E1F5FE', 5, TRUE),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380006', 'Breakfast & Sauces', 'breakfast-sauces', 'breakfast_dining', '#F3E5F5', 6, TRUE),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380007', 'Instant Food', 'instant-packaged-food', 'ramen_dining', '#FFEBEE', 7, TRUE),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380008', 'Tea, Coffee & Health', 'tea-coffee-health-drinks', 'coffee', '#EFEBE9', 8, TRUE),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380009', 'Sweet Tooth', 'sweet-tooth', 'cake', '#FCE4EC', 9, TRUE),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380010', 'Bakery & Biscuits', 'bakery-biscuits', 'bakery_dining', '#EDE7F6', 10, TRUE),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380011', 'Personal Care', 'personal-care', 'spa', '#E0F7FA', 11, TRUE),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380012', 'Baby Care', 'baby-care', 'child_care', '#F9FBE7', 12, TRUE),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380013', 'Household Essentials', 'household-essentials', 'home', '#E8EAF6', 13, TRUE),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380014', 'Cleaning Supplies', 'cleaning-supplies', 'cleaning_services', '#E0F2F1', 14, TRUE),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380015', 'Pet Care', 'pet-care', 'pets', '#FFFDE7', 15, TRUE)
ON CONFLICT (slug) DO NOTHING;

-- 4. Brands
INSERT INTO brands (id, name, slug)
VALUES
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380001', 'Amul', 'amul'),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380002', 'Aashirvaad', 'aashirvaad'),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380003', 'Lay''s', 'lays'),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380004', 'Maggi', 'maggi')
ON CONFLICT (slug) DO NOTHING;

-- 5. Promotional Banners (PRD Section 4.3 & 5.10)
INSERT INTO banners (title, subtitle, image_url, discount_text, background_color_hex, display_order)
VALUES
('Fresh Farm Fruits & Veggies', 'Flat 30% OFF • Freshly Picked Daily', 'https://images.unsplash.com/photo-1610832958506-aa56368176cf', 'UP TO 30% OFF', '#0C8340', 1),
('Morning Dairy & Breakfast', 'Pure Milk, Fresh Bread & Eggs in 10 mins', 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af', 'FLAT ₹50 OFF', '#FF7A00', 2),
('Munchies & Chilled Beverages', 'Chips, Dips, Sodas & Party Packs', 'https://images.unsplash.com/photo-1563729784474-d77dbb933a9e', 'BUY 1 GET 1', '#673AB7', 3);
