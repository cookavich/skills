---
argument-hint: "[scope]"
name: codebase-wiki
user-invocable: true
description: >-
  Generate progressive local-only Markdown documentation for a codebase you are
  onboarding to. First invocation produces a breadth map (architecture, module map,
  getting-started, glossary, plus stubs for every subsystem and deeper topic).
  Subsequent invocations with a scope hint (e.g. "auth") expand a stub into a full
  page. Use when the user wants to understand an unfamiliar repository — its
  structure, conventions, libraries, runtime flows — without committing or sharing
  docs.
---

# Codebase Wiki

Generate an interlinked Markdown wiki for a local repository you are onboarding to. The wiki is a **throwaway personal aid**, not committed documentation — fresh per session, deepening on demand.

Think of it as progressive image rendering: pass 1 produces a low-resolution map of the whole system; later passes sharpen specific areas you actually need to dig into.

## Arguments

Parse runtime arguments:

- `scope` — optional. Identifies a stub to expand on pass 2 (e.g. `auth`, `testing`, `runtime-flows`). When absent, runs the breadth pass.
- `repo-root` — repository to document. Default: the current working directory.
- `output-dir` — wiki location. Default: `.codebase-wiki/` inside `repo-root`. Override only if needed — the default is auto-gitignored.

Do not modify application source. Keep generated content inside `output-dir`.

## Workflow

### 1. Detect Mode

Inspect `output-dir` before doing anything else:

| `output-dir` state | Scope provided? | Mode |
|---|---|---|
| Missing or empty | — | Pass 1 (breadth) |
| Populated | Yes | Pass 2 (deepen) |
| Populated | No | Ambiguous — ask the user before proceeding |

If the conversation references a specific open stub file and the user describes intent for it, treat that as Pass 2 on that stub.

Never silently overwrite an existing populated wiki.

### 2. Pass 1 — Breadth

Produce a low-resolution map. Sharp where it matters for navigation; stubbed everywhere else.

1. **Read repository instructions.** `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.github/copilot-instructions.md`, root `README*`, and the contents of `docs/`. If `docs/adr/`, `docs/decisions/`, `adrs/`, or `RFCS/` exists, scan titles.

2. **Run inventory.**
   ```bash
   bash codebase-wiki/scripts/repo-inventory.sh "$repo_root" "$output_dir"
   ```
   Resolve the script path relative to this `SKILL.md` and use absolute paths if your runtime does not place the skill directory on the working path. The script writes `_inventory.md` to `output-dir` and excludes `output-dir` from its own scan.

3. **Auto-gitignore.** If a `.gitignore` exists at the repo root and does not already list `output-dir` (path relative to repo root), append it on its own line. Report this in the final summary.

4. **Read deliberately.** Treat the inventory as a map, not a substitute. Check off as you read:

   - [ ] All manifests, lock files, and build configs.
   - [ ] All CI/CD workflow files.
   - [ ] Every entrypoint (`main`, server bootstrap, CLI, route registration, worker entries).
   - [ ] Every top-level documentation file already discovered.
   - [ ] Every ADR or design-decision document.
   - [ ] 2–3 representative source files per candidate area.
   - [ ] All source files, if total source count < ~100.

5. **Decide area boundaries.** Use model judgment, informed by directory structure, entrypoints, and naming patterns. Cap by repo size:
   - ≤5 for small (under ~75 source files)
   - 5–10 for medium
   - 10–15 for large
   - 20 absolute maximum

   Areas should match user-visible features, bounded domains, monorepo packages, or runtime layers — not every directory.

6. **Write full-quality core pages:** `README.md`, `architecture.md`, `module-map.md`, `getting-started.md`, `glossary.md`. The inventory script has already written `_inventory.md`.

7. **Write stubs for everything else:** `conventions.md`, `configuration.md`, `testing.md`, `operations.md`, `runtime-flows.md`, `data-flow.md`, and one `areas/<name>.md` per area. See `references/wiki-structure.md` for the exact stub format.

8. **Idempotency rule.** Before writing any file: if it exists *without* `status: stub` frontmatter, do not overwrite — log "skipped (already expanded)" in the final summary. Files that exist with `status: stub` may be overwritten with a fresh stub.

Read `references/wiki-structure.md` before writing for the page taxonomy, stub format, README pattern, linking rules, and quality bar. See `references/examples/` for sample outputs of the most-generated pages — match the shape, not the content.

### 3. Pass 2 — Deepen

Replace one stub with a full page, using the stub's file list as the starting context.

1. **Resolve the scope to a target stub.**
   - Exact match against page name: `auth` → `areas/auth.md`, `testing` → `testing.md`.
   - If no exact match, fuzzy-match against stub `description` frontmatter values and confirm with the user.
   - If still no match, treat as a new focused page — but confirm with the user before creating it.

2. **Read the stub.** Its `description` and `Relevant files` list were curated on pass 1 specifically to bootstrap this expansion.

3. **Read deeply on the target only.** Trace public interfaces, internal flow, dependencies in and out. Read tests that verify the area's behavior.

4. **Write the expanded page over the stub.** Remove the `status: stub` frontmatter block entirely.

5. **For area pages**, follow the post-expansion template in `references/wiki-structure.md`: Responsibility, Key files, Public interfaces, Internal flow, Dependencies, Tests, Common changes (optional), Open questions (only if real).

6. **Cross-link.** The expanded page must link back to `../README.md` and to at least one related area or core page.

### 4. Verify

Before reporting done:

1. Every generated page is reachable from `README.md`.
2. Relative Markdown links resolve.
3. Source citations use repo-relative paths only — no absolute filesystem paths.
4. No secrets, no concrete credential values, no private hostnames in the wiki. Env-var *names* are fine.
5. No leftover `TODO`, `TBD`, or template placeholder text.
6. **Claim-citation scan.** In each full-quality core page, flag paragraphs that make behavioral claims (verbs like "handles", "validates", "fetches", "transforms") without a nearby backticked source path. Report flagged paragraphs in the final summary — warning, not blocker.

## Output Style

- Explain how the system works, not just what files exist.
- Cite source paths in backticks. Use bare paths (`src/server.ts`) for file-level references; use line-anchored citations (`src/server.ts:42` or `src/server.ts:42-58`) when pointing at a specific function or claim.
- Make uncertainty explicit: "The code indicates...", "This appears to...", "Not found in this repository...".
- Diagrams: ASCII only, never Mermaid. See `references/wiki-structure.md` for patterns. Pair every diagram with prose naming the source files involved.
- Cross-link aggressively. A reader should move from high-level architecture to source-level area pages without having to search.

## Final Response

Summarize:

- Wiki location.
- Pass executed (breadth or deepen, with target).
- Files created, updated, and skipped — with reason for skips.
- On pass 1: the area list with size-cap reasoning ("Identified 7 areas; cap for this repo size is 10").
- Validation results, including any paragraphs flagged by the claim-citation scan.
- Whether `.gitignore` was modified.
- Suggested next-step deepening targets — pull the top 2–3 hot-spots from `_inventory.md` so the user knows where pass 2 should go next.
