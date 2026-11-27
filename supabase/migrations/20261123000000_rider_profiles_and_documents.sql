-- ============================================================================
-- QUICK BASKET: Delivery Partner App — rider profile, payout & KYC documents
--
-- Purely ADDITIVE. Does not modify or weaken any existing table or policy.
--
-- * rider_profiles   — personal info + payout (bank) details, one row per
--                      signed-in partner (auth.uid()).
-- * rider_documents  — KYC document records (Aadhaar, PAN, DL, RC, insurance).
-- * storage bucket "rider-documents" — PRIVATE; files under "<auth.uid()>/…".
--
-- Access model (Row Level Security):
--   - A partner can read / write ONLY their own rows and files.
--   - A partner can never mark their own document as verified.
--   - Staff (super_admin, store_manager, delivery_manager in user_roles) can
--     read everything and review documents.
--   - Anonymous (public key) access: none.
-- ============================================================================

-- Helper: is the current user rider-admin staff? SECURITY DEFINER so it works
-- regardless of the RLS on user_roles; search_path pinned for safety.
CREATE OR REPLACE FUNCTION public.is_rider_staff()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid()
          AND ur.role IN ('super_admin', 'store_manager', 'delivery_manager')
    );
$$;

REVOKE ALL ON FUNCTION public.is_rider_staff() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_rider_staff() TO authenticated;

-- ---------------------------------------------------------------------------
-- 1. rider_profiles
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rider_profiles (
    user_id                 UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    rider_ref               TEXT,          -- delivery_partners.id the partner logged in as
    phone                   TEXT,
    email                   TEXT,
    address                 TEXT,
    emergency_contact_name  TEXT,
    emergency_contact_phone TEXT,
    bank_account_holder     TEXT,
    bank_account_number     TEXT,
    bank_ifsc               TEXT CHECK (bank_ifsc IS NULL OR bank_ifsc = '' OR bank_ifsc ~ '^[A-Z]{4}0[A-Z0-9]{6}$'),
    upi_id                  TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.rider_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Rider reads own profile" ON public.rider_profiles;
CREATE POLICY "Rider reads own profile" ON public.rider_profiles
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_rider_staff());

DROP POLICY IF EXISTS "Rider creates own profile" ON public.rider_profiles;
CREATE POLICY "Rider creates own profile" ON public.rider_profiles
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Rider updates own profile" ON public.rider_profiles;
CREATE POLICY "Rider updates own profile" ON public.rider_profiles
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 2. rider_documents
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rider_documents (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    doc_type     TEXT NOT NULL CHECK (doc_type IN ('aadhaar', 'pan', 'driving_licence', 'vehicle_rc', 'vehicle_insurance')),
    storage_path TEXT NOT NULL,
    status       TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'rejected')),
    review_note  TEXT,
    uploaded_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at  TIMESTAMPTZ,
    reviewed_by  UUID REFERENCES auth.users(id),
    UNIQUE (user_id, doc_type)
);

ALTER TABLE public.rider_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Rider reads own documents" ON public.rider_documents;
CREATE POLICY "Rider reads own documents" ON public.rider_documents
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_rider_staff());

-- Partners may only submit documents as 'pending', inside their own folder.
DROP POLICY IF EXISTS "Rider submits own documents" ON public.rider_documents;
CREATE POLICY "Rider submits own documents" ON public.rider_documents
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid() AND status = 'pending' AND storage_path LIKE auth.uid()::text || '/%');

-- Re-upload resets to 'pending'; a partner can never self-verify.
DROP POLICY IF EXISTS "Rider re-submits own documents" ON public.rider_documents;
CREATE POLICY "Rider re-submits own documents" ON public.rider_documents
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid() AND status <> 'verified')
    WITH CHECK (user_id = auth.uid() AND status = 'pending' AND storage_path LIKE auth.uid()::text || '/%');

DROP POLICY IF EXISTS "Staff review rider documents" ON public.rider_documents;
CREATE POLICY "Staff review rider documents" ON public.rider_documents
    FOR UPDATE TO authenticated
    USING (public.is_rider_staff())
    WITH CHECK (public.is_rider_staff());

-- ---------------------------------------------------------------------------
-- 3. Private storage bucket for document images
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('rider-documents', 'rider-documents', false)
ON CONFLICT (id) DO UPDATE SET public = false;

DROP POLICY IF EXISTS "Rider uploads own document files" ON storage.objects;
CREATE POLICY "Rider uploads own document files" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'rider-documents' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "Rider reads own document files" ON storage.objects;
CREATE POLICY "Rider reads own document files" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'rider-documents'
           AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_rider_staff()));
