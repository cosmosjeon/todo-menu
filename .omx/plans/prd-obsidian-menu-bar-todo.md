# PRD — Obsidian Menu Bar Todo

## Overview
Build a standalone macOS menu bar app for daily todo management where **plain local markdown files are the source of truth**. The app should let users quickly view, check, and add todos from the menu bar, while automatically creating each day’s file and injecting routine items from a routine template. Obsidian remains compatible as an editor/viewer, but is not a runtime dependency.

---

## Problem
The current markdown-based workflow is durable and AI-friendly, but too slow for frequent daily interactions. Opening files or Obsidian to check or add items creates friction. The user wants the speed of a native menu bar todo app without giving up:
- plain local markdown ownership
- direct CLI / AI agent access to the same files
- human-editable, portable daily notes

---

## Goals
1. **Fast menu bar workflow** for daily viewing, checking, and adding todos.
2. **Local markdown remains authoritative** with no app-private source-of-truth DB.
3. **Automatic day lifecycle**: resolve/create today’s file on date change.
4. **Routine injection**: copy routine checklist items into each new daily file once.
5. **Safe direct file mutation** under normal external edits.
6. **Compatibility with CLI and Obsidian** without migration or export steps.

---

## Non-Goals
- Notifications, reminders, alarms
- Cloud sync, accounts, backend services
- Automatic carry-over of unfinished non-routine tasks
- Complex filtering, dashboards, tags, or project views
- Obsidian plugin implementation
- Perfect live sync with open Obsidian windows
- Semantic merge of concurrent edits beyond fail-safe refresh

---

## Users / JTBD

### Primary user
A macOS user already managing daily work in markdown and wanting a lighter, always-available interaction surface.

### JTBD
- **When** I want to quickly see today’s tasks, **I want** a menu bar panel, **so I can** check status without opening a full app.
- **When** I finish something, **I want** to toggle it from the menu bar, **so the markdown file updates immediately.**
- **When** I remember a new task, **I want** to add it in one quick interaction, **so capture is low-friction.**
- **When** a new day starts, **I want** today’s file created automatically with routine items included, **so I can begin working immediately.**
- **When** I or an AI tool edit the files outside the app, **I want** the app to stay safe and predictable, **so I never lose trust in the files.**

---

## Product Principles
1. **Markdown is the product contract** — local files are the durable source of truth.
2. **Deterministic over magical** — only mutate clearly owned structures.
3. **Fast enough for repeated daily use** — opening, scanning, toggling, and adding must feel lightweight.
4. **Fail safe on ambiguity** — refresh instead of guessing during conflicting edits.
5. **Portable by default** — files stay easy to inspect and edit in normal tools.
6. **Obsidian-compatible, not Obsidian-dependent** — support the workflow without binding to plugin/runtime APIs.

---

## v1 Scope

### Included
- Standalone native macOS menu bar app
- Menu bar icon + dropdown/panel
- Load current day’s file from configured daily-notes directory
- Auto-create today’s file when absent on day change / app reactivation
- Plain markdown parsing for managed sections
- Toggle checklist items directly in file
- Add new checklist items directly in file
- Routine template parsing and one-time injection into new daily file
- Configurable paths for:
  - daily notes directory
  - routine template file
  - optional daily scaffold/template
- Safe file watching / stale-state refresh behavior
- Open current file / reveal folder actions
- Default section insertion using last-used section, fallback to `OTHERS`

### Explicitly excluded from v1
- Background daemon behavior while app is not running
- Cross-device sync
- Rich metadata, hidden IDs, or custom DB layers
- Automatic migration of legacy files beyond tolerant parsing/preservation
- Auto-copy of incomplete non-routine tasks

---

## UX Flows

### 1. First-time setup
1. User launches app.
2. App prompts for daily notes folder and routine template file.
3. User optionally selects a daily scaffold/template file.
4. App validates paths and saves config.
5. App resolves or creates today’s file and renders panel state.

**Success:** user reaches a working panel with no manual file editing required.

### 2. Open panel and view today
1. User clicks menu bar icon.
2. Panel opens in one interaction.
3. App reads and parses today’s file.
4. Panel shows grouped checklist items by section.

**Success:** panel reflects current file contents.

### 3. Check / uncheck a todo
1. User toggles an item in panel.
2. App re-reads current file before mutation.
3. App resolves target item uniquely.
4. App writes updated markdown atomically.
5. UI refreshes to latest state.

**Failure mode:** if target cannot be resolved uniquely, app aborts mutation and refreshes state.

### 4. Add a new todo
1. User enters text in quick-add field.
2. App inserts item into last-used section or `OTHERS`.
3. App writes updated markdown atomically.
4. UI refreshes with new item visible.

### 5. New day rollover
1. Date changes while app is running, or app becomes active after date changed.
2. App resolves today’s file path.
3. If file does not exist, app creates it using scaffold/default structure.
4. App injects routine items into `ROUTINE`.
5. App renders new day state.

**Success:** routine injection happens once per new file; non-routine items are not auto-carried.

### 6. External edit while app is open
1. User or CLI/editor changes file externally.
2. File watcher detects change.
3. App reparses latest file and refreshes panel.
4. If a mutation was in progress and target is now ambiguous, app aborts safely.

---

## Data / File Contract Summary

### Daily file naming
- `YYYY-MM-DD TODO.md`

### Storage location
- User-configured daily-notes directory

### Canonical v1 file shape
```md
[[실행 허브]]

### ROUTINE
- [ ] Example routine

### SLIT
- [ ] Example task

### SPEC
- [ ] Example task

### OTHERS
- [ ] Example task
```

### Managed sections
V1 default ordered sections:
1. `ROUTINE`
2. `SLIT`
3. `SPEC`
4. `OTHERS`

### Mutation rules
- App manages checklist items inside recognized sections.
- Preamble before first managed section is preserved.
- Unknown sections are preserved and not mutated.
- Non-checklist lines inside managed sections are preserved but not targeted.

### Checklist format
- Unchecked: `- [ ] text`
- Checked: `- [x] text`

### Item identity strategy
V1 uses **position-based identity with ambiguity rejection**, resolved from:
- file path
- section name
- checklist occurrence index
- normalized text snapshot
- checked state snapshot

### Conflict policy
- Re-read before each write
- Compare current fingerprint against rendered snapshot
- If stale, reparse and retry resolution
- If not uniquely resolvable, abort and refresh
- Use atomic replace writes when feasible

### Routine materialization
- Routine source comes from configured template file
- Routine items are copied into `ROUTINE` only when creating a new daily file
- Existing files are not silently re-injected

### Carry-over policy
- No automatic carry-over of unfinished non-routine tasks in v1

---

## Milestones / Slices

### Slice 1 — File contract and fixtures
**Deliverables**
- Locked markdown grammar
- Fixture corpus for valid, malformed, and conflict cases
- Managed vs passthrough behavior defined

**Exit criteria**
- File contract is stable enough to build parser/writer against

### Slice 2 — Markdown engine
**Deliverables**
- Parser for preamble, sections, checklist items
- Writer preserving passthrough content
- Toggle and add mutation logic
- Ambiguity rejection behavior

**Exit criteria**
- Direct file mutation works safely in tests

### Slice 3 — Daily lifecycle
**Deliverables**
- Today file resolver
- New-day file bootstrapper
- Routine materializer
- Rollover triggers on midnight / wake / reactivation

**Exit criteria**
- Today file creation and routine injection behave deterministically

### Slice 4 — Native shell and config
**Deliverables**
- Menu bar app skeleton
- Settings/config flow
- Path validation and persistence

**Exit criteria**
- User can configure folders/files and launch into working state

### Slice 5 — Core UX workflow
**Deliverables**
- Panel rendering by section
- Toggle interaction
- Quick add interaction
- Open/reveal actions
- Stale-state refresh behavior

**Exit criteria**
- Core daily workflow is usable end-to-end

### Slice 6 — Hardening and release prep
**Deliverables**
- File watcher robustness
- Sleep/wake handling
- Packaging/build stability
- Final verification bundle

**Exit criteria**
- Acceptance criteria met with evidence

---

## Risks
1. **Markdown mutation correctness**
   - Risk: corrupting user files or mutating wrong item
   - Mitigation: conservative parser/writer, fixtures, ambiguity rejection, atomic writes

2. **External edit conflicts**
   - Risk: stale panel state causes incorrect writes
   - Mitigation: re-read before write, fingerprint checking, fail-safe refresh

3. **Legacy file variance**
   - Risk: real-world files deviate from ideal shape
   - Mitigation: preserve passthrough regions, lock minimal managed grammar, test against fixtures

4. **macOS menu bar UX edge cases**
   - Risk: awkward panel behavior, wake/rollover bugs
   - Mitigation: dedicated lifecycle coordination and manual validation

5. **Path/config fragility**
   - Risk: moved or invalid folders/templates break app state
   - Mitigation: path validation, clear recovery UX, conservative config handling

6. **Over-scoping v1**
   - Risk: feature creep into reminders, carry-over, advanced organization
   - Mitigation: hold v1 to core menu bar workflow and file contract

---

## Acceptance Criteria
1. App exposes a menu bar icon that opens a dropdown/panel within one interaction.
2. App locates or creates the current day’s markdown file automatically when the date changes.
3. Current day’s file is plain markdown and remains human-editable outside the app.
4. Routine items are materialized from a routine template into the new daily file.
5. Checking/unchecking an item in the app mutates the underlying markdown file directly.
6. Adding a new todo in the app mutates the underlying markdown file directly.
7. Non-routine unfinished todos are not automatically copied into the next day.
8. Resulting files remain easy for AI CLI and editors like Obsidian to inspect and modify.
9. Ambiguous stale-write scenarios fail safely and do not silently corrupt content.
10. Routine injection happens once per newly created daily file.

---

## Launch Checklist

### Product readiness
- [ ] File contract finalized and documented
- [ ] v1 scope held with no reminder/cloud/carry-over creep
- [ ] Settings flow supports required paths cleanly

### Engineering readiness
- [ ] Parser/writer passes fixture coverage
- [ ] Toggle/add mutations verified against temp-directory integration tests
- [ ] Atomic write behavior implemented
- [ ] Conflict detection and ambiguity rejection implemented
- [ ] Daily file bootstrap and routine injection verified
- [ ] Midnight / wake / reactivation resolution verified

### UX readiness
- [ ] Panel opens reliably from menu bar
- [ ] Today view renders expected sections/items
- [ ] Quick add is low-friction
- [ ] Open current file / reveal folder actions work
- [ ] Stale external edits trigger safe refresh behavior

### Interoperability readiness
- [ ] Files remain readable in plain text editors
- [ ] Files remain usable in Obsidian without migration
- [ ] CLI edits are reparsed safely by app
- [ ] No app-private authoritative store exists

### Release evidence
- [ ] Build succeeds on target macOS environment
- [ ] Manual demo of open / toggle / add captured
- [ ] Before/after markdown examples collected
- [ ] Risks and known limitations documented
