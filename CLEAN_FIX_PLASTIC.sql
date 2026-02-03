ALTER TABLE public.plastic_items DISABLE ROW LEVEL SECURITY;

ALTER TABLE public.plastic_items DROP CONSTRAINT IF EXISTS plastic_items_status_check CASCADE;

ALTER TABLE public.plastic_items ALTER COLUMN status SET NOT NULL;

ALTER TABLE public.plastic_items ALTER COLUMN status SET DEFAULT 'pending';

UPDATE public.plastic_items SET status = 'pending' WHERE status IS NULL;

ALTER TABLE public.plastic_items ADD CONSTRAINT plastic_items_status_check CHECK (status IN ('pending', 'assigned', 'collected', 'delivered'));

ALTER TABLE public.plastic_items ENABLE ROW LEVEL SECURITY;

SELECT conname, pg_get_constraintdef(oid) as definition FROM pg_constraint WHERE conrelid = 'public.plastic_items'::regclass AND conname = 'plastic_items_status_check';
