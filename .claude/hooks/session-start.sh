#!/usr/bin/env bash
# SessionStart hook: prints a short reminder of the project rules.
# Claude Code adds this output to the session context at startup.
cat <<'NOTE'
IT PMO Kanban board: project rules reminder
- Everything stays in index.html (vanilla HTML, CSS, JS). No frameworks, npm or build step.
- Must work from file:// with no server. No CDN scripts, web fonts or image files.
- No storage APIs (localStorage, sessionStorage, IndexedDB, cookies). Refresh resets the board.
- Only network call: FormSubmit AJAX endpoint. A failure must never break the board.
- No alert() or confirm(). No !important. Colors and spacing come from :root custom properties.
- Escape all user input with escapeHtml(). Update state, then re-render.
- Test with Playwright from the scratchpad, not the repo.
See CLAUDE.md for full details.
NOTE
