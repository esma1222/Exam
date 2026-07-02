# Simulazioni Esame OAC — Interactive Exam Webpage

A bilingual (IT / EN) practice-exam web app for the **Operatore Amministrativo
Contabile (OAC)** qualification, backed by Supabase.

The question bank (multiple-choice + practical exercises) and the UI strings now
live in a Supabase Postgres database. The app fetches everything through a
single RPC on load and records each completed attempt back to the database.

## Contents

| File | Purpose |
| --- | --- |
| `Simulazioni Esame OAC.dc.html` | The app (a `dc` component rendered by `support.js`). |
| `support.js` | The `dc` runtime (loads React + Babel, boots the component). |
| `supabase-config.js` | Supabase URL + publishable key used by the app. |
| `oac-data.js` | The original static question bank — kept as an **offline fallback** and as the seed source. |
| `supabase/schema.sql` | Tables + Row Level Security, for reference / reproducibility. |
| `supabase/get_oac.sql` | The `get_oac()` RPC that assembles the frontend payload. |
| `_test1.txt` | Source material (raw test text). |

## How it works

### Data flow

```
Browser ──POST /rest/v1/rpc/get_oac──▶ Supabase ──▶ full question bank (JSON)
        ◀───────────────────────────
        ──POST /rest/v1/attempts─────▶ Supabase   (records the finished attempt)
```

On mount the component:

1. imports `supabase-config.js`,
2. calls the `get_oac()` RPC, which returns the whole question bank in exactly
   the shape the UI expects (`ui`, `units`, `mc`, `practicals`, `templates`),
3. if the backend is unreachable, falls back to the bundled `oac-data.js` so the
   app still works offline.

When the user finishes and grades an exam, the attempt (template, language,
score, and answers) is inserted into `public.attempts`. Grading itself is done
client-side, so a failed save never blocks the results screen.

### Database schema

- `app_ui` — UI translations, one row per language.
- `units` — the three competence units (UC1–UC3).
- `questions` — 90 multiple-choice + 10 practical questions (IT/EN).
- `templates` — the 5 named exam simulations.
- `template_questions` — ordered membership of questions in each template.
- `attempts` — completed attempts (write-only from the client).

### Security (Row Level Security)

RLS is enabled on every table. The **publishable key** shipped in
`supabase-config.js` is safe for the browser — it can only do what the policies
allow:

- **Read** the question bank (`app_ui`, `units`, `questions`, `templates`,
  `template_questions`).
- **Insert** into `attempts`. There is no read policy on `attempts`, so attempts
  cannot be listed back through the public API.

> Note: because grading is client-side (as in the original app), the correct MC
> answers are part of the public read payload. This is intentional for a
> self-study practice tool. If you later need tamper-proof scoring, move grading
> into a `SECURITY DEFINER` RPC that keeps `answer` server-side.
>
> The Supabase linter flags the `attempts` insert policy as "always true". That
> is by design — anonymous learners must be able to record attempts.

## Running locally

The app uses ES module imports, so it must be served over HTTP (not opened via
`file://`):

```bash
cd <this folder>
python3 -m http.server 8000
# then open http://localhost:8000/Simulazioni%20Esame%20OAC.dc.html
```

`support.js` loads React and Babel from unpkg, so an internet connection is
needed on first load.

## Re-seeding the database

The database was seeded from `oac-data.js`. To reproduce on a fresh project:

1. Run `supabase/schema.sql`.
2. Load the `OAC` object from `oac-data.js` as JSON into a staging table and
   unpack it into the tables (see commit history for the exact unpack SQL), or
   simply re-insert from your own tooling.
3. Run `supabase/get_oac.sql`.
4. Point `supabase-config.js` at your project URL and publishable key.
