# Backend Decision: Supabase Canonical Source of Truth

Date: 2026-05-06  
Status: Approved

## Decision
- Supabase is the canonical system of record for Foundation School.
- Apps Script is retired and will be fully removed after Supabase parity checks are complete.
- All new features must use Supabase tables, Supabase Auth, RLS, and Edge Functions.

## Why Apps Script Is Being Retired
- Operational drift: duplicated logic between Apps Script and Supabase caused inconsistent outcomes.
- Limited reliability at scale: retry behavior, auditability, and typed contracts were weak.
- Security posture: centralized Auth + RLS in Supabase is stricter and easier to enforce.
- Maintainability: one backend stack reduces duplicated helpers, hidden business rules, and regressions.

## Migration Principles
- Preserve behavior first, then improve internals.
- Migrate by bounded workflows (schedule, attendance, registration, notifications).
- Keep writes idempotent and retry-safe.
- Log critical transitions in `audit_logs`.
- Add compatibility only at explicit migration boundaries, never as permanent architecture.

## Forbidden Patterns
- Direct calls to `script.google.com` web app URLs.
- `google.script.run` usage in portal code.
- Action-string transport as backend contract (`action=get...`, `action=post...`) for new features.
- Dual-write to Apps Script and Supabase for the same workflow.
- New business logic outside Supabase tables/RPC/Edge Functions.

## Accepted Backend Architecture
- Data: Postgres tables in Supabase (`public` schema unless explicitly scoped).
- Auth: Supabase Auth session/JWT.
- Access control: RLS policies for all user-facing tables.
- Orchestration: Supabase Edge Functions for workflow/business APIs.
- Async delivery: `scheduled_notifications`, `email_queue`, queue workers.
- Integrations: Moodle/Mailchimp via Edge Functions and queue processors.

## Source-of-Truth Rules
- Registration state lives in `applicants` (`registration_status`, `availability_status`).
- Classing/scheduling state lives in `class_options`, `class_slots`, `teacher_availability`.
- Notification state lives in `scheduled_notifications` and `email_queue`.
- Audit trail lives in `audit_logs`.
- If values conflict, Supabase tables win.

## Frontend Routing Canonical Path
- Canonical app root is `/foundation`.
- Canonical admin/staff pages live in `/foundation/staff/`.
- Root-level `/staff/` is deprecated and must not be used for new links, redirects, or deploy routes.

## Phased Retirement Checklist
1. ✅ Replace Apps Script reads with Supabase queries/Edge Functions.
2. ✅ Replace Apps Script writes with Supabase writes (idempotent/upsert where needed).
3. ✅ Verify parity for each workflow with manual regression checklist.
4. ✅ Remove frontend Apps Script URL/meta/config usage.
   - Last reference was `window.TA_CONFIG.endpointBaseUrl` in `foundation/ui/teacher-availability/index.html`.
   - Removed 2026-05-06. Config now uses `mode: "supabase"`.
5. ✅ Remove Apps Script helper branches from shared JS (`api-client.js`).
   - `api-client.js` was already Supabase-only; no dual-mode branches existed at final review.
6. ⬜ Disable Apps Script endpoints in production traffic path (GCP console — manual step).
7. ⬜ Archive Apps Script project as read-only historical artifact (GCP console — manual step).

## Exit Criteria for Full Retirement
- No portal page calls Apps Script endpoints.
- No workflow depends on Apps Script for success path or retries.
- Monitoring confirms all core flows run via Supabase for 2+ release cycles.
