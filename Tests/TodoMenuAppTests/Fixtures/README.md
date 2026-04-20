# Acceptance / Interoperability Fixture Corpus

These fixtures implement the corpus required by `.omx/plans/test-spec-obsidian-menu-bar-todo.md` for worker-3's lane:
- canonical valid files
- preamble preservation
- unknown sections
- managed passthrough lines
- ambiguity/conflict cases
- lifecycle templates and existing-day files

## Fixture inventory
- `canonical-full.md` — full valid day file with all default managed sections
- `canonical-empty-sections.md` — minimal valid file with empty managed sections
- `preamble-preservation.md` — wiki-link + preamble before first managed section
- `unknown-sections.md` — unmanaged headings before/after managed sections
- `managed-passthrough-lines.md` — notes/comments inside managed sections that must be preserved
- `ambiguous-duplicate-same-section.md` — duplicate checklist text in one section to exercise ambiguity rejection
- `conflict-reordered-lines.md` — reordered lines suitable for stale snapshot/conflict tests
- `conflict-external-edit-text-and-state.md` — text/state edited externally after render snapshot
- `routine-template.md` — routine source template to inject during bootstrap
- `daily-scaffold.md` — scaffold/preamble template for new-day creation
- `existing-today-with-routine.md` — existing daily file proving no duplicate routine injection

## Ownership intent
These files are safe for parser/writer, lifecycle, and acceptance tests to consume without introducing app-private metadata.
