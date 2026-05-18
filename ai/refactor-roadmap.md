refactor-roadmap.md

# Refactor Roadmap

Phased stabilization plan. Respect phase order — do not begin a later phase while an earlier
phase has open critical work.

---

## Phase 1 — Shared Shells [COMPLETE]

Goal: Every admin/staff page uses `admin-shell.js` for navigation, auth handling, and theme.
No page should embed its own nav markup.

Deliverables:
- `admin-shell.js` extracted and stabilized
- All staff pages call `FSAdminShell.mount()`
- Null-safe guard: shows "Not connected" when config absent
- Role-gating: teacher-only pages blocked for non-teacher roles

---

## Phase 2 � Shared Design System [COMPLETE]

tokens.css + primitives.css created, admin-shell.js updated,
page migration not yet started.

Goal: All staff pages use `fs-*` CSS primitives from `tokens.css` / `primitives.css`.
No page should define its own color variables, spacing tokens, or component classes.

Deliverables:
- `tokens.css` — single source of truth for all design values
- `primitives.css` — all fs-* component classes (shell, topbar, table, badge, button, input)
- All staff pages import `primitives.css` and use `fs-*` classes
- CI check: grep for `var(--muted)`, `.chip`, `.summary-card` → fail

Pages pending migration:`r`n- All 8 pages migrated. CI hook enforces fs-* compliance on commit.`r`n- Completed: May 18, 2026.`r`n`r`n---

## Phase 3 — Inline JS Extraction [NOT STARTED]

Goal: No business logic in `<script>` tags or inline JS in HTML files.
All page logic lives in ES module files under `/foundation/js/`.

Deliverables:
- All inline `<script type="module">` blocks extracted to named `.js` files
- Shared helpers (auth, API, UI) imported rather than duplicated
- `admin-api.js` covers all Supabase function invocations
- config.js guard centralized in `runtime.js`

---

## Phase 4 — Security Hardening [LARGELY COMPLETE]

RLS 1-4 done, CORS fixed, credentials secured.

Goal: Every Supabase table has RLS. Every edge function validates JWT role. No credentials
in any committed file.

Completed:
- RLS hardening migrations 1-4 applied (all listed tables covered)
- CORS wildcard removed from 6 edge functions + shared-utils
- config.js gitignored and never committed; pre-commit hook added
- Attendance deduplication guard added
- Teacher user ownership hardening migration applied

Remaining:
- Confirm all new tables created after 202605121320 have RLS policies
- Rotate anon key found in config.js (release blocker)
- Add server-side rate limiting to registration-processor

---

## Phase 5 — Operational Expansion [IN PROGRESS]

Goal: Expand operational visibility and per-applicant traceability.

Planned deliverables:
- Per-applicant trace view in System Health (email + ID → full event log)
- trace_id added to email pipeline tables
- Moodle sync failure dashboard with per-cause breakdown
- ClickUp escalation audit in Retry Center

Current status (May 2026):
- Operational hardening significantly improved (retry workflows, error classification, and visibility surfaces).
- Per-applicant trace view remains open and is now a top consolidation task.

---

## Current Platform State — May 2026

Completed:
- RLS hardening complete.
- CORS cleanup complete.
- Attendance dedupe complete.
- fs-* design system introduced.
- `teacher-portal-api` router refactor complete.
- Moodle 403 classification completed.
- Shared `_shared/` utilities started (`supabase.ts`, `audit.ts`, `response.ts`).
- `sender-worker` marked for deprecation.
- Operational visibility significantly improved.

Current highest priority consolidation tasks:
- Shared assignment pipeline extraction.
- Auth module consolidation.
- fs-* migration completion.
- Schema canonicalization (remove fallback table-name loops).
- sender-worker deprecation completion.
- Operational trace view.

Do not reintroduce:
- Duplicate workers.
- Duplicate auth paths.
- Legacy CSS primitives.
- try-multiple-table-name fallbacks.
- Inline config guards.
- Page-specific design systems.

---

### Next Quarter Priorities (from engineering review)

In recommended order:

1. Refactor teacher-portal-api into action router [COMPLETED]
   - ~60-line router target achieved via action-map + extracted handlers
   - Isolated blast radius per action
   - Testable independently

2. Extract shared assignment logic
   - registration-processor + phase2-processor share core loop
   - Extract to _shared/lib/assign-applicant.ts
   - Both become thin wrappers

3. Consolidate admin assignment path -> admin-api action [COMPLETED]
   - admin-review.js now calls admin-api/assign-applicant-admin which delegates
     to _shared/lib/assign-applicant.ts
   - Direct DB writes removed from frontend assignment path

4. Consolidate auth-client.js + auth-guards.js [PARTIALLY COMPLETE - admin_users fallback removed. auth-guards.js consolidation pending.]
   - Single auth module for all pages
   - Remove admin_users fallback once profiles migration complete

5. Complete fs-* page migration
   - Set deadline before next feature sprint
   - Add grep CI check: var(--muted), .chip, .summary-card = fail

6. Create supabase/functions/_shared/ utilities [STARTED]
   - retry.ts, audit.ts, response.ts, supabase.ts
   - `supabase.ts`, `audit.ts`, `response.ts` now exist
   - Expand adoption in new/refactored functions

7. Audit sender-worker vs notification-retry-helper
   - Determine if they can be merged
   - Add trace_id to email pipeline tables

8. Replace React teacher-availability sub-app
   - Rewrite in vanilla JS using fs-* system
   - Eliminate separate build toolchain

9. Per-applicant trace view in system-health
   - Enter email/ID → see full chronological event log
   - Joins: applicants, audit_logs, class_roster,
     scheduled_notifications, email_queue



