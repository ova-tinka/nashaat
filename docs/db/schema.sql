create table public.users (
  id uuid not null,
  email text not null,
  created_at timestamp with time zone null default now(),
  last_active_at timestamp with time zone null default now(),
  timezone text null default 'UTC'::text,
  locale text null default 'en'::text,
  constraint users_pkey primary key (id),
  constraint users_email_key unique (email),
  constraint users_id_fkey foreign key (id) references auth.users (id) on delete cascade
) TABLESPACE pg_default;