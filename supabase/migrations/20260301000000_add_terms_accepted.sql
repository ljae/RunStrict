-- Migration: Add terms_accepted_at to users table
-- Purpose: Record timestamp when user accepted Terms of Service and Privacy Policy
-- Version: 1.0 (legal_version matches kLegalVersion in legal_content.dart)

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS legal_version TEXT;

COMMENT ON COLUMN public.users.terms_accepted_at IS
  'UTC timestamp when the user accepted the Terms of Service and Privacy Policy. '
  'NULL for users who registered before terms enforcement (grandfathered).';

COMMENT ON COLUMN public.users.legal_version IS
  'Version of the Terms/Privacy Policy accepted by the user (e.g. "1.0"). '
  'Used to detect when re-acceptance is required after policy updates.';
