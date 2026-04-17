-- The exercise catalog is app-wide reference data.
-- Allow the mobile app to read it even when RLS is enabled on the table.

GRANT SELECT ON public.exercises TO anon, authenticated;

DROP POLICY IF EXISTS "Exercise catalog is publicly readable" ON public.exercises;

CREATE POLICY "Exercise catalog is publicly readable"
ON public.exercises
FOR SELECT
TO anon, authenticated
USING (true);
