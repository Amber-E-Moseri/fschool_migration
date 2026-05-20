BEGIN;

-- Update is_superadmin() to use current_profile_role() for consistency with is_admin()
CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, auth AS $$
  SELECT COALESCE(public.current_profile_role() = 'superadmin', FALSE)
$$;

-- Widen INSERT/UPDATE to all admin-level roles (superadmin, admin, subgroup_admin, pastor, principal)
DROP POLICY IF EXISTS batches_superadmin_insert ON public.batches;
DROP POLICY IF EXISTS batches_superadmin_update ON public.batches;
DROP POLICY IF EXISTS batches_staff_insert      ON public.batches;
DROP POLICY IF EXISTS batches_staff_update      ON public.batches;
DROP POLICY IF EXISTS batches_admin_insert      ON public.batches;
DROP POLICY IF EXISTS batches_admin_update      ON public.batches;

CREATE POLICY batches_admin_insert ON public.batches
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY batches_admin_update ON public.batches
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Keep DELETE superadmin-only
DROP POLICY IF EXISTS batches_superadmin_delete ON public.batches;
DROP POLICY IF EXISTS batches_staff_delete      ON public.batches;

CREATE POLICY batches_superadmin_delete ON public.batches
  FOR DELETE TO authenticated
  USING (public.is_superadmin());

-- Audit trigger: log every hard DELETE on batches
CREATE OR REPLACE FUNCTION public.log_batch_delete()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, auth AS $$
DECLARE
  v_actor_email TEXT;
BEGIN
  SELECT email INTO v_actor_email
  FROM public.profiles
  WHERE user_id = auth.uid()
  LIMIT 1;

  INSERT INTO public.audit_logs (
    action, entity_type, entity_id,
    actor_email, actor_id, status, details
  ) VALUES (
    'BATCH_DELETED', 'batch', OLD.batch_id::text,
    v_actor_email, auth.uid()::text, 'SUCCESS',
    jsonb_build_object(
      'batch_id',   OLD.batch_id,
      'batch_name', OLD.batch_name,
      'status',     OLD.status,
      'active',     OLD.active
    )
  );

  RETURN OLD;
EXCEPTION WHEN OTHERS THEN
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_batches_audit_delete ON public.batches;
CREATE TRIGGER trg_batches_audit_delete
  AFTER DELETE ON public.batches
  FOR EACH ROW
  EXECUTE FUNCTION public.log_batch_delete();

COMMIT;
