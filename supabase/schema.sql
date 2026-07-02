-- OAC Exam Simulator — database schema
-- Applied to the Supabase project via MCP migration `oac_exam_schema`.
-- The question bank is public read-only (anon); attempts are public insert-only.

-- UI translations: one row per language, full strings object as jsonb
create table if not exists public.app_ui (
  lang    text primary key,
  strings jsonb not null
);

-- Competence units (UC)
create table if not exists public.units (
  id       text primary key,        -- 'uc1' | 'uc2' | 'uc3'
  label_it text not null,
  label_en text not null,
  sort     int  not null default 0
);

-- Question bank (multiple-choice and practical)
create table if not exists public.questions (
  id          text primary key,     -- e.g. 'uc1-1', 'p-1'
  type        text not null check (type in ('mc','prac')),
  unit_id     text references public.units(id) on delete restrict,
  q_it        text not null,
  q_en        text not null,
  opts_it     jsonb,                -- array of option strings (mc only)
  opts_en     jsonb,
  answer      smallint,             -- 0-based index of correct option (mc only)
  solution_it text,                 -- model solution (prac only)
  solution_en text,
  sort        int not null default 0,
  constraint mc_requires_opts check (
    type <> 'mc' or (opts_it is not null and opts_en is not null and answer is not null)
  ),
  constraint prac_requires_solution check (
    type <> 'prac' or (solution_it is not null and solution_en is not null)
  )
);
create index if not exists questions_unit_idx on public.questions(unit_id);
create index if not exists questions_type_idx on public.questions(type);

-- Exam templates (a named simulation = ordered set of questions)
create table if not exists public.templates (
  id       text primary key,        -- 'sim1'..
  title_it text not null,
  desc_it  text not null,
  title_en text not null,
  desc_en  text not null,
  sort     int not null default 0
);

-- Ordered membership of questions in templates
create table if not exists public.template_questions (
  template_id text not null references public.templates(id) on delete cascade,
  question_id text not null references public.questions(id) on delete cascade,
  position    int  not null default 0,
  primary key (template_id, question_id)
);
create index if not exists tq_template_idx on public.template_questions(template_id);

-- Persisted exam attempts (write-only from the client)
create table if not exists public.attempts (
  id                uuid primary key default gen_random_uuid(),
  created_at        timestamptz not null default now(),
  template_id       text references public.templates(id) on delete set null,
  lang              text,
  session_id        text,           -- anonymous client id from localStorage
  mc_total          int,
  mc_correct        int,
  mc_pct            int,
  prac_total        int,
  answers           jsonb,          -- { question_id: option_index | text }
  prac_marks        jsonb           -- { question_id: 'correct' | 'wrong' } (optional)
);
create index if not exists attempts_template_idx on public.attempts(template_id);
create index if not exists attempts_session_idx on public.attempts(session_id);

-- Row Level Security ------------------------------------------------------
alter table public.app_ui             enable row level security;
alter table public.units              enable row level security;
alter table public.questions          enable row level security;
alter table public.templates          enable row level security;
alter table public.template_questions enable row level security;
alter table public.attempts           enable row level security;

-- Public (anon + authenticated) read access to the question bank
create policy "public read app_ui"    on public.app_ui             for select using (true);
create policy "public read units"     on public.units              for select using (true);
create policy "public read questions" on public.questions          for select using (true);
create policy "public read templates" on public.templates          for select using (true);
create policy "public read tq"        on public.template_questions for select using (true);

-- Anyone may record an attempt; nobody may read attempts back via the API.
create policy "public insert attempts" on public.attempts for insert with check (true);
