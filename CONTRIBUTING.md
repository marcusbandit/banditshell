# Contributing

One naming scheme runs through the whole path from idea to main: the issue,
the branch, every commit, the PR title and the squash commit it becomes. It is
the scheme T3 Code uses, applied to banditshell's packages.

## The flow

1. **Issue first.** Anything bigger than a typo starts as a GitHub issue. The
   title states the outcome, the body says what done looks like.
2. **Branch** off `main` as `<type>/<issue>-<slug>`.
3. **Commit** as you go, each message `<type>(<scope>): <outcome>`.
4. **Open a PR** whose title follows the same pattern and whose body ends in
   `Closes #<issue>`.
5. **Review and checks.** CI must be green and review comments answered, each
   fix as a new commit on the branch. Never amend and force-push a pushed branch.
6. **Squash merge** with `gh pr merge --squash --delete-branch`. The PR title
   becomes the one commit on main, with `(#N)` appended by GitHub.

## Types

| Type       | Use it for                                          |
| ---------- | --------------------------------------------------- |
| `feat`     | something new the shell can do                      |
| `fix`      | something broken now works                          |
| `perf`     | same behaviour, less CPU, memory or frame time      |
| `refactor` | code moves or changes shape, behaviour stays        |
| `docs`     | README, DESIGN, CONTRIBUTING, `docs/`               |
| `test`     | tests only                                          |
| `chore`    | dependencies, tooling, cleanup                      |
| `ci`       | `.github/workflows`                                 |

## Scopes

The scope is the package the change belongs to, as named in its
`module.json`: `calculator`, `cheatsheet`, `clipboard`, `files`, `island`,
`keyboard`, `launcher`, `lock`, `media`, `notifications`, `password`, `pen`,
`quickcontrols`, `session`, `settings`, `stream`, `wallpaper`, `windows`.

Outside the packages use `cli`, `install`, `theme`, `docs` or `ci`. A change
that genuinely spans two packages lists both, comma separated:
`fix(island,media): ...`. More than two usually means the PR should split.

## Branch names

    <type>/<issue>-<slug>

- `fix/66-wallpaper-browse-reveal`
- `feat/71-launcher-dictionary`
- `docs/contributing-naming` when no issue exists, which should be rare

The slug is a few lowercase hyphenated words naming the outcome. This is the
name `banditshell dev try` takes, and it matches on any part of it.

## Commit and PR titles

    <type>(<scope>): <what is different now>

Write the outcome a user would notice, in plain words, lowercase after the
colon, no trailing full stop. Say what changed for the person, not which file
moved.

Good:

- `fix(island): the mic indicator settles instead of flickering`
- `feat(launcher): a dictionary with a word view`
- `perf(launcher): rows no longer rebuild on every keystroke`

Not:

- `Fix bug` says nothing
- `island: update MicIndicator.qml` names a file, not an outcome
- `Merge pull request #58 from marcusbandit/mic-indicator-settles` is a merge
  commit; squash instead

## The PR body

- **What changed**, in a few lines.
- **Why**, linking the issue.
- **How it was verified**: a screenshot or recording for anything visible,
  test output otherwise.
- `Closes #<issue>` on its own line.

## Before you open it

- `node --test tests/*.test.js` passes.
- `banditshell dev modules` passes; a new cross-package reach has its
  `requires` entry.
- `scripts/qmldirs.sh` was run after adding, moving or renaming a QML file.
- `docs/whats-new.json` has an entry for anything a user of the shell will
  notice. See `docs/agents/whats-new.md`.
- No new comments in the code. See `CLAUDE.md`.
