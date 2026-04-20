# Manual Acceptance Checklist

Grounded in the PRD and test spec.

## Core interaction
- [ ] Menu bar icon appears after launch
- [ ] One click opens the panel
- [ ] Panel groups todos by `ROUTINE`, `SLIT`, `SPEC`, `OTHERS`
- [ ] Empty/misconfigured state is understandable and recoverable

## File mutation
- [ ] Toggling an item updates the visible UI
- [ ] Toggling an item mutates plain markdown on disk directly
- [ ] Quick add inserts a new item into the expected section
- [ ] Added item is immediately visible without restart

## Daily lifecycle
- [ ] Missing today's file is created automatically
- [ ] New file keeps scaffold/preamble content
- [ ] Routine items are copied into `ROUTINE` exactly once
- [ ] Existing today file is not overwritten or silently re-injected
- [ ] Unfinished non-routine tasks are not auto-carried to the next day

## Interoperability / trust
- [ ] `cat`/`grep` on the file remains readable and useful
- [ ] Editing the file in a text editor preserves app compatibility
- [ ] Opening the file in Obsidian shows normal markdown checklists and headings
- [ ] External edits while the panel is open cause refresh or safe failure rather than silent corruption

## Conflict behavior
- [ ] If the rendered item is still uniquely resolvable after external edits, the mutation succeeds on a fresh parse
- [ ] If the item is no longer uniquely resolvable, the app aborts, refreshes, and does not toggle the wrong line
