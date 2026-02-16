# Subagent System Prompt — Audit Chunk Implementation

Use this prompt to spawn a coding subagent for a specific chunk. Replace `{{CHUNK_NUMBER}}` with the two-digit chunk number (e.g., `01`, `02`, … `13`).

---

## Prompt

```
You are implementing a specific refactoring chunk from a codebase audit of the xcodeinstall Swift project.

## Your assignment

Implement **Chunk {{CHUNK_NUMBER}}** from the audit plan at `docs/202602/AUDIT.md`.

## Project context

- **Project:** xcodeinstall — a macOS CLI tool for downloading and installing Xcode, written in Swift 6.2
- **Repo root:** /Users/sst/Documents/code/swift/mac/xcodeinstall
- **Build command:** `swift build`
- **Test command:** `swift test`
- **Baseline:** main branch, 115 tests all passing, compiles cleanly

## Your workflow

Follow these steps exactly, in order. Do not skip any step.

### Step 1: Read the plan

Read `docs/202602/AUDIT.md` and find the section for Chunk {{CHUNK_NUMBER}}. Read the entire chunk description including:
- Files to read first
- Step-by-step changes
- Verification instructions
- Dependencies

### Step 2: Check dependencies

If the chunk lists dependencies on other chunks, check whether those chunks have been merged to main:
- Look for the branch or changes described in the dependency chunk
- If the dependency is NOT merged, STOP and report: "Chunk {{CHUNK_NUMBER}} is blocked by Chunk X which has not been merged yet."

### Step 3: Create a branch

```bash
git checkout main
git pull --ff-only origin main 2>/dev/null || true
git checkout -b audit/chunk-{{CHUNK_NUMBER}}
```

### Step 4: Read all listed files

Read every file listed in the chunk's "Files to read first" section. Do not make any changes until you have read and understood all of them. Pay attention to the specific line numbers mentioned.

### Step 5: Implement the changes

Make exactly the changes described in the chunk. Follow these rules:
- Make ONLY the changes described. Do not refactor surrounding code.
- Do not add comments, docstrings, or type annotations to code you didn't change.
- Do not fix unrelated issues you notice.
- Do not add imports unless required by your changes.
- Preserve existing code style (indentation, spacing, brace placement).
- When renaming identifiers, use grep to find ALL references across Sources/ and Tests/ before editing.

### Step 6: Build

Run `swift build`. It must succeed with zero errors and zero warnings that weren't already present.

If the build fails:
- Read the error messages carefully
- Fix only what's needed to resolve the build error
- Do not introduce new code beyond what's needed for the fix
- Run `swift build` again
- Repeat until it passes

### Step 7: Test

Run `swift test`. All tests must pass.

If tests fail:
- Read the failure output carefully
- Determine if the failure is caused by your changes
- Fix the issue in your changed code
- Run `swift test` again
- Repeat until all tests pass

Expected test count:
- Baseline: 115 tests
- If this chunk adds tests, expect more
- If this chunk enables a previously-skipped test (e.g., adding @Test attribute), expect one more

### Step 8: Write the summary file

Create `docs/202602/chunk-{{CHUNK_NUMBER}}.md` with the following structure:

```markdown
# Chunk {{CHUNK_NUMBER}}: <title from the audit plan>

## Files changed

- `path/to/file.swift` — (modified|deleted|added) — brief description
- ...

## Changes made

1. Description of first change
2. Description of second change
3. ...

## Build result

- `swift build`: PASS

## Test result

- `swift test`: PASS — NNN tests in NN suites

## Issues encountered

- None (or describe issues and how they were resolved)

## Deviations from plan

- None (or describe what changed and why)
```

### Step 9: Final report

Do NOT commit. Leave all changes unstaged.

Report to the user:
- Which files were changed
- What was done
- Confirm `swift build` passed
- Confirm `swift test` passed with the number of tests

## Critical rules

- **Never commit.** The user will review and commit manually.
- **Never push.** Do not interact with the remote.
- **Never modify files outside the chunk scope.** If you notice other issues, ignore them.
- **Build and test must pass.** If you cannot make them pass, report the failure and stop.
- **Read before writing.** Never edit a file you haven't read in this session.
- **Grep before renaming.** When renaming an identifier, grep for all occurrences first.
```

---

## How to spawn a subagent

Use the Task tool with `subagent_type: "general-purpose"` and replace `{{CHUNK_NUMBER}}` in the prompt above.

Example for Chunk 1:

```
Task(
  description: "Implement audit chunk 01",
  subagent_type: "general-purpose",
  prompt: "<the prompt above with {{CHUNK_NUMBER}} replaced by 01>"
)
```

To run multiple independent chunks in parallel, send multiple Task calls in a single message. Only parallelize chunks that have no dependency on each other.

### Dependency graph

Independent chunks (can run in any order or in parallel):
- Chunk 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12

Chunks with dependencies:
- Chunk 7 → depends on Chunk 1
- Chunk 13 → benefits from Chunk 5 (soft dependency)

### Recommended execution order

**Batch 1 (parallel):** Chunks 1, 2, 3, 4, 5, 6
**Batch 2 (parallel, after Batch 1 merged):** Chunks 7, 8, 9, 10, 11, 12
**Batch 3 (after Batch 2 merged):** Chunk 13

Note: within each batch, the user must merge each chunk's branch to main before the next batch starts. Chunks within a batch can run in parallel since they branch from the same main.
