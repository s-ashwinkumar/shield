---
name: code-review-standards
description: Team coding standards and review checklist
---

## Review Standards

### General
- No unnecessary try/catch or begin/rescue blocks — use framework error handlers
- No duplicate abstractions — check if a helper/component already exists before creating new ones
- No placeholder code, TODO-only fallbacks, or dead code
- No obvious/narrative comments that restate the code
- Verify methods, schema fields, and API signatures exist — don't assume

### Rails (railsapi)
- Follow Packwerk package boundaries
- Use action_policy for authorization
- Write RSpec tests
- Run Rubocop and Brakeman checks
- Follow existing model/controller patterns

### React/Next.js (webui)
- Use existing shadcn/ui components from the design system
- Follow Tanstack Query patterns for data fetching
- Write Vitest unit tests
- Run ESLint and Prettier
- Use TypeScript strictly — no `any` types

### Python (mlai)
- Use pydantic models for data validation
- Follow existing agent/prompt patterns
- Write pytest tests
- Run Ruff and Pyright

### Cross-service
- Validate at system boundaries only (user input, external APIs)
- Prefer integration tests when changes cross service boundaries
- Check for N+1 queries in any database-touching code
- Ensure new endpoints have proper auth/authorization
