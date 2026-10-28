# How banditshell updates itself

banditshell updates from GitHub. There is no package and no installer on the path: the checkout is
a git clone, and an update is a fast-forward of that clone, tried first on a copy. This page is the
map of the whole loop for the next agent, then the channels, the version number, and a design note
for signed updates that is not built.

The words a person reads live in `services/update.js`. The work is done by `cli/banditshell`
(`update_*` functions). `services/Update.qml` runs the CLI and shows its answers, and
`modules/menu/content/UpdateMenu.qml` is the menu. Tests are `tests/update.test.js` (the words) and
`tests/update-cli.test.js` (the loop, against a fake world of a bare origin, a checkout, a fake
`qs` and a fake compositor in `tests/fixtures/update/`).

## The loop

1. **Check.** `banditshell update check [--json] [--no-fetch]`. It fetches the followed branch from
   the configured remote, counts commits each way and settles on one state: `current`,
   `available`, `diverged` (this copy has commits GitHub lacks and GitHub has new ones),
   `paused` (the checkout is on a branch that is not the one followed, as in a tried worktree) or
   `skipped` (that exact commit failed on this copy before). When something is available it
   writes a facts folder (name-status of the diff, the files edited here, the untracked files,
   `api/actions.tsv`, `install.sh` and `docs/whats-new.json` from both sides) and
   `node services/update.js report` reads it into a class: restart or reload, commands changed,
   removed command ids, helpers to rebuild, new install steps, edits in the way, files in the
   way, and the incoming what's-new entries. Exit 0 means nothing to do, 10 means a version is
   waiting, 1 means an error. `Update.qml` repeats this every `updates.interval` minutes and
   remembers the last fetch in `update.json`, so it does not fetch more than every 30 minutes.
2. **Stage.** `banditshell update apply [--to <sha>] [--detach] [--json]`. The menu passes the sha
   the check showed, so a push during the click is not pulled. `git archive` unpacks the target
   into `~/.cache/banditshell/staged`, a tree that touches nothing live.
3. **Verify.** `scripts/qml-compile-check.sh` runs on the staged tree in a fresh offscreen
   engine. A tree that does not load stops here and nothing has changed. `scripts/qmldirs.sh` runs
   on it too, and a qmldir that drifts is a warning. When helpers changed they are built in the
   staged tree, and a failed build stops the update.
4. **Apply.** The old head goes into `update/previous` and the target into `update/target`. Edits
   here that the update also touches are set aside with `git stash` under a fixed identity and the
   names go into `update/aside`; edits the update does not touch ride along. Then
   `git merge --ff-only`. Helpers are copied from the staged tree, `bin/` is ensured and
   completions are refreshed.
5. **Health.** If the class says restart, the shell is stopped and launched again. Otherwise the
   running shell is left to reload by itself, because Quickshell watches its files. In both cases
   the CLI waits for `shell status` to answer over IPC and then scans the log for
   `ReferenceError` and `Failed to load` for a few seconds, counting only lines after the mark it
   took before the merge. `BANDITSHELL_HEALTH_WAIT` and `BANDITSHELL_HEALTH_SCAN` set the
   seconds, and the tests set them small. When it passes, `~/.cache/banditshell/lastgood` is
   refreshed with rsync, or `cp -a` if rsync is missing, and `update/result.json` records `ok`.
   A hot reload can fail where a cold start of the same tree works. An inline component added to
   a file the running shell already loaded is one way. So when a reload fails its check, the
   shell is restarted once on the new version and that start is checked the same way.
6. **Roll back on failure.** If the health check of a start fails, `git reset --keep <previous>` puts the
   checkout back, the commit that failed goes into `update/skip` (it is not offered again until a
   newer one arrives) and the shell is relaunched. If even that launch fails, the last known
   good copy is started. `result.json` records `ok: false` with the reason, and the menu shows it
   until dismissed.
7. **Roll back by hand.** `banditshell update rollback [--detach] [--json]` does the same reset to
   `update/previous` and skips what it left. It refuses on a paused copy, on a copy with commits
   of its own, and when the recorded commit is not behind HEAD; a reset git refuses changes and
   skips nothing. The check reports that commit as `previous`, with its id as `previousVersion`,
   under the same rules, and the menu then offers "Go back to <id>" ahead of Hide message, asks once
   in its place, and runs `rollback --detach`, whose first progress line is `goback`. Only the
   checkout moves: `config.json`, files the newer version wrote elsewhere and stashed edits stay
   as they are, and the confirm says so (#171). After a go-back the outcome offers a quiet
   "Reinstall the version you just left", asked once, which runs `update apply --detach --to <sha>` on the commit it left. Once an
   applied commit starts, it leaves `update/skip`, and the shell clears `updates.skip` when
   `result.json` names it (#178). It leads with
   "Report what broke": a few lines of words, handed to `banditshell triage` in a terminal
   (`scripts/in-terminal.sh`) with the skipped and current versions as `--context`, so they
   land under the words in the report and stay out of the issue title (#228),
   where triage shows the whole report and sends nothing until the person answers y (#180).
   `banditshell update status [--json]` says where the copy stands, the last outcome and the
   version before the last update. What's new shows nothing pending when the seen mark is a
   newer id than the whole log, which is where a rollback leaves it.

`--detach` runs the whole of apply, or of rollback, in a session of its own and writes JSON phase lines to
`update/progress.log`, which `Update.qml` reads back. A restart or a hot reload cannot kill the
update that way. A second update at the same time is turned away by a lock on `update/lock`.
`BANDITSHELL_DRY=1` makes apply print what it would do.

State lives in `~/.local/state/banditshell/update/` (`previous`, `target`, `skip`, `aside`,
`result.json`, `progress.log`, `lock`, `verify.log`, `build.log`) and `~/.cache/banditshell/`
(`staged`, `lastgood`, `failed.log`). `~/.local/state/banditshell/root` remembers the checkout so
a shell run from `lastgood` can still update the real one.

## Channels

`updates.channel` in `config.json` is `stable` or `main`. The default is `stable`: other people get
releases, and only the owner's own desktop follows `main`.

| Channel  | Follows                | Moves when                                  |
| -------- | ---------------------- | ------------------------------------------- |
| `stable` | `origin/stable`        | the owner cuts a release with `banditshell dev release` |
| `main`   | `origin/main`          | any merge                                   |

Before releases existed, the shell wrote `"channel": "main"` into every `config.json` it touched, so
that value says nothing about a choice. The config upgrade in `config/configuration.js` moves it to
`stable` once and records `"channelUpgraded": true` beside it; a `main` set after that stays `main`.
The CLI reads a `main` without the marker as `stable` too (`config_channel`), so the shell and the
command agree before the shell has rewritten the file. To follow every merge, set it back:
`banditshell config set updates.channel main`.

A copy still on the code from before releases cannot record the marker: its config loader drops
keys it does not know. So the move also stops when `~/.local/state/banditshell/keep-channel` is a
non-empty file, which no version of the shell rewrites. The shell reads it before the upgrade
(`keepsChannel` in `config/Config.qml`) and the CLI reads it in `config_channel`. To keep a copy on
`main` whichever version it runs:

    mkdir -p ~/.local/state/banditshell && echo main > ~/.local/state/banditshell/keep-channel && banditshell config set updates.channel main

`updates.branch` still works as an override. The rule is one sentence: a branch other than `main`
wins over the channel, and `main` (the default value in every config) means "let the channel
decide". Someone who follows `dev` keeps following `dev` on either channel. The rule exists in two
places that must agree: `branchFor` in `services/update.js` for the menu and `update_branch_for` in
`cli/banditshell` for the CLI. `banditshell version` prints `channel` and `follows`.

A bad channel value is refused with a plain message instead of being guessed at. The menu reads a
bad value as `stable` only for display, and the CLI error shows in its place.

The checkout stays on its local `main` while following `stable`. The paused rule accepts that
(`update_on_branch`, `following` in `update.js`); any other local branch is still paused. A copy
that is ahead of `stable`, for example one that took a merge from `main` before releases existed,
reads as up to date and joins at the next release. Stable never moves a copy backwards. A copy on
`stable` when GitHub has no `stable` yet reads as current ("there is no release on stable yet"),
not as an error, so the time between this landing and the first release is quiet. A check that
does fail still carries `version` in its JSON, so the menu keeps the release number.

### Why a stable branch and not the newest tag

Every release is a tag, and `stable` is a branch fast-forwarded to that tag in the same atomic push.
The update loop follows the branch. That keeps check, apply and rollback to one fetched ref and a
fast-forward, exactly as on `main`: no tag sorting on the user's machine, no question of what to do
with a tag that is not on `main`, and a copy that has never fetched a tag still lands on the release
because the branch already points at it. A push to `stable` that is not a fast-forward is refused
by git, so `stable` can never move backwards or sideways. Each fetch also brings the `v*` tags, so
the version shows as a release number from the first check on.

### Cutting a release

`banditshell dev release [--dry-run] [--skip-boot-check]`, which runs `scripts/release.sh`. It
refuses unless the copy is a clean checkout of `origin/main` (no edits, no untracked files, HEAD
equal to `origin/main` after a fetch), and unless `gh` is installed and logged in; a dry run only
warns about `gh`. Then:

1. The last release is the highest `vX.Y.Z` tag on `main`. Nothing since it means nothing to
   release, and it stops.
2. The commit titles since it pick the number (`nextRelease` in `services/whatsnew.js`): any `feat`
   or `!` is a minor bump, anything else a patch. The first release is `v0.1.0`. It stays 0.x until
   the owner calls 1.0; from 1.0 on, a `!` is a major bump.
3. `main` as committed is exported and checked: `node --test tests/*.test.js`,
   `scripts/check-modules.js`, `scripts/lint-rules.js`, `scripts/qml-compile-check.sh`, and the
   headless boot check. Any failure stops it, and every failing check is named. A boot check that
   cannot run (no gamescope) counts as a failure unless `--skip-boot-check` is given.
4. The release notes are the what's-new entries on `main` that the last tag did not have, grouped
   the way the What's new card groups them.
5. `git tag -a`, then one `git push --atomic origin <tag> <sha>:stable`, so the tag and `stable`
   move together or not at all. Last, `gh release create` writes the GitHub release. If only that
   step fails, the command to finish it is printed; people already have the update.

`--dry-run` does every check and prints the notes and the three commands, and pushes nothing.
`tests/release.test.js` runs it against throwaway bare repos with a fake `gh`.

### Installing

A fresh clone is on `main`. `install.sh` moves it back to `origin/stable`, the newest release,
before it does anything else, then runs again from the released copy. It only does that for a clone
on `main` with no `config.json` yet, no edits, and a release to go to; anything else is left where
it is and the update loop takes over.

## Versions

The version is the release: `v0.2.0` on a tagged commit, `v0.2.0+3` three commits past it, which is
what a copy on `main` shows. With no release tag in reach it falls back to the id of the newest real
entry in `docs/whats-new.json`, then the short sha. `update_label` in `cli/banditshell` is the one
definition. Where it shows:

- `banditshell version` prints `version`, and `--json` has the same key.
- `banditshell update` and `update check` name the version this copy is on and the one waiting.
- `banditshell update check --json` carries `version` (this copy), `targetVersion` (what is
  waiting) and `previousVersion` (where rollback goes).
- The update menu says `You have <release>, on the stable channel`; on stable a waiting update is headed
  `<release> is ready`, with that release's what's-new entries under "In this update".
- Settings > About shows the same version.

`update rollback` on `stable` goes to the release before the one this copy is on, found from the
tags rather than from `update/previous`, so it works on a copy that never updated. A release that
already failed here (`update/skip`) is stepped over. On `main` it
goes to the commit before the last update, as before.

## Design note: signed updates (not built)

Nothing here is implemented. It is the plan for the day the repository goes public, when anyone
could try to push to the account that updates read from.

**What is signed.** The annotated tag `dev release` already makes, one per stable release,
signed with an SSH key (`git tag -s` with `gpg.format=ssh`). The signature covers the commit the
tag points at, so the commit that `stable` moves to is the signed thing. The `main` channel is
the developer edge and is not verified.

**Where the key lives.** The private key is an ed25519 key on the owner's machine, ideally a
hardware key (`ed25519-sk`) so a stolen laptop is not a stolen release. It never goes into CI. The
public half goes into an `allowed_signers` file. That file is pinned at install time into
`~/.config/banditshell/allowed_signers`, not read from the update itself, because a verifier that
trusts the file it is checking trusts nothing. `install.sh` copies the starting copy out of the
checkout it installs from, which is the one moment the person is already trusting the source.

**How `update apply` verifies.** After the fetch and before staging, for the `stable` channel only:
fetch tags, find a `v*` tag that points exactly at the target commit, and run
`git -c gpg.format=ssh -c gpg.ssh.allowedSignersFile=<pinned file> verify-tag <tag>`. No tag, a bad
signature or a signer not in the file stops the update with "this version is not signed by the
owner, so nothing was changed", before anything is unpacked. `--to <sha>` goes through the same
check. The check also refuses a tag whose version is older than the running one, so a replayed old
signed release cannot be used to roll people back to a version with a known hole. It needs
`ssh-keygen`, which comes with OpenSSH.

**Rotating the key.** A new `allowed_signers` is itself delivered as a tag signed by the old key.
`banditshell update trust` would show the new fingerprint and replace the pinned file only when the
old key signed the change. A lost private key means everyone reinstalls once to re-pin.

**What it costs a non-developer.** Day to day, nothing: no prompt, no key to manage, one small
extra fetch for tags. The costs are on failure paths. An update whose tag is missing does not
arrive, so a release without a tag stops stable (`dev release` always makes one). A key rotation needs one `update trust` confirmation. A machine without
`ssh-keygen` cannot take stable updates until it is installed, and `doctor` should say so. It does
not protect against the owner's own machine being compromised, and it does not make `main` safe.

## Where to change things

| To change                         | Edit                                                       |
| --------------------------------- | ---------------------------------------------------------- |
| What the update says or classifies | `services/update.js`, then `tests/update.test.js`          |
| The loop itself                   | `update_*` in `cli/banditshell`, then `tests/update-cli.test.js` |
| The menu or the state shown       | `services/Update.qml`, `modules/menu/content/UpdateMenu.qml` |
| What a release checks and pushes  | `scripts/release.sh`, `tests/release.test.js`              |
| The release number or notes       | `services/whatsnew.js`, `tests/whatsnew.test.js`           |
| The version shown                 | `update_label` in `cli/banditshell`                        |
