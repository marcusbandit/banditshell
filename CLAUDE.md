# CLAUDE.md

Repo-level guidance for agents working in banditshell. `DESIGN.md` carries the
visual and architectural intent; read it before changing anything the user sees.

## Comments

The code carries close to no comments. Do not add any unless the user asks for
one, and never add file-header essays, section banners, or narration of what
the next block does. This was a hard-won correction: the codebase had filled
with comment prose until it was stripped clean on 2026-09-30. If something is
genuinely non-obvious, the fix is clearer naming or structure, not a comment.

## Layout

Four buckets: `config/` (singletons backing config.json and the theme),
`services/` (state that outlives any widget), `components/` (reusable, know
nothing about the shell), `modules/` (actual UI, one subfolder per feature).
Standalone windows live in `previews/`, reached through the `preview.qml`
router at the root with `BANDITSHELL_PREVIEW=<Name>`; `shell.qml` and
`preview.qml` are the only QML files at the root. Names are full words a
person would search for - no abbreviations, no product-name jokes. Every QML
folder carries a `qmldir`; after adding, moving or renaming a file run
`scripts/qmldirs.sh`, or the LSP stops resolving `qs.*` imports.

## Agent skills

### Issue tracker

Local markdown under `.scratch/` by default, GitHub issues
(`marcusbandit/banditshell`, via `gh`) for anything release-facing or already
filed there, with a `Public:` flag that inverts the default once the repo goes
public. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, unchanged: `needs-triage`, `needs-info`,
`ready-for-agent`, `ready-for-human`, `wontfix`. See
`docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and one `docs/adr/` at the repo root, alongside
the existing `DESIGN.md`. See `docs/agents/domain.md`.

### What's new

Every push writes its entry in `docs/whats-new.json` at push time - the log
the shell itself reads out to the user, so it is written for the recipient,
not the commit log. The Major bar is hard, and agents inflate it: reread the
last ten entries before classifying. See `docs/agents/whats-new.md`.
