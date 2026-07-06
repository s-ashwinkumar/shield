# QA Context — Rhythms

## Auth
- App URL: http://localhost:3000
- Login: Google OAuth at /login
- If not logged in (redirected to login page), ASK THE USER to log in manually in the browser, then continue

## Navigation
- Left sidebar: Dashboards, Check-ins, OKRs, People, Settings
- Top bar: Search (mentionable), Notifications bell, User avatar menu
- Breadcrumbs on most pages for navigation context

## Key Pages & Flows
- **Dashboards**: /dashboards → card grid → click card → dashboard detail with widgets
- **Check-ins**: /check-ins → select team dropdown → check-in list → click to expand → fill form → submit
- **OKRs**: /okrs → objective cards → expand → key results → edit inline
- **People**: /people → user list → click user → profile with teams/check-ins
- **Settings**: /settings → tabs (Profile, Team, Integrations, Admin)
- **Superadmin**: /superadmin → only visible to admin users

## Common UI Patterns
- **Tables**: sortable columns, row selection with checkboxes, bulk actions toolbar
- **Modals**: confirmation dialogs, form modals (close with X or Escape)
- **Toast notifications**: bottom-right, auto-dismiss after 5s
- **Empty states**: illustrated placeholder with CTA button when no data
- **Loading**: skeleton loaders (not spinners) for data fetching
- **Inline editing**: click text to edit, Enter to save, Escape to cancel

## Test Data (local dev)
- Seeded via db:seed — check if data exists before testing
- If pages are empty, note it in the report rather than failing

## Common Gotchas
- OAuth redirect: after login, should land back on the page you were trying to access
- Permissions: admin users see edit/delete actions, members see read-only
- Real-time updates: some pages use websockets, changes may appear without refresh
- Next.js hydration: watch for hydration mismatch errors in console
- API errors: check network tab / console for failed requests after interactions
