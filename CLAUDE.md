# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A demo/training IT PMO Kanban board for a fictitious bank. The whole app is one file, `index.html`, with a `<style>` block and a `<script>` block. Do not use any real bank's logo or branding; the header uses a plain "IT PMO" text wordmark and a corporate blue palette.

`v2/index.html` is a forest-themed redesign of the same board (v1 stays at `index.html`). It keeps the same script and HTML ids, adds a dark theme, a 4/2/1 column layout for desktop/tablet/phone and a background image embedded as a base64 `data:` URI in the `--photo` token. The same hard constraints apply to it. When the script changes, apply the change to both files.

## Hard constraints (keep these when changing anything)

- Vanilla HTML, CSS and JavaScript only. No frameworks, libraries, npm, bundler or build step.
- Everything stays in `index.html`. It must work when opened by double-clicking (`file://`), with no server.
- No external resources: no CDN scripts, web fonts or image files. Use the system font stack and inline SVG or Unicode glyphs.
- No persistence. Do not use localStorage, sessionStorage, IndexedDB, cookies or any storage API. A refresh resets the board to the seeded demo tasks; the page shows a note saying so.
- The only network call is the FormSubmit AJAX endpoint (`FORMSUBMIT_ENDPOINT`). A FormSubmit failure must never break the board.
- No `alert()` or `confirm()`. Validation errors show inline under fields; delete uses an inline "Delete? Yes / No" panel in the card.
- No `!important` in CSS. Colors and spacing come from custom properties on `:root`.

## Running and testing

There is no build, lint or test tooling. Open `index.html` in a browser.

For automated checks, Playwright and Chromium are available in the cloud container (`require('playwright')`, `chromium.launch()`). Load the page with `page.goto('file:///home/user/repo/index.html')` and drive it. Write test scripts in the scratchpad, not in the repo.

## Script architecture

- **Config at the top of the script:** `FORMSUBMIT_ENDPOINT`, `ID_PREFIX` (`UOB-ITPM-`) and `TOAST_MS`. The HTML comment above `<script>` explains FormSubmit's one-time activation email. While the endpoint still contains `YOUR_EMAIL@example.com`, `notifyNewTask()` throws before sending anything, which produces the warning toast.
- **Reference data:** `COLUMNS` (status and description), `PROJECTS`, `CATEGORIES` and `PRIORITIES` drive the columns, the form selects and the filter selects. The selects are filled by `fillSelect()` in `init()`, so add new options to these arrays, not to the HTML.
- **State:** a single `state = { tasks, filters, ui }` object is the source of truth. `ui` holds which card has its Move panel (`moveOpenId`) or delete confirm (`confirmDeleteId`) open, plus the `sending` flag. `nextIdNumber` is the counter for zero-padded task IDs.
- **Rendering:** `renderBoard()` rebuilds all four columns from state on every change and calls `renderSummary()`. `renderCard()` returns an HTML string. Do not change card contents directly in the DOM; update state and re-render. Every user-supplied value must go through `escapeHtml()` before it goes into HTML.
- **Focus after re-render:** since the board is rebuilt, keyboard focus is restored with `renderAndFocus(selector)` and `cardSelector(id, inner)`. Any new card action should pick a sensible focus target this way.
- **Events are delegated** on `#board`: clicks use `data-action` attributes handled in `handleBoardClick()`. Native HTML5 drag and drop (`wireDragAndDrop()`) also listens on `#board`, uses the `is-drop-target` class for the column highlight and calls `moveTask()` on drop. Escape closes an open card panel (`handleKeydown()`).
- **Add Task flow** (`handleSubmit()`): `readForm()`, then `validateTask()`, then `showFieldErrors()`. On success it is optimistic: `addTask()` renders the card right away, the form resets, a success toast shows, and only then `notifyNewTask()` runs with the submit button in the "Sending…" state. On failure the card stays and a warning toast shows.
- **Dates** are local `YYYY-MM-DD` strings compared as text (`todayISO()`, `toISODate()`); avoid `toISOString()` for dates, as it shifts to UTC. Seed due dates use `daysFromToday()` so the overdue examples stay overdue. A task is overdue when its due date is before today and its status is not Done.
- **Filters** (project, assignee text contains, priority) are applied in `applyFilters()` at render time. Column badges show `shown/total` while a filter is active; the header summary always counts all tasks.

## Layout and accessibility conventions

- Columns are a 4-column CSS grid and stack to one column below 768px.
- Priority is shown by the card's left border color and also by a text pill, so color is never the only signal. Overdue cards get a text "Overdue" badge.
- Icon-only buttons need an `aria-label`. Inputs need a `<label for>`. The toast region is `aria-live="polite"`.
