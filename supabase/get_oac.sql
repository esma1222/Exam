-- get_oac() — assembles the full question-bank payload in the exact shape the
-- frontend expects (mirrors the original oac-data.js OAC object).
-- Applied via MCP migration `oac_get_oac_rpc`. Exposed to anon over PostgREST
-- at POST /rest/v1/rpc/get_oac.

create or replace function public.get_oac()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'ui', (select jsonb_object_agg(lang, strings) from public.app_ui),

    'units', (
      select jsonb_object_agg(id, jsonb_build_object('it', label_it, 'en', label_en))
      from public.units
    ),

    'mc', (
      select jsonb_object_agg(unit_id, arr)
      from (
        select unit_id,
               jsonb_agg(
                 jsonb_build_object(
                   'id', id, 'type', 'mc', 'unit', unit_id,
                   'it', jsonb_build_object('q', q_it, 'opts', opts_it),
                   'en', jsonb_build_object('q', q_en, 'opts', opts_en),
                   'answer', answer
                 ) order by sort
               ) as arr
        from public.questions
        where type = 'mc'
        group by unit_id
      ) g
    ),

    'practicals', (
      select coalesce(jsonb_agg(
               jsonb_build_object(
                 'id', id, 'type', 'prac',
                 'it', jsonb_build_object('q', q_it, 'solution', solution_it),
                 'en', jsonb_build_object('q', q_en, 'solution', solution_en)
               ) order by sort
             ), '[]'::jsonb)
      from public.questions
      where type = 'prac'
    ),

    'templates', (
      select coalesce(jsonb_agg(
               jsonb_build_object(
                 'id', t.id,
                 'it', jsonb_build_object('title', t.title_it, 'desc', t.desc_it),
                 'en', jsonb_build_object('title', t.title_en, 'desc', t.desc_en),
                 'mc', coalesce((
                   select jsonb_agg(tq.question_id order by tq.position)
                   from public.template_questions tq
                   join public.questions q on q.id = tq.question_id
                   where tq.template_id = t.id and q.type = 'mc'
                 ), '[]'::jsonb),
                 'prac', coalesce((
                   select jsonb_agg(tq.question_id order by tq.position)
                   from public.template_questions tq
                   join public.questions q on q.id = tq.question_id
                   where tq.template_id = t.id and q.type = 'prac'
                 ), '[]'::jsonb)
               ) order by t.sort
             ), '[]'::jsonb)
      from public.templates t
    )
  );
$$;

grant execute on function public.get_oac() to anon, authenticated;
