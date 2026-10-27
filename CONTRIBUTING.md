# Contributing

One naming scheme runs through the whole path from idea to main: the issue,
the branch, every commit, the PR title and the squash commit it becomes.

## The flow

1. **Issue first.** Anything bigger than a typo starts as a GitHub issue. The
   title states the outcome, the body says what done looks like.
2. **Branch** off `main` as `<type>/<issue>-<slug>`.
3. **Commit** as you go, each message `<type>(<scope>): <outcome>`.
4. **Try it live** with `banditshell dev try <branch>` and go back with
   `banditshell dev back`. See below for what `try` does not cover.
5. **Open a PR** whose title follows the same pattern and whose body ends in
   `Closes #<issue>`.
6. **Review and checks.** CI must be green and review comments answered, each
   fix as a new commit on the branch. Never amend and force-push a pushed branch.
7. **Squash merge** with `gh pr merge --squash --delete-branch`. The PR title
   becomes the one commit on main, with `(#N)` appended by GitHub.

## Releases

Merging to `main` reaches only the owner's desktop, which follows `main`.
Everyone else follows releases. The loop is:

1. Merge the PR to `main`.
2. The owner runs it for a while.
3. When the owner says "release", run `banditshell dev release --dry-run`
   from a clean checkout of `origin/main`, then the same without
   `--dry-run`. It checks main, picks the number (minor for a `feat`, patch
   otherwise), tags it, moves `stable` and writes the GitHub release from
   what's new since the last tag.

Never cut a release the owner did not ask for. `docs/architecture/updates.md`
has the details.

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

## Trying a branch live

`banditshell dev try` relaunches only the shell's front end from the worktree:
the QML, and the helpers it builds there. It reloads as files change, but a hot
reload resets singletons, so state can look wrong until a clean start. When a
change does not seem to take, run `banditshell restart` before deciding it is
broken.

Hyprland's Lua is pointed at the worktree too, but Hyprland only reads it
again when its config reloads, so changed binds and layouts wait for that.

Some things `try` never swaps, because they come from what is installed rather
than the worktree: the `banditshell` command on your `PATH`, systemd units and
anything `install.sh` puts in place. To test the command, run it from the
worktree, `BANDITSHELL_DIR=$PWD bash cli/banditshell`. The rest needs an install
and a restart of the whole session.

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
