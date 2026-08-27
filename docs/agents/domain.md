# Domain Docs

How the engineering skills should consume this repo's domain documentation when
exploring the codebase. banditshell is **single-context**: one `CONTEXT.md` and
one `docs/adr/` at the repo root.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root: the glossary of domain terms.
- **`docs/adr/`**: read ADRs that touch the area you're about to work in.
- **`DESIGN.md`** at the repo root already exists and carries the project's
  visual and architectural intent. Read it alongside `CONTEXT.md`; where the two
  disagree about a term, `CONTEXT.md` wins on vocabulary and `DESIGN.md` wins on
  look and feel.

If any of these files don't exist, **proceed silently**. Don't flag their
absence; don't suggest creating them upfront. The `/domain-modeling` skill
(reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates
them lazily when terms or decisions actually get resolved.

## File structure

```
/
├── CONTEXT.md
├── DESIGN.md
├── docs/adr/
│   ├── 0001-....md
│   └── 0002-....md
├── components/
├── modules/
├── services/
└── src/
```

If banditshell ever splits into genuinely separate contexts, the layout becomes
a root `CONTEXT-MAP.md` pointing at one `CONTEXT.md` per context, with
context-scoped ADRs under each. Nothing in the tree suggests that today, so
assume single-context until a `CONTEXT-MAP.md` appears at the root.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal,
a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift
to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're
inventing language the project doesn't use (reconsider) or there's a real gap
(note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than
silently overriding:

> _Contradicts ADR-0007 (drawn marks over themed icon files), but worth
> reopening because..._
