# New Staff Page Guide

## Start from Template
1. Copy `foundation/staff/_template.html` to your new page file.
2. Rename title and placeholders.
3. Replace inline module with a dedicated page module once stabilized.

## What to Change Per Page
- `Page Title` in `<title>` and `.fs-page-title`
- `PAGE_KEY` in `FSAdminShell.mount(...)`
- `Primary Action` button text and behavior
- table columns / cards / filters for the page domain
- module import path if moving to `../js/<page>.js`

## Required Boot Pattern
1. Config guard:
   - check `window.FS_CONFIG?.SUPABASE_URL`
   - show not-connected banner and return if missing
2. Auth guard:
   - default admin pages use:
   - `await requireAuth(["admin", "superadmin"])`
3. Shell mount:
   - `window.FSAdminShell?.mount({ active: "PAGE_KEY", pageTitle: "Page Title" })`
4. Data load + render + event binding

## Common Patterns
- Data loading:
  - show loading state first
  - fetch with Supabase
  - render empty state if no rows
- Error states:
  - use `fs-banner fs-banner-danger` for blocking errors
  - use toast for transient actions
- Action flow:
  - disable button while request in flight
  - optimistic UI only when safe
  - log key actions to `audit_logs` where applicable

## `fs-*` Class Cheatsheet
- Page layout:
  - `fs-content`, `fs-page-header`, `fs-page-title`, `fs-page-subtitle`, `fs-page-actions`
- Cards:
  - `fs-card`, `fs-card-header`, `fs-card-title`
- Controls:
  - `fs-action-bar`, `fs-action-bar-search`, `fs-action-bar-actions`
  - `fs-input`, `fs-select`, `fs-textarea`, `fs-btn`, `fs-btn-primary`, `fs-btn-secondary`
- Table:
  - `fs-table-wrap`, `fs-table`, `fs-table-empty`, `fs-table-loading`
- Status:
  - `fs-badge`, `fs-badge-success`, `fs-badge-warning`, `fs-badge-danger`, `fs-badge-info`
- Messaging:
  - `fs-banner`, `fs-banner-info`, `fs-banner-warning`, `fs-banner-danger`, `fs-banner-success`
