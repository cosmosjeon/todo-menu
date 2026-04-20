# Test Spec — Obsidian Menu Bar Todo

## Purpose
Define the verification strategy for v1 of the standalone macOS menu bar todo app so execution can proceed with clear, testable proof of correctness. This spec is aligned to:
- `.omx/plans/prd-obsidian-menu-bar-todo.md`
- `.omx/plans/consensus-plan-obsidian-menu-bar-todo.md`
- `.omx/specs/deep-interview-obsidian-menu-bar-todo.md`

The main risk area is the **markdown contract and direct mutation engine**, so tests prioritize file safety, deterministic writes, and lifecycle correctness before UI polish.

---

## Test Objectives
1. Prove the app reads and writes the canonical markdown contract safely.
2. Prove daily file bootstrap and routine injection are deterministic.
3. Prove external edits do not cause silent corruption.
4. Prove the menu bar workflow satisfies core v1 interactions.
5. Prove resulting files remain portable across CLI and editors like Obsidian.

---

## Quality Gates

### Gate 1 — Domain safety
Must pass before UI-heavy work is considered complete.
- Parser recognizes managed sections and checklist items
- Writer preserves passthrough content
- Toggle/add mutations are deterministic
- Ambiguous targets are rejected safely

### Gate 2 — Lifecycle correctness
Must pass before release-candidate status.
- Today file resolution works
- New day creation works on missing file/date change
- Routine items inject once per new file
- Non-routine items do not auto-carry

### Gate 3 — Interaction correctness
Must pass before ship.
- Menu bar opens in one interaction
- Toggle/add actions update both UI and file
- External edits trigger refresh or safe rejection

### Gate 4 — Portability
Must pass before ship.
- Files remain human-editable plaintext
- Files remain inspectable/editable by CLI
- Files remain usable in Obsidian without conversion or migration

---

## Test Layers

### 1. Unit Tests — Markdown Contract / Domain Core
Focus: parser, writer, mutation engine, identity resolution.

#### Parser coverage
- Parse canonical daily file with all default sections
- Parse file with empty managed sections
- Parse file with preamble before first managed section
- Parse file with unknown sections that must be preserved
- Parse file with non-checklist passthrough lines inside managed sections
- Parse checked and unchecked checklist lines correctly
- Ignore malformed lines rather than mutating them as checklist items

#### Writer / preservation coverage
- Preserve preamble byte-for-byte where possible
- Preserve unknown sections without modification
- Preserve non-checklist lines within managed sections
- Preserve section order when mutating managed content
- Create missing configured section when insertion requires it

#### Mutation coverage
- Toggle unchecked to checked in target section
- Toggle checked to unchecked in target section
- Add new item to explicitly requested section
- Add new item to last-used section
- Fallback to `OTHERS` when no last-used section exists
- Reject toggle when target item cannot be uniquely resolved after re-read
- Reject mutation when duplicate/shifted lines make identity ambiguous

#### Filename/date coverage
- Generate `YYYY-MM-DD TODO.md` for local date
- Resolve today path correctly from configured directory

---

### 2. Integration Tests — Filesystem and Lifecycle
Focus: temp-directory end-to-end behavior using real files.

#### Bootstrap and creation
- If today file is absent, app/service creates new file from scaffold/default contract
- New file includes required managed sections in correct order
- New file includes preserved scaffold/preamble content
- Routine template items are copied into `ROUTINE` during creation
- Routine injection occurs only once for a newly created file
- Existing today file is not overwritten during normal resolution

#### Daily lifecycle
- Date change while app/service is active resolves to new day file
- Wake/reactivation path re-checks date and creates missing file if needed
- No background-only assumptions required when app was not running overnight

#### Mutation integration
- Toggle action mutates underlying markdown file directly
- Add action mutates underlying markdown file directly
- Atomic write path leaves final readable file on success
- If write is interrupted before final rename, next creation attempt remains recoverable

#### Carry-over policy
- Unfinished non-routine items from prior day are not copied into next day file

---

### 3. Conflict / External Edit Tests
Focus: stale-state safety under real file changes.

#### Freshness and re-read behavior
- Mutation path re-reads file before write
- Fingerprint change (mtime/hash) triggers reparse before applying mutation

#### Safe conflict handling
- If external edit preserves unique target resolvability, mutation succeeds on fresh parse
- If external edit creates ambiguity, mutation aborts and signals refresh-required state
- App never silently toggles the wrong duplicate item after external reordering/editing

#### File watcher behavior
- External edit while panel is open triggers refresh/re-render
- Watcher-driven refresh updates visible items to latest file state
- Refresh path does not duplicate routine items or re-bootstrap existing day file

---

### 4. UI / App Behavior Verification
Focus: core menu bar workflow validation.

#### Core UI checks
- Menu bar status item appears after launch
- Clicking menu bar icon opens panel in one interaction
- Panel displays grouped items by section
- Empty state / missing-config state is understandable and recoverable

#### Interaction checks
- Toggle in panel updates visible state and file state
- Quick add inserts visible item without restarting app
- Open current file action opens the current markdown file in default editor/Finder workflow
- Reveal folder action exposes configured daily-notes directory

#### Stale-state UX checks
- External file change while panel is open results in refresh or visible stale-state handling
- Conflict failure does not leave UI claiming success when file was not mutated

---

### 5. Manual Acceptance / Interoperability Tests
Focus: real-world portability and trust.

#### Plaintext portability
- Open created daily file in a normal text editor and verify readability
- Inspect created/modified file with CLI tools (`cat`, `grep`, plain edit) and verify no hidden metadata requirement
- Open same file in Obsidian and confirm checklist/section structure remains usable

#### External edit interoperability
- Modify file externally with editor and reopen/re-render in app successfully
- Modify file externally with CLI/script and verify app refreshes or safely rejects stale writes

#### Real workflow checks
- Create a new day file in a realistic directory structure
- Confirm routine template copy behavior matches expected daily workflow
- Confirm unfinished non-routine tasks remain absent from next day unless manually added

---

## Fixture Corpus
Create fixtures before or alongside the markdown engine.

### Required fixture categories
1. **Canonical valid files**
   - Full file with all default sections
   - Minimal file with empty sections
2. **Preamble preservation files**
   - File with wiki-link/header content before first managed section
3. **Unknown section files**
   - Additional unmanaged heading blocks before/after managed sections
4. **Managed passthrough files**
   - Notes, comments, or non-checklist lines inside managed sections
5. **Ambiguity/conflict files**
   - Duplicate checklist text in same section
   - Reordered lines after rendered snapshot
   - External edit changing both text and checked state
6. **Lifecycle files**
   - Routine template fixture
   - Scaffold/default daily template fixture
   - Existing-today-file fixture to prove no duplicate routine injection

---

## Acceptance Criteria Traceability Matrix

| Acceptance Criterion | Primary Verification | Secondary Verification |
|---|---|---|
| 1. Menu bar icon opens panel within one interaction | Manual UI verification | App smoke test |
| 2. Locate or create current day file on date change | Integration lifecycle tests | Manual rollover simulation |
| 3. Current day file remains plain markdown and human-editable | Plaintext portability checks | Fixture snapshot review |
| 4. Routine items materialize from routine template | Integration bootstrap tests | Manual new-day creation check |
| 5. Checking/unchecking mutates underlying markdown directly | Mutation integration tests | Manual toggle demo |
| 6. Adding new todo mutates underlying markdown directly | Mutation integration tests | Manual quick-add demo |
| 7. Non-routine unfinished todos are not auto-copied | Lifecycle integration test | Manual next-day check |
| 8. Files remain easy for AI CLI and Obsidian to inspect/modify | CLI/editor interoperability checks | No-hidden-metadata review |
| 9. Ambiguous stale-write scenarios fail safely | Conflict tests | Manual stale-edit repro |
| 10. Routine injection happens once per new daily file | Bootstrap idempotency tests | Manual existing-file check |

---

## Milestone Verification Plan

### Slice 1 — File contract and fixtures
**Must prove**
- Canonical grammar is stable
- Fixture corpus covers normal, malformed, and conflicting cases

**Exit evidence**
- Fixture inventory checked in
- Parsing expectations documented against fixtures

### Slice 2 — Markdown engine
**Must prove**
- Parser/writer preserve non-owned content
- Toggle/add are deterministic
- Ambiguity rejection works

**Exit evidence**
- Unit and integration tests passing for core mutation cases

### Slice 3 — Daily lifecycle
**Must prove**
- Today resolution and creation work
- Routine injection works once
- Non-routine carry-over stays off

**Exit evidence**
- Temp-directory lifecycle tests passing

### Slice 4 — Native shell and config
**Must prove**
- App launches with valid config and recovers from invalid/missing paths

**Exit evidence**
- Manual launch/config smoke pass

### Slice 5 — Core UX workflow
**Must prove**
- User can open panel, toggle, and quick-add successfully

**Exit evidence**
- Manual walkthrough with before/after file examples

### Slice 6 — Hardening and release prep
**Must prove**
- Watchers, wake/reactivation, and conflict behaviors are reliable enough for daily use

**Exit evidence**
- Final acceptance matrix complete
- Known limitations documented

---

## Test Environment Assumptions
- Target platform: macOS
- Local filesystem access to user-selected folders/files
- Tests may use temp directories and fixture files
- UI validation may require manual verification if native menu bar automation is limited
- No backend/network dependencies are required for v1 correctness

---

## Known Areas Requiring Manual Verification
Automated coverage is necessary but insufficient for:
- Menu bar panel ergonomics and open behavior
- Wake-from-sleep / foreground reactivation timing
- Finder/editor integration actions
- Real-world Obsidian interoperability check
- Perceived speed of quick open / toggle / add loop

These must be covered in a manual release checklist before claiming v1 complete.

---

## Ship Blockers
Do not call v1 complete if any of the following remain unresolved:
- Mutation engine can toggle/add the wrong item under duplicate/conflict conditions
- External edits can silently overwrite user changes
- Routine items duplicate on existing-day files
- Non-routine tasks auto-carry into next day
- Files require hidden metadata or app-private state to remain usable
- Core menu bar open/toggle/add workflow is not demonstrated end-to-end on macOS

---

## Final Exit Criteria
Planning-quality verification is complete when:
1. The PRD and this test spec agree on contract, scope, and non-goals.
2. Every acceptance criterion has a named verification method.
3. The highest-risk failure modes (file corruption, stale writes, duplicate routine injection) are explicitly tested.
4. Manual checks are identified where automation is insufficient.
5. Execution can proceed without further ambiguity about what “done” means.
