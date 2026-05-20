# Rock Solid Ops — Operations Platform

> **RockSolid OPS** — Internal staff operations platform for Foundation School.  
> Manages student registration, teacher scheduling, attendance, cohort batches, notifications, Moodle enrollment, and milestone tracking.  
> **Status: MVP Ready — Supabase-first backend, pilot launch ready (May 2026).**

---

> 💼 **Summary:** Full production operations platform for a school — replaced a legacy Google Sheets + Apps Script backend with Supabase edge functions, a multi-stage email pipeline with retry/trace infrastructure, Moodle LMS sync, and a staff portal managing the full student lifecycle from registration to graduation.

---

## Architecture Overview

```
                        ┌─────────────────────┐
                        │  Public Registration │
                        │        Form          │
                        └──────────┬──────────┘
                                   │ POST
                                   ▼
                    ┌──────────────────────────────┐
                    │    registration-processor     │  ← Single canonical intake
                    │  (Supabase Edge Function)     │
                    └───┬──────────┬───────────┬───┘
                        │          │           │
               ASSIGNED │   WAITLISTED    DUPLICATE/REVIEW
                        │          │           │
                        ▼          ▼           ▼
              ┌──────────────┐  ┌────────┐  ┌──────────────┐
              │ moodle-sync  │  │Waitlist│  │  Admin Review │
              │  (enroll)    │  │ Queue  │  │    Portal     │
              └──────┬───────┘  └────────┘  └──────────────┘
                     │
              ┌──────┴────────────────────────────────────┐
              │              Notification Pipeline         │
              │                                           │
              │  scheduled_notifications (PENDING)        │
              │            ↓                              │
              │  notification-batch-processor             │
              │            ↓                              │
              │  email_queue (Pending)                    │
              │            ↓                              │
              │  email-sender (cron 07:00 EST) → Resend   │
              └───────────────────────────────────────────┘
                     │
              ┌──────┴──────────────────────────────────────────┐
              │               Operations Layer                   │
              │                                                  │
              │  retry-worker (*/20min) ─── Moodle retry sweep  │
              │  missed-class-detector ──── Nightly gap check   │
              │  clickup-sync ───────────── Escalation tasks    │
              │  student-engagement-monitor  At-risk detection  │
              │  report-generator ───────── Scheduled reports   │
              └──────────────────────────────────────────────────┘
                     │
              ┌──────┴──────────────────────────────────────────┐
              │               Staff Portals                      │
              │                                                  │
              │  Admin Portal     (/staff/)   ── superadmin/admin│
              │  Teacher Portal   (/teacher/) ── teacher role    │
              │  System Health    (/staff/)   ── Ops trace + KPIs│
              │  Retry Center     (/staff/)   ── Failure recovery│
              └──────────────────────────────────────────────────┘
                     │
              ┌──────┴──────────────────────────────────────────┐
              │            Supabase Postgres (RLS on all tables) │
              │                                                  │
              │  applicants · students · batches · class_options │
              │  teachers · attendance_records · milestones      │
              │  scheduled_notifications · email_queue           │
              │  moodle_enrollment_sync · audit_logs             │
              │  clickup_task_links · report_archive             │
              └──────────────────────────────────────────────────┘
```

---

## Table of Contents

1. [What This Is](#what-this-is)
2. [Tech Stack](#tech-stack)
3. [Repository Structure](#repository-structure)
4. [Core Features](#core-features)
   - [Registration Pipeline](#1-registration-pipeline)
   - [Admin Portal](#2-admin-portal)
   - [Teacher Portal](#3-teacher-portal)
   - [Batch & Class Management](#4-batch--class-management)
   - [Attendance & Session Outcomes](#5-attendance--session-outcomes)
   - [Milestones](#6-milestones)
   - [Notifications & Email Pipeline](#7-notifications--email-pipeline)
   - [Moodle Enrollment Sync](#8-moodle-enrollment-sync)
   - [Retry & Recovery Center](#9-retry--recovery-center)
   - [ClickUp Escalation](#10-clickup-escalation)
   - [Waitlist Processor](#11-waitlist-processor)
   - [Student Engagement Monitoring](#12-student-engagement-monitoring)
   - [Reports & Data Exports](#13-reports--data-exports)
   - [System Health & Operational Trace](#14-system-health--operational-trace)
   - [Fellowship & Subgroup Management](#15-fellowship--subgroup-management)
   - [Audit Logging](#16-audit-logging)
   - [Auth & RBAC](#17-auth--rbac)
5. [Edge Functions Reference](#edge-functions-reference)
6. [Cron Schedule](#cron-schedule)
7. [Status Enums](#status-enums)
8. [Deployment](#deployment)
9. [Environment Variables / Secrets](#environment-variables--secrets)
10. [Known Issues](#known-issues)
11. [Tech Debt Register (Summary)](#tech-debt-register-summary)
12. [Security Rules](#security-rules)
13. [Legacy Archive](#legacy-archive)

---

## What This Is

Foundation School is an **internal staff operations platform** — not a public SaaS product. It is used by admins, regional secretaries, and teachers to run the full student lifecycle:

- Accept and process new student registrations (from a public-facing form)
- Assign students to batch cohorts and class options
- Manage teacher availability, assignments, and attendance
- Sync enrolled students into Moodle courses
- Send lifecycle emails (welcome, waitlist, review, rejection, reminders)
- Track student milestones and engagement
- Surface failures, retries, and audit events to staff operators

The backend migrated from Google Apps Script + Google Sheets to **Supabase Postgres + Edge Functions** (completed May 2026). The legacy backend is archived and non-operational.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Database | Supabase Postgres (public schema) |
| Auth | Supabase Auth (JWT sessions) |
| Backend logic | Supabase Edge Functions (Deno / TypeScript) |
| Frontend | Plain HTML / CSS / Vanilla JS (no framework) |
| Email delivery | Resend API |
| LMS sync | Moodle REST Web Services API |
| Task escalation | ClickUp API |
| Newsletter sync | Mailchimp API ⚠️ Dormant — using Resend |
| Hosting | Vercel (static frontend) + Supabase (functions) |
| Design tokens | Custom CSS variables (`tokens.css`, `primitives.css`) |
| Font | Manrope (Google Fonts) |

---

## Repository Structure

```
/
├── foundation/
│   ├── auth/               # Auth pages (login, register, reset, logout)
│   ├── staff/              # All admin/staff HTML pages
│   ├── teacher/            # Teacher portal HTML pages
│   ├── js/                 # Shared JS modules
│   ├── ui/                 # Shared CSS (tokens, components, layout, primitives)
│   └── docs/               # Engineering docs (architecture, constraints, known bugs)
├── supabase/
│   ├── functions/          # All Supabase Edge Functions
│   │   ├── _shared/        # Shared utilities (audit, http, supabase client, assign lib)
│   │   └── <function>/     # One directory per edge function
│   └── migrations/         # All Postgres migrations (additive, timestamped)
├── ai/                     # AI/Claude context docs (constraints, statuses, roadmap)
├── archive/
│   └── apps-script-legacy/ # Retired Google Apps Script (read-only reference)
└── vercel.json             # Vercel routing config
```

---

## Core Features

### 1. Registration Pipeline

**Canonical path: `registration-processor` edge function only. No second registration path exists.**

- Accepts POST payloads from the public registration form
- Validates and normalizes applicant data
- Writes operational records to `applicants` and related tables
- Resolves fellowship and subgroup from the payload
- Determines registration outcome:
  - `PENDING` → awaiting assignment
  - `ASSIGNED` → placed in a class option
  - `WAITLISTED` → no available class; placed on waitlist
  - `DUPLICATE` → matching record already exists; surfaced to admin
  - `REVIEW` → flagged for manual review
- Fires downstream notifications (welcome email, waitlist confirmation, etc.)
- Writes `trace_id` for end-to-end pipeline tracing
- All events written to `audit_logs`

**Key rules:**
- WAITLISTED students are never enrolled in Moodle — only ASSIGNED students
- DUPLICATE status must be preserved and surfaced; never silently overwritten
- One pipeline, one source of truth

---

### 2. Admin Portal

Located at `foundation/staff/`. All pages use the shared `admin-shell.js` nav and auth layer.

| Page | Purpose |
|---|---|
| `admin-dashboard.html` | Operational overview and KPIs |
| `admin-portal.html` | Primary registration review hub |
| `admin-review.html` | Per-applicant review and assignment actions |
| `admin-management.html` | Admin user management |
| `applicant-directory.html` | Searchable directory of all applicants |
| `batch-management.html` | Cohort batch creation and scheduling (canonical UI reference) |
| `class-editor.html` | Create and edit class options within batches |
| `teacher-management.html` | Teacher profiles, status transitions, direct-add |
| `teacher-schedule.html` | Teacher class assignment schedule view |
| `waitlist.html` | Waitlist queue management |
| `fellowship-management.html` | Fellowship and subgroup configuration |
| `milestones-admin.html` | Milestone definitions and student status |
| `at-risk-students.html` | At-risk student flag and escalation view |
| `email-campaigns.html` | Outbound email campaign management |
| `notification-center.html` | Notification queue monitoring |
| `failed-sync-retry-center.html` | Moodle sync and notification failure retry |
| `system-health.html` | Integration health + Operational Trace debugger |
| `audit-log.html` | Full audit log browser |
| `role-audit.html` | RBAC role inspection |
| `reports.html` | Scheduled and on-demand reports |
| `baptism-report.html` | Water baptism milestone report |
| `data-exports.html` | CSV/export data downloads |
| `dashboards.html` | Dashboard aggregates |
| `moodle-settings.html` | Moodle connection configuration |
| `env-check.html` | Environment variable verification |

---

### 3. Teacher Portal

Located at `foundation/teacher/`. Uses `teacher-shell.js` and teacher-scoped JWT auth.

- Teachers log in with Supabase Auth accounts linked to their teacher profile
- Self-registration at `foundation/auth/teacher-register.html`
- Submit availability (days/times/campus) for scheduling
- View assigned class options and student roster
- Submit session attendance (mark present / absent / late-start)
- Submit session outcomes and notes
- Update student milestone statuses
- View own assignment history and class progress grid

**Teacher API:** All teacher actions are routed through the `teacher-portal-api` edge function, which enforces JWT verification and class ownership checks before every action.

---

### 4. Batch & Class Management

- Batches represent cohort intake cycles with a status lifecycle: `DRAFT → UPCOMING → ACTIVE → COMPLETED → ARCHIVED`
- Each batch contains one or more class options (day/time/campus combinations)
- Class options support multi-campus configurations (including online / multi-campus flags)
- Admin can create batches, add class options, set capacity, assign teachers, and manage rollover
- `subgroup_id` is tracked on both batches and applicants for regional grouping
- Class selection token flow: admins can generate tokens for targeted class self-selection by waitlisted students
- Batch rollover email notifications supported via template

---

### 5. Attendance & Session Outcomes

- Attendance records stored in `attendance_records` (Supabase table)
- Deduplication enforced via upsert with conflict guard migration
- Session outcomes stored separately from raw attendance for reporting flexibility
- Teachers submit attendance per-session via `TeacherAttendancePortal.html` or teacher portal
- Late-start status supported (`attendance_late_start_status` migration)
- Attendance reminders sent automatically via `attendance-reminder` edge function (cron-scheduled)
- Missed-class detection runs nightly via `missed-class-detector` edge function
- `StudentProgressView.html` provides per-student attendance and outcome overview

---

### 6. Milestones

- Milestone definitions are admin-managed (table: `milestone_definitions`)
- Student milestone statuses are tracked per student per milestone
- Special milestone: `water_baptized` (added May 2026)
- Role policy: admin and superadmin can update student milestone statuses
- Teacher portal surfaces milestones per session for teacher input
- Baptism report available at `baptism-report.html`

---

### 7. Notifications & Email Pipeline

Three-stage pipeline — each stage has exactly one active function:

```
scheduled_notifications (status=PENDING, due)
        ↓
notification-batch-processor   ← canonical batch queuer
        ↓
email_queue (status=Pending)
        ↓
email-sender (cron: daily 07:00 EST)   ← canonical Resend delivery
```

**Email templates** (stored in `email_templates` table with `{{variable}}` substitution):

| Template Key | Trigger |
|---|---|
| `foundation_welcome` | New registration assigned |
| `duplicate_registration` | Duplicate detected |
| `waitlist_confirmation` | Student waitlisted |
| `registration_under_review` | Status = REVIEW |
| `no_suitable_times` | No matching availability |
| `no_class_available` | No class to assign to |
| `teacher_approved` / `teacher_rejected` | Teacher application decision |
| `batch_rollover` | Batch rollover notification |
| `class_reassignment_notice` | Student reassigned to different class |
| `attendance_reminder` | Pre-session attendance reminder |
| `missed_class_checkin` | Post missed-class follow-up |
| `review_checkin` | Applicant stuck in REVIEW > 48h |
| `teacher_status_*` | Teacher lifecycle status changes |
| `direct_message` | Admin ad-hoc direct message |
| `moodle_credentials` | Moodle login credentials |

**Retry Center** handles stuck/failed notifications via `notification-retry-helper` (single-item reset only — never runs as a batch processor).

**Trace IDs** flow from registration → scheduled_notifications → email_queue → moodle_enrollment_sync for end-to-end tracing.

**In-app notifications** supported via `in_app_notifications` table (May 2026).

---

### 8. Moodle Enrollment Sync

- Edge function: `moodle-sync`
- Only ASSIGNED students are enrolled — never WAITLISTED
- Enrollment queue: `moodle_enrollment_sync` table
- Looks up or creates Moodle user account, then enrolls into the correct course
- Moodle course mapping via `batch_moodle_courses` table (nullable `course_id` supported)
- Failure classification (stored in `failure_reason` column):

| Code | Retryable | Meaning |
|---|---|---|
| `MOODLE_WAF_BLOCK` | Yes (transient) | Cloudflare/WAF blocked the request |
| `MOODLE_REST_DISABLED` | No | REST protocol not enabled in Moodle |
| `MOODLE_PERMISSION_DENIED` | No | Token lacks required API functions |
| `MOODLE_403_UNKNOWN` | No | Unclassified 403 |

- `retry-worker` sweeps retryable failures every 20 minutes
- Non-retryable failures surface immediately to the Retry Center for operator action
- Moodle grade sync: `moodle-grade-sync` edge function (cron: `202605171900` migration)
- Moodle credentials email sent after successful enrollment

**Required Moodle functions:** `core_webservice_get_site_info`, `core_user_get_users`, `core_user_create_users`, `enrol_manual_enrol_users`

---

### 9. Retry & Recovery Center

`failed-sync-retry-center.html` + `retry-worker` edge function

- Lists all failed/stuck Moodle sync rows and notification rows
- Operators can manually retry, resolve, or dismiss individual failures
- Auto sweep (`retry-worker`, cron every 20 min) retries only retryable Moodle failures
- Manual retry for notifications via `notification-retry-helper`
- All retry actions are audited to `audit_logs`

---

### 10. ClickUp Escalation

- Edge function: `clickup-sync`
- Creates ClickUp tasks for missed-class events and registrations stuck in REVIEW > 48h
- `missed-class-detector` edge function runs nightly and feeds the escalation queue
- Idempotency: `clickup_task_links` table prevents duplicate tasks for the same event
- Assignee resolution: `clickup_admin_mappings` table (subgroup match first, group-level fallback)
- Optional secondary watchers: `clickup_admin_watchers` (same resolution order)
- Watcher comment failures are non-blocking
- No API keys in the mapping tables — all in Supabase secrets

**Required secrets:** `CLICKUP_API_KEY`, `CLICKUP_LIST_ID`, `CLICKUP_DEFAULT_ASSIGNEE_ID`

---

### 11. Waitlist Processor

- Edge function: `waitlist-processor`
- When a class option opens capacity, waitlisted applicants are auto-evaluated
- `waitlist_class_available_auto_notify` migration (May 2026): triggers notification when a slot opens
- Class selection tokens allow targeted self-selection by waitlisted students (`class_selection_tokens` table)
- Waitlist management UI at `waitlist.html`

---

### 12. Student Engagement Monitoring

- Edge function: `student-engagement-monitor` (cron)
- Tracks attendance gaps and engagement signals
- `student_engagement_tracking` table (May 2026)
- At-risk flag trigger: `at_risk_trigger` migration
- At-risk students surfaced in `at-risk-students.html`
- `review-checkin` edge function sends follow-up emails for applicants in REVIEW > 48h

---

### 13. Reports & Data Exports

- `report-generator` edge function produces scheduled and on-demand reports
- Reports archived in `report_archive` table
- Cron-triggered report generation via `report_crons` migration
- Data exports available at `data-exports.html`
- Export utilities in `foundation/js/export-utils.js`
- Dashboard KPI RPCs: `dashboard_rpcs` migration; teacher KPIs: `dashboard_teacher_kpis`

---

### 14. System Health & Operational Trace

`system-health.html` + `foundation/js/system-health.js` + `foundation/js/operational-trace.js`

- Integration health checks (Moodle connection status, email queue health, function status)
- **Operational Trace MVP**: per-applicant end-to-end timeline debugger
  - Search by applicant email, applicant ID, student ID, or registration ID
  - Powered by SQL RPC `public.get_operational_trace(...)`
  - Shows chronological events across: applicants, students, class_roster, moodle_enrollment_sync, scheduled_notifications, email_queue, audit_logs, sync_log
  - Read-only; admin-only access; SECURITY DEFINER with `search_path = public`

---

### 15. Fellowship & Subgroup Management

- Fellowships represent church campuses or geographic groups
- Subgroups represent smaller divisions within a fellowship (e.g., service times, campuses)
- `fellowship_management.html` for admin configuration
- `fellowship_map` table with nullable `group_id` (May 2026 hardening)
- Applicants carry `group_id` and `subgroup_id` (backfill migrations included)
- Regional secretary role introduced May 2026 for scoped admin access
- Registration flow supports regional fellowship codes for multi-campus intake

---

### 16. Audit Logging

- **Canonical table:** `public.audit_logs`
- Every significant action writes: `action`, `actor_id`, `target_id`, `metadata`
- All edge functions, RPCs, and admin actions write to this table
- `audit-log.html` provides full browser UI for admins
- `role-audit.html` surfaces RBAC-specific audit events

---

### 17. Auth & RBAC

- Auth: Supabase Auth (email/password, JWT sessions)
- Roles (stored in `profiles.role`):

| Role | Access |
|---|---|
| `superadmin` | Full platform access; can delete batches, manage definitions |
| `admin` | Full operational access; cannot delete batches |
| `regional_secretary` | Scoped to their fellowship/region |
| `teacher` | Teacher portal only; scoped to their classes |

- RLS (Row Level Security) enforced on every table — client-side role checks are UI hints only
- New tables must have RLS enabled before shipping
- Auth pages: `foundation/auth/login.html`, `teacher-register.html`, `reset-password.html`
- Auth client: `foundation/auth/auth-client.js`
- Auth guards: `foundation/auth/auth-guards.js`

---

## Edge Functions Reference

| Function | Schedule | Role |
|---|---|---|
| `registration-processor` | On-demand (webhook) | Canonical registration intake |
| `admin-api` | On-demand | Admin portal API router |
| `teacher-portal-api` | On-demand | Teacher portal API router |
| `phase2-processor` | On-demand | Assignment processing (being consolidated) |
| `moodle-sync` | On-demand (queue-driven) | Moodle enrollment |
| `moodle-grade-sync` | Cron | Moodle grade pull |
| `retry-worker` | `*/20 * * * *` | Moodle retry sweep |
| `notification-batch-processor` | On-demand | Scheduled notification → email_queue |
| `email-sender` | `0 12 * * *` (07:00 EST) | Resend delivery |
| `email-retry` | On-demand | Email queue retry helper |
| `notification-retry-helper` | On-demand (Retry Center only) | Single-notification reset |
| `notification-dispatcher` | On-demand | Notification routing |
| `missed-class-detector` | `15 2 * * *` (02:15) | Nightly attendance gap detection |
| `attendance-reminder` | Cron | Pre-class attendance reminders |
| `review-checkin` | Cron | REVIEW > 48h follow-up |
| `student-engagement-monitor` | Cron | Engagement gap detection |
| `clickup-sync` | On-demand | ClickUp task creation |
| `waitlist-processor` | On-demand | Waitlist slot evaluation |
| `class-selection` | On-demand | Class selection token handler |
| `mailchimp-sync` | ⚠️ Dormant | Not in use — using Resend |
| `report-generator` | Cron | Scheduled report archive |
| `reminder-processor` | ⚠️ Do not schedule | Legacy stub |

---

## Cron Schedule

| Time | Function |
|---|---|
| Every 20 min | `retry-worker` |
| Daily 07:00 EST (12:00 UTC) | `email-sender` |
| Daily 02:15 UTC | `missed-class-detector` |
| See config.toml | `attendance-reminder`, `review-checkin`, `student-engagement-monitor`, `report-generator`, `moodle-grade-sync` |

**Never schedule:** `notification-retry-helper`, `reminder-processor`

---

## Status Enums

Do not invent new values without updating `/ai/statuses.md`.

```
Registration:   PENDING | ASSIGNED | WAITLISTED | DUPLICATE | REVIEW | INACTIVE | COMPLETED
Batch:          DRAFT | ACTIVE | UPCOMING | COMPLETED | ARCHIVED
Teacher avail:  PENDING | APPROVED | REJECTED | RESET
Availability:   CLASS_ASSIGNED | CLASS_FULL | NO_MATCHING_TIME | MANUAL_REVIEW_REQUIRED
Email:          foundation_welcome | duplicate_registration | waitlist_confirmation |
                registration_under_review | no_suitable_times | no_class_available
```

---

## Deployment

### Pre-deploy

1. Create `foundation/js/config.js` from `foundation/js/config.js.example`
2. Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in config
3. Set all Supabase secrets (see below)
4. Run `supabase db push` (applies all pending migrations)
5. Run `supabase functions deploy` (deploys all edge functions)
6. Confirm `ALLOWED_ORIGINS` includes your Vercel/Netlify domain

### Post-deploy Verification

- [ ] Login works
- [ ] Registration form loads fellowships
- [ ] Admin portal loads and shows data
- [ ] Teacher portal loads
- [ ] Email sends within 15 minutes of registration
- [ ] Moodle connection shows green in `system-health`
- [ ] All system health checks pass

### Rollback

1. Revert Vercel/Netlify deploy to previous successful build
2. Redeploy prior edge function versions from previous commit
3. If migrations caused breakage: apply a forward-fix migration (preferred over restore)
4. Re-run smoke checks

---

## Environment Variables / Secrets

All set via `supabase secrets set KEY="value"`:

| Secret | Required | Purpose |
|---|---|---|
| `SUPABASE_URL` | ✅ | Supabase project URL |
| `SUPABASE_ANON_KEY` | ✅ | Public anon key (frontend) |
| `SUPABASE_SERVICE_ROLE_KEY` | ✅ | Service role key (edge functions) |
| `ALLOWED_ORIGINS` | ✅ | CORS allowed origins |
| `RESEND_API_KEY` | ✅ | Email delivery |
| `MOODLE_URL` | ✅ | Moodle site base URL |
| `MOODLE_TOKEN` | ✅ | Moodle web service token |
| `MAILCHIMP_API_KEY` | ⚠️ Dormant | Not in use — using Resend |
| `MAILCHIMP_SERVER_PREFIX` | ⚠️ Dormant | — |
| `MAILCHIMP_AUDIENCE_ID` | ⚠️ Dormant | — |
| `CLICKUP_API_KEY` | ✅ | ClickUp escalations |
| `CLICKUP_LIST_ID` | ✅ | Target ClickUp list |
| `CLICKUP_DEFAULT_ASSIGNEE_ID` | ✅ | Fallback ClickUp assignee |
| `PHASE2_WEBHOOK_SECRET` | ✅ | Phase 2 processor auth |
| `ATTENDANCE_ADMIN_EMAIL` | ✅ | Attendance admin contact |
| `TEACHER_PORTAL_URL` | ✅ | Teacher portal public URL |

> **Never commit `config.js` with real credentials.** It is gitignored.  
> **Rotate the anon key if it was ever committed.**

---

## Known Issues

| Issue | Location | Status |
|---|---|---|
| CLASS_OPTIONS creation failure on approval flow | `phase2-processor`, `admin-review` | ✅ Fixed |
| Multi-campus label shows only last campus | Batch calendar header | ✅ Fixed |
| Large tables overflow on mobile | `admin-management.html` and others | ✅ Fixed |
| Moodle HTTP 403 / WAF blocks enrollment sync | `moodle-sync` edge function | External (Hostinger WAF) |

---

## Tech Debt Register (Summary)

| # | Area | Risk | Target |
|---|---|---|---|
| 2 | Assignment pipeline duplicated in `registration-processor` + `phase2-processor` | High | Q3 2026 |
| 3 | `fs-*` CSS migration incomplete on some pages | Medium | Q3 2026 |
| 5 | Schema fallback loops in some edge functions | Medium | Q4 2026 |
| 6 | Per-page style blocks (should be in `primitives.css`) | Medium | Q4 2026 |
| 7 | Teacher availability React sub-app (separate build chain) | Medium | Q4 2026 |
| 9 | Legacy CSS primitives alongside `fs-*` | Medium | Q4 2026 |
| 10 | Audit table legacy fallback paths in some functions | Medium | Q3 2026 |
| 11 | Confusing notification function naming (`notification-retry-helper` sounds canonical) | High | Q3 2026 |

Items 1, 4, 8 marked **RESOLVED** as of May 2026.

---

## Security Rules

Before any PR:

- [ ] No real credentials in any committed file
- [ ] Every new table has RLS enabled
- [ ] Every new privileged edge function verifies JWT role server-side
- [ ] No new client-side-only role enforcement added
- [ ] No legacy backend references reintroduced
- [ ] `config.js` is not staged (`git status`)
- [ ] Migration is additive and idempotent

**Never:**
- Add a second registration pipeline
- Enroll a WAITLISTED student in Moodle
- Drop RLS from a table
- Bypass auth with the service role key on a public-facing path
- Commit real Supabase credentials

---

## Legacy Archive

`archive/apps-script-legacy/` contains the original Google Apps Script + Google Sheets backend. This is **read-only historical reference** — it is not operational, not connected to any live data, and must never be used as a runtime backend.

---

*Generated May 2026 — keep updated as the platform evolves.*S
