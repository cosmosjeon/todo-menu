# Deep Interview Spec — obsidian-menu-bar-todo

## Metadata
- Generated at: 2026-04-20T05:22:34Z
- Profile: standard
- Rounds: 11
- Final ambiguity: 3.4%
- Threshold: 20%
- Context type: greenfield with external brownfield evidence
- Context snapshot: `.omx/context/obsidian-menu-bar-todo-20260420T045501Z.md`
- Transcript summary: `.omx/interviews/obsidian-menu-bar-todo-20260420T052234Z.md`

## Clarity breakdown
| Dimension | Score | Notes |
|---|---:|---|
| Intent | 0.95 | 항상 보이고 빠르게 체크/추가하고 싶음 |
| Outcome | 0.95 | 메뉴바 패널 + local-md-first workflow가 명확 |
| Scope | 0.90 | v1에 보기/체크/추가/자동생성/루틴복사 포함 |
| Constraints | 0.96 | local markdown, AI CLI 접근성, menu bar UX가 핵심 |
| Success | 0.84 | daily lifecycle와 routine semantics까지 명시됨 |
| Context | 1.00 | 기존 vault/template usage 확인됨 |

## Intent (why)
사용자는 인간이 쓰기 쉬운 로컬 markdown 파일을 일정/투두의 source of truth로 유지하면서, AI CLI도 같은 파일에 직접 접근할 수 있게 하고 싶다. 동시에 macOS 메뉴바에서 빠르게 보고 체크하고 추가할 수 있는 가벼운 일상 UX를 원한다.

## Desired Outcome
A local-markdown-first todo app with:
- a macOS menu bar dropdown panel
- daily note auto-generation on date change
- recurring routine template injection each day
- direct read/write to local markdown files
- compatibility with Obsidian as an optional viewer/editor, not as the product core

## In-Scope
- macOS 메뉴바 앱 shell
- compact dropdown/panel UI (ToDoBar-like)
- current-day markdown file discovery/creation
- direct markdown read/write
- checklist toggle
- new item insertion
- routine template copying into each new day file
- section-aware organization (`ROUTINE`, `SLIT`, `SPEC`, `OTHERS` or evolved equivalent)
- local file structure that AI CLI can inspect and modify

## Out-of-Scope / Non-goals (first version)
- notifications / reminders
- automatic carry-over of non-routine TODOs
- complex filters, tags, or project dashboards
- internal app-only database as authoritative store
- perfect live UI sync with Obsidian windows
- cloud backend / account system

## Decision Boundaries
OMX may decide without confirmation:
- app architecture and tech stack
- file/folder conventions if they preserve local-md-primary goals
- menu bar UI composition
- parser/writer strategy
- whether to preserve exact legacy Obsidian layout or evolve it slightly for better AI/app ergonomics

OMX should not change without confirmation:
- source of truth moving away from plain local markdown
- introducing a required remote backend or app-private authoritative DB
- removing user access/editability of files from normal tools/CLI
- forcing Obsidian-specific lock-in as a hard dependency

## Constraints
- local markdown is primary (`local-md-primary`)
- AI CLI must be able to directly read and edit the schedule/todo source files
- menu bar interaction should be fast and natural on macOS
- daily file should auto-create on date change
- routines should be injected by copying a routine template daily
- ordinary non-routine todos should not auto-carry over

## Testable acceptance criteria
1. The app exposes a menu bar icon that opens a dropdown panel within one interaction.
2. The app can locate or create the current day's markdown file automatically when the date changes.
3. The current day's file is written in plain markdown and remains human-editable outside the app.
4. Routine items are materialized from a routine template into the new daily file.
5. Checking/unchecking an item in the app mutates the underlying markdown file directly.
6. Adding a new todo in the app mutates the underlying markdown file directly.
7. Non-routine unfinished todos are not automatically copied into the next day.
8. The resulting files remain easy for AI CLI and editors like Obsidian to inspect and modify.

## Brownfield evidence vs inference
### Evidence
- existing vault has daily TODO files and a daily template
- files are date-based markdown docs with checklist sections
- sections used repeatedly: ROUTINE / SLIT / SPEC / OTHERS

### Inference
- current workflow can seed initial schema, but the product should be generalized into a local-md-first app rather than staying bound to an Obsidian plugin model
- a standalone macOS menu bar app is the most aligned UX surface

## Technical context findings
### Existing pattern observed
- daily files: `YYYY-MM-DD TODO.md`
- daily template with section scaffolding
- checklist items as raw markdown lines

### New product-level semantics captured
- daily lifecycle: auto-create on date change
- routine lifecycle: copy routine template daily
- general todos: manual carry-over only
- primary integration principle: AI-readable local files first

## ADR snapshot
### Decision
Build a **standalone macOS menu bar app** for a **local-markdown-first todo system**, not an Obsidian plugin.

### Drivers
- menu bar-first UX
- AI CLI direct file accessibility
- plain local file durability and portability
- existing user comfort with markdown-based daily planning

### Alternatives considered
- Obsidian plugin first
- app-private DB with markdown sync/export
- viewer-only menu bar helper

### Why chosen
A menu bar app best serves the UX, while local markdown best serves AI and long-term ownership.

### Consequences
Need robust markdown parsing/writing, daily generation rules, and a lightweight but stable file schema.

### Follow-ups
Planning should resolve schema shape, routine source location, migration from current vault layout, file watcher behavior, and testing strategy.
