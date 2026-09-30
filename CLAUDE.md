# CLAUDE.md

Repo-level guidance for agents working in banditshell. `DESIGN.md` carries the
visual and architectural intent; read it before changing anything the user sees.

## Comments

The code carries close to no comments. Do not add any unless the user asks for
one, and never add file-header essays, section banners, or narration of what
the next block does. This was a hard-won correction: the codebase had filled
with comment prose until it was stripped clean on 2026-09-30. If something is
genuinely non-obvious, the fix is clearer naming or structure, not a comment.

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
