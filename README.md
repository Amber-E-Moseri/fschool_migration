# Foundation School System

A multi-campus registration and administration platform handling student intake, class management, teacher availability, attendance, email workflows, and a gradual migration from Google Apps Script to Supabase.

> **Status:** Active development. Apps Script/Sheets is the current working backend. Supabase migration is in progress.

---

## What's in this repo

```
supabase_foundation/
├── foundation/
│   ├── apps-script/        # Current working backend (registration, attendance, availability, dashboards)
│   ├── docs/               # ARCHITECTURE, CONSTRAINTS, KNOWNBUGS, NEXT_STEPS
│   ├── edge-functions/     # Mailchimp, Moodle, ClickUp sync stubs
│   ├── registration/       # Public registration form
│   ├── sql/                # schema.sql, policies.sql, dashboard_views.sql
│   ├── staff/              # Admin portal HTML pages
│   └── ui/
│       └── teacher-availability/   # React/Vite scheduler prototype
├── supabase/
│   └── config.toml
├── LICENSE
└── README.md
```

---

## Modules

| Module | Location | Status |
|---|---|---|
| Registration | `apps-script/`, `registration/` | Working (Apps Script) |
| Batch management | `staff/batch-management.html`, `sql/schema.sql` | In progress |
| Teacher availability | `apps-script/55_TEACHER_AVAILABILITY.js`, `ui/teacher-availability/` | In progress |
| Attendance | `apps-script/40–43, 60_*.js`, `staff/TeacherAttendancePortal.html` | Working (Apps Script) |
| Admin portal | `staff/admin-portal.html` + supporting pages | Working (static) |
| Email queue | `edge-functions/mailchimp-sync/`, `email_queue` table | Partial |
| Moodle mapping | `sql/schema.sql`, `edge-functions/moodle-sync/` | Stubbed |
| Audit logs | `audit_logs` + `failed_syncs` tables | Schema defined |

---

## Stack

**Current:** Google Apps Script · Google Sheets · Static HTML portals · Google Forms

**Migration target:** Supabase (PostgreSQL) · Edge Functions · React/Vite

---

## Getting started

### Apps Script
```bash
cd foundation/apps-script
clasp login
clasp push
```
Make sure `.clasp.json` points to the correct Apps Script project before pushing.

### Teacher availability UI (local)
```bash
cd foundation/ui/teacher-availability
npm install
npm run dev
```

### Supabase schema
Run the SQL files in order via the Supabase SQL Editor:
```
foundation/sql/schema.sql
foundation/sql/policies.sql
foundation/sql/dashboard_views.sql
```

---

## Known issues

- Attendance duplicate protection needs final validation
- Scheduler approval doesn't reliably create `CLASS_OPTIONS` rows
- Moodle API may return HTTP 403 depending on host/WAF config
- `email_queue` SQL is currently embedded in the Mailchimp Edge Function — needs to move to a proper migration file
- Some staff portal tables overflow on mobile

Full list: [`foundation/docs/KNOWNBUGS.md`](foundation/docs/KNOWNBUGS.md)

---

## Migration approach

The goal is incremental, not a rewrite. One workflow moves at a time:

1. Stabilize and verify current Apps Script flows
2. Build Supabase schema module by module
3. Move one workflow into Supabase, test, then move the next
4. Add Edge Functions only after tables and RLS policies are stable
5. Retire Apps Script modules one at a time as equivalents are confirmed working

---

## Never commit

```
node_modules/   .env*   *.local   supabase.exe
supabase/.temp/   .DS_Store   Google credentials   API keys
```

---

## Commit style

```bash
git commit -m "feat: add batch management portal"
git commit -m "fix: prevent admin portal crash on missing module"
git commit -m "db: add applicants migration"
git commit -m "docs: update known bugs"
```

---

## Docs

- [`ARCHITECTURE.md`](foundation/docs/ARCHITECTURE.md)
- [`CONSTRAINTS.md`](foundation/docs/CONSTRAINTS.md)
- [`KNOWNBUGS.md`](foundation/docs/KNOWNBUGS.md)
- [`NEXT_STEPS.md`](foundation/docs/NEXT_STEPS.md)
