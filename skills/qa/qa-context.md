# QA Context — &lt;your app name&gt;

> This file describes your app to the QA agent so it knows how to navigate, log in,
> and what UI patterns to expect. Copy it into your project (e.g.
> `.claude/skills/qa/qa-context.md`) and **customize every section** for your app.
> Delete this banner once you're done.

## Auth
- App URL: &lt;the PR's preview if the project has one (`preview_url_pattern`, e.g. `https://myapp-pr-{pr}.example.com`), else the local URL the app runs on from the worktree, e.g. http://localhost:3000&gt;
- Test accounts: &lt;which account(s) to use, and how the persistent QA browser profile (`~/.shield/qa-chrome`, ensured by `shield browser`) stays signed in&gt;
- Login: &lt;how login works — e.g. "Google OAuth at /login" or "form at /signin"&gt;
- If not logged in (redirected to login page), ASK THE USER to log in manually in the browser, then continue

## Navigation
- &lt;Sidebar structure, top-bar elements, breadcrumbs, etc.&gt;
- Example: "Left sidebar: Dashboards, Settings, Team. Top bar: Search, Notifications, User menu."

## Key Pages & Flows
- &lt;List the main pages and what they do, with URL paths&gt;
- Example:
  - **Home**: `/` → list of items → click item → detail view
  - **Settings**: `/settings` → tabs (Profile, Team, Billing)

## Common UI Patterns
- &lt;Describe recurring UI patterns so the agent recognizes them&gt;
- Examples:
  - Tables: sortable columns, row selection, bulk actions
  - Modals: confirmation dialogs, form modals (close with X or Escape)
  - Toast notifications: position, auto-dismiss timing
  - Empty states: how they look
  - Loading: spinners vs skeletons
  - Inline editing: click-to-edit, Enter to save

## Test Data (local dev)
- &lt;How test data is seeded — `db:seed`, fixtures, etc.&gt;
- If pages are empty, note it in the report rather than failing

## Common Gotchas
- &lt;Things that will confuse an agent — auth redirects, permissions, real-time updates, hydration warnings, etc.&gt;
- Example: "After OAuth login, the user should land back on the page they were trying to access — flag if they don't."
