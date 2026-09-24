# CLAUDE.md

Repo-level guidance for agents working in banditshell. `DESIGN.md` carries the
visual and architectural intent; read it before changing anything the user sees.

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
