# Consensus Plan Draft — obsidian-menu-bar-todo

## Scope Snapshot
- Product type: greenfield macOS menu bar app
- Codebase starting point: no app code yet; only OMX artifacts exist
- Source of truth: `.omx/specs/deep-interview-obsidian-menu-bar-todo.md`
- Product goal: build a local-markdown-first todo app with a macOS menu bar UI, direct markdown mutations, daily file auto-generation, and routine template injection

---

## RALPLAN-DR

### Principles
1. **Local markdown remains authoritative** — the app is an operational layer over user-editable files, not a replacement datastore.
2. **Deterministic mutation beats magical parsing** — v1 should only mutate clearly owned structures and should fail safe on ambiguity.
3. **Menu bar UX must be fast** — open, scan, check, and add should feel lightweight enough for many daily interactions.
4. **Daily lifecycle is explicit** — a new day file is created automatically; routine items are materialized daily; non-routine carry-over stays manual.
5. **Compatibility stays portable** — files remain easy to inspect and edit in CLI, editors, and Obsidian, but the architecture is not bound to Obsidian internals.

### Top Decision Drivers
1. **Plain local file accessibility** for AI CLI and normal editing tools.
2. **Safe, deterministic markdown writes** under real human/CLI external edits.
3. **Reliable macOS menu bar interaction** with low friction and no required backend/private DB.

### Viable Options

#### Option A — Standalone native macOS menu bar app (SwiftUI/AppKit) with direct filesystem reads/writes
**Pros**
- Best fit for menu bar-first UX and startup/responsiveness goals.
- Native access to menu bar/panel behavior, timers, day rollover, and file watching.
- Keeps product independent from Obsidian runtime/plugin APIs.
- Easiest way to keep markdown files as the only source of truth.

**Cons**
- Requires owning parser/writer correctness and file access UX.
- macOS-specific v1.
- Needs explicit user-selected path configuration.

#### Option B — Obsidian plugin with internal panel workflow
**Pros**
- Reuses current vault context and formatting conventions.
- Lower migration risk if legacy layout must stay exactly unchanged.
- Less standalone app shell work.

**Cons**
- Weak fit for true menu bar-first UX because Obsidian remains the runtime anchor.
- Harder to satisfy “always visible / quick dropdown” intent.
- Product becomes subordinate to Obsidian lifecycle and plugin constraints.

#### Option C — Hybrid helper app + embedded web/JS layer over markdown files
**Pros**
- Potentially quicker UI iteration if web stack is preferred.
- Easier future portability.

**Cons**
- More runtime and packaging complexity than v1 needs.
- No meaningful user-value advantage over a small native app at this scope.
- More moving parts around local filesystem authority.

### Recommendation
Choose **Option A: standalone native macOS menu bar app with direct markdown read/write**.

**Bounded rationale**
- It best satisfies the strongest constraints simultaneously: **menu bar-first UX**, **local-md-primary storage**, and **AI CLI direct access**.
- It avoids unnecessary coupling to Obsidian and avoids premature multi-runtime complexity.
- It allows us to define a strong file contract first and layer a native shell on top.

---

## Architecture — File Contract First

### Architectural stance
The highest-risk part of the product is **not the menu bar shell**. It is the **markdown contract + mutation engine**. Therefore the architecture centers on a deterministic file model first and a native shell second.

### High-level layers
1. **File Contract / Domain Layer**
   - canonical daily-file grammar
   - section recognition and ordered checklist model
   - mutation rules and conflict detection
2. **Application Services**
   - `TodayFileResolver`
   - `RoutineMaterializer`
   - `TodoMutationService`
   - `DayRolloverCoordinator`
3. **Filesystem / Config Layer**
   - root paths, template paths, file IO, atomic writes, watcher integration
4. **Menu Bar Shell**
   - status item, dropdown/panel UI, quick add, toggle, open-in-editor/finder actions

---

## Canonical Markdown Contract (locked for v1)

### Daily file naming
- Default filename: `YYYY-MM-DD TODO.md`
- Stored under a configured daily-notes directory

### Daily file shape
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

### Section grammar
- Headings are **level-3 markdown headings** exactly matching known section labels in v1.
- V1 default ordered sections:
  1. `ROUTINE`
  2. `SLIT`
  3. `SPEC`
  4. `OTHERS`
- V1 supports configurable **aliases/order mapping only at app config level**, but not arbitrary nested schemas.
- If a configured section is missing, the app may create it.

### App-managed vs passthrough regions
- **Passthrough preamble**: any content before the first managed `###` section is preserved byte-for-byte where possible.
- **Managed sections**: the app owns checklist lines under recognized sections.
- **Passthrough lines inside managed sections**: non-checklist lines are preserved but never targeted for mutation.
- **Unknown sections**: preserved and rendered only if later explicitly supported; v1 should not mutate them.

### Checklist line contract
- V1 checklist item format remains plain markdown:
  - unchecked: `- [ ] text`
  - checked: `- [x] text`
- No app-private DB.
- No required hidden metadata in v1.

---

## Item Identity Model (locked for v1)

### Decision
Use **position-based identity within app-managed checklist blocks**, with ambiguity rejection.

### Resolution rule
An item is identified by the tuple:
- file path
- section name
- checklist occurrence index within that section
- normalized text snapshot
- checked/unchecked snapshot

### Why this choice
- Preserves human-clean markdown with no hidden IDs/comments.
- Keeps AI CLI/editor friendliness highest for v1.
- Is acceptable because the app will re-read the live file before every mutation.

### Safety rule
If, after re-reading, the target tuple cannot be resolved uniquely (for example due to duplicate edits, line movement, or conflicting external modification), the app must:
1. refuse the mutation,
2. refresh the panel state,
3. ask the user to retry.

This is intentionally conservative and preferable to corrupting the file.

---

## External-edit / Write-conflict Policy (locked for v1)

### Read model
- On panel open: parse current file snapshot.
- On every toggle/add action: re-read file from disk before writing.
- On file watcher event while panel is open: mark UI stale and re-render from latest parse.

### Write model
- Writes are **atomic replace writes** (`write temp -> fsync -> rename`) when feasible.
- Before write, compare current file fingerprint (mtime + content hash) against the last rendered state.
- If fingerprint changed:
  - reparse fresh file,
  - attempt to resolve target item under current contract,
  - if resolution succeeds uniquely, apply mutation to fresh parse and write,
  - if not, abort with refresh-required state.

### Merge stance
- V1 does **not** attempt smart semantic merge of concurrent edits.
- V1 chooses **fail safe + refresh** over surprising merge behavior.

---

## Daily Lifecycle and Rollover Semantics (locked for v1)

### Daily file creation trigger
User requested `auto-create-on-date-change`.

### Concrete behavior
A new daily file is created when either condition occurs:
1. the app is running across local midnight and detects the date changed, or
2. the app next becomes active / panel opens after the date changed and today’s file does not yet exist.

This gives deterministic behavior without requiring a background daemon when the app is not running.

### Time semantics
- Use the user’s current local macOS timezone.
- On wake-from-sleep / foreground reactivation, rerun date-resolution immediately.

### Creation semantics
When creating a new day file:
1. start from configured daily template scaffold (or generated default scaffold)
2. preserve configured preamble/header
3. create required managed sections
4. materialize routines into `ROUTINE`
5. do **not** auto-carry non-routine unfinished tasks from prior days

---

## Routine Materialization Semantics (locked for v1)

### Decision
Use **copy-routine-template-daily**.

### Concrete behavior
- There is a configured routine source/template file.
- On new-day creation, the routine source is parsed and checklist items are copied into the new day’s `ROUTINE` section.
- Routine materialization occurs **only once per new file**.

### Duplicate prevention rule
Daily bootstrap is a **single atomic full-file creation** operation. There is no separate hidden finalization state in v1.
- if today’s file does not exist, the app generates the fully materialized document in memory (preamble + sections + routines) and writes it once atomically.
- if today’s file already exists, routine materialization does not run again automatically.
- if the app crashes before rename/replace completes, no final file exists and the next attempt simply recreates the full file.
- if the final file exists but is malformed or missing expected routine content, v1 treats it as a user-visible recovery case and does **not** silently re-inject routines; instead it surfaces a repair action or requires manual correction.

---

## Configuration and File Access Strategy

### V1 distribution stance
- Prefer a direct-distribution macOS app outside App Store constraints for v1.
- Use explicit user-selected folders/files for:
  - daily directory
  - routine template file
  - optional daily scaffold/template source

### Access persistence
- Persist absolute selected paths in app config for v1.
- If sandboxing becomes necessary later, migrate to security-scoped bookmarks as a follow-up.

### Why this choice
- Keeps local file access simple and robust in v1.
- Avoids premature App Sandbox complexity before product semantics are proven.

---

## Recommended Architecture

### App services
- `ConfigService`
  - stores/validates configured paths and section mapping
- `TodayFileResolver`
  - resolves today’s path and existence
- `DailyFileBootstrapper`
  - creates new day files using scaffold + routines
- `RoutineMaterializer`
  - loads routine template items for insertion
- `MarkdownDocumentParser`
  - parses preamble, managed sections, checklist items, passthrough blocks
- `TodoMutationService`
  - toggle/add with conflict detection and atomic writes
- `DocumentWatchService`
  - file watcher with stale-state refresh notifications
- `DayRolloverCoordinator`
  - handles midnight/wake/reactivation refresh

### UI shell
- menu bar status item
- dropdown/panel containing:
  - current date title
  - grouped sections/items
  - quick add input
  - section chooser/default section behavior
  - refresh / open current file / reveal in finder settings actions

### Default insertion policy
- New items default to the **last-used section** in the current day.
- If no last-used section exists, default to `OTHERS`.

---

## Implementation Slices (reordered by risk)

### Slice 1 — File contract + fixtures
**Goal:** lock the markdown grammar before shell work.
- Define fixture corpus for valid daily files, legacy variants, and conflict cases
- Finalize section recognition and insertion defaults
- Document managed vs passthrough regions

### Slice 2 — Parser, writer, and mutation engine
**Goal:** deterministic direct file mutation with conflict safety.
- Parse managed sections and checklist items
- Toggle checkbox state
- Add items to target section
- Preserve passthrough content
- Implement fail-safe ambiguity rejection

### Slice 3 — Daily lifecycle + routine materialization
**Goal:** reliable day creation semantics.
- Resolve today file path
- Create missing file on day boundary/open
- Inject routines once on new day creation
- Enforce no auto-carry for non-routine todos

### Slice 4 — App foundation + configuration
**Goal:** native app launches and can be pointed at local files.
- Menu bar app skeleton
- settings/config persistence
- path validation and startup state

### Slice 5 — Menu bar workflow UI
**Goal:** core user workflow is fast and usable.
- render today file sections/items
- toggle and quick-add actions
- stale state refresh behavior
- open file/folder actions

### Slice 6 — Watchers, hardening, and packaging
**Goal:** day-to-day reliability.
- file watcher refresh
- sleep/wake rollover behavior
- build/distribution hardening
- final verification bundle

---

## Concrete Deliverables / Steps

1. **Product contract package**
   - file grammar doc
   - section contract
   - fixture set
   - mutation safety rules

2. **Markdown engine package**
   - parser/writer
   - toggle/add mutation logic
   - conflict detection + atomic write support

3. **Lifecycle package**
   - today resolver
   - day creation
   - routine template materialization
   - non-routine non-carry rules

4. **Native shell package**
   - menu bar skeleton
   - config/settings flow
   - panel rendering

5. **Workflow UX package**
   - quick add
   - section defaulting
   - refresh/open actions
   - stale-state handling

6. **Verification/release package**
   - automated tests
   - manual acceptance evidence
   - packaging instructions and known limitations

---

## Test Strategy / Acceptance Criteria Mapping

### Test layers

#### 1) Unit tests — markdown/domain core
- parse known headings and checklist lines correctly
- preserve checked/unchecked state
- preserve passthrough preamble and unmanaged text blocks
- insert new todo into expected section/order
- reject ambiguous mutation targets safely
- generate correct daily filename from local date

#### 2) Integration tests — filesystem lifecycle
- create today file when absent
- seed daily file with scaffold and routines correctly
- prevent second routine injection on existing day file
- toggling mutates markdown file directly
- adding item mutates markdown file directly
- non-routine unfinished todos are not auto-copied on next day
- changed file on disk triggers reparse/refresh behavior

#### 3) UI / app behavior verification
- menu bar icon appears and opens panel in one interaction
- panel reflects current file contents
- toggle action updates visible state and underlying file
- quick add writes and refreshes without reopening app
- stale file change produces safe refresh behavior instead of silent overwrite

#### 4) Manual acceptance checks
- point app to a real markdown directory
- verify resulting files remain readable/editable in editor/Obsidian/CLI
- simulate midnight/wake/reactivation behavior
- verify legacy-like template preamble survives creation

#### 5) Interoperability checks — concrete AC #8 coverage
- create a daily file, then inspect it with standard CLI tools (`cat`, `grep`, plain-text edit) and confirm the app reparses it without migration steps
- modify the file externally with a normal editor or scripted CLI edit, then confirm the app refreshes or safely rejects stale writes instead of corrupting content
- confirm successful end-to-end use without any hidden metadata or app-private store being required for routine open/edit/toggle/add flows

### Acceptance Criteria Mapping
| Spec Acceptance Criterion | Verification Method |
|---|---|
| 1. Menu bar icon opens panel within one interaction | UI verification/manual check |
| 2. Locate or create current day file on date change | Integration test + manual rollover check |
| 3. Daily file is plain markdown and human-editable | Fixture assertion + manual external-edit check |
| 4. Routine items materialize from routine template | Unit/integration tests on bootstrap flow |
| 5. Toggle in app mutates underlying markdown file | Integration test + UI verification |
| 6. Add new todo in app mutates underlying markdown file | Integration test + UI verification |
| 7. Non-routine unfinished todos are not auto-copied | Integration rollover test |
| 8. Files remain easy for AI CLI and editors to inspect/modify | Concrete CLI/editor interoperability checks + external-edit refresh test |

---

## ADR

### Decision
Build **a standalone native macOS menu bar app** whose **only authoritative storage is plain local markdown files** organized as daily todo documents with automatic day creation and daily routine-template materialization.

### Drivers
- need a true menu bar-first interaction model on macOS
- need direct human/AI CLI access to the same files without export/sync indirection
- need deterministic, safe markdown mutations under external edits
- need a practical v1 without remote backend or app-private DB

### Alternatives considered
1. **Obsidian plugin first**
   - Rejected because it weakens the menu bar-first UX and couples the product to Obsidian runtime behavior.
2. **App-private database with markdown export/sync**
   - Rejected because it violates the local-md-primary requirement and increases consistency risk.
3. **Hybrid helper/web-shell architecture**
   - Rejected for v1 because it adds complexity without materially improving the key workflow.

### Why chosen
This is the narrowest design that fully satisfies the strongest requirements: **fast macOS menu bar workflow**, **plain markdown as source of truth**, and **AI CLI accessibility**. The file-contract-first revision makes the biggest technical risk explicit instead of burying it under UI work.

### Consequences
- parser/writer correctness becomes the primary engineering risk
- v1 stays macOS-specific
- app distribution and file access UX need explicit handling
- some mutation cases will deliberately fail-safe and ask the user to refresh rather than guessing at merges

### Follow-ups
- decide whether configurable section aliases ship in v1 or immediately after
- decide whether future stable hidden IDs are worth adding beyond v1
- consider optional manual carry-over helper later
- consider App Sandbox/security-scoped bookmark migration if distribution changes
- consider reminders/search only after file semantics are proven stable

---

## Available Agent Types Roster

### Planning / analysis
- `planner` — sequencing, scope shaping, PRD/test-spec refinement
- `architect` — validate file model, mutation policy, macOS service decomposition
- `critic` — challenge over-design and test-risk gaps

### Implementation
- `executor` — primary build owner for foundation and feature slices
- `designer` — menu bar panel interaction and compact UX review
- `debugger` — investigate file watcher/day rollover/state bugs
- `build-fixer` — resolve macOS build/toolchain issues once code exists

### Verification
- `test-engineer` — fixture design, lifecycle coverage, acceptance mapping
- `verifier` — final evidence-based completion check
- `security-reviewer` — optional review of file permissions/path handling

### Research (optional)
- `researcher` — official macOS API confirmation if native menu bar/window behavior needs validation
- `dependency-expert` — only if a package/framework choice becomes non-trivial

---

## Suggested Staffing Guidance

### If follow-up uses **ralph**
Use a **single-owner execution lane** with milestone specialist consults.
- **Primary owner:** `executor`
- **Consult at milestones:**
  - `architect` after Slice 1/2 to confirm file contract and mutation safety
  - `test-engineer` before Slice 3/5 integration work to lock fixtures and lifecycle tests
  - `verifier` at release-candidate stage
- **Reasoning guidance:**
  - `executor`: high
  - `architect`: high
  - `test-engineer`: medium
  - `verifier`: high
- **Ralph path:**
  1. derive `prd-*.md` and `test-spec-*.md`
  2. execute slices sequentially
  3. verify after each slice boundary
  4. close with acceptance evidence + known risk list

### If follow-up uses **team**
Use a **3-lane coordinated build** after PRD/test-spec artifacts exist.

#### Recommended lane allocation
1. **Lane A — File contract + markdown engine**
   - Agent type: `executor`
   - Scope: domain fixtures, parser/writer, mutation safety
2. **Lane B — Lifecycle + native shell**
   - Agent type: `executor`
   - Scope: today resolver, routine materializer, app shell, config
3. **Lane C — Verification + UX hardening**
   - Agent type: `test-engineer` initially, then `verifier` / `designer`
   - Scope: acceptance/interoperability fixtures, UI checks, stale-edit scenarios, polish findings

#### Team review path
- `architect` reviews shared file/schema contract before parallel build starts
- `critic` optional mid-plan challenge if scope drifts
- `verifier` closes the loop with acceptance evidence

#### Suggested reasoning levels by lane
- Lane A `executor`: high
- Lane B `executor`: high
- Lane C `test-engineer`: medium; `verifier`: high; `designer`: medium/high

#### Team launch hints
- Keep write ownership separated:
  - Lane A owns domain fixtures, file contract, parser/writer, mutation tests
  - Lane B owns lifecycle services, shell/config, app integration
  - Lane C owns acceptance/interoperability fixtures, acceptance docs, UI verification assets
- Rejoin after Slice 3 boundary before final polish to avoid schema churn mid-build

---

## Concrete Verification Path

### Required evidence before calling v1 complete
1. **Build evidence**
   - App builds cleanly in target macOS environment.
2. **Core workflow evidence**
   - Screenshot/video proof of menu bar open, toggle, and quick add.
3. **Filesystem evidence**
   - Before/after markdown fixtures showing direct file mutation.
4. **Lifecycle evidence**
   - Test or controlled simulation showing new-day file creation and routine injection.
5. **Negative evidence**
   - Test proving unfinished non-routine items are not auto-carried.
6. **Conflict evidence**
   - Test proving stale external edits fail safe and refresh instead of corrupting data.
7. **Interoperability evidence**
   - Manual check that resulting files stay readable/editable in a normal editor/Obsidian and inspectable by CLI.

### Verification sequence
1. Unit tests for parser/writer and conflict logic
2. Integration tests against temp directories for daily lifecycle and routine injection
3. Manual app run to verify menu bar interaction
4. Manual external-edit interoperability check
5. Final verifier pass against all eight acceptance criteria plus conflict-safety evidence

### Exit criteria
The product is ready for initial use when:
- all eight spec acceptance criteria are satisfied,
- no app-private authoritative store exists,
- routine duplication is prevented,
- date rollover behavior is deterministic,
- stale external edits fail safe,
- and the app’s core flow is fast enough for repeated daily use.

---

## Immediate Next Planning Artifacts
To unblock `ralph` or `team`, create next:
1. `.omx/plans/prd-obsidian-menu-bar-todo.md`
2. `.omx/plans/test-spec-obsidian-menu-bar-todo.md`

These should lock:
- product contract / non-goals
- canonical file schema and managed-region rules
- implementation ownership by slice
- test fixtures, conflict cases, and acceptance cases
