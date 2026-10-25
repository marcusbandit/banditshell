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
6. **Roll back on failure.** If the health check fails, `git reset --keep <previous>` puts the
   checkout back, the commit that failed goes into `update/skip` (it is not offered again until a
   newer one arrives) and the shell is relaunched. If even that launch fails, the last known
   good copy is started. `result.json` records `ok: false` with the reason, and the menu shows it
   until dismissed.
7. **Roll back by hand.** `banditshell update rollback [--detach] [--json]` does the same reset to
   `update/previous` and skips what it left. It refuses on a paused copy, on a copy with commits
   of its own, and when the recorded commit is not behind HEAD; a reset git refuses changes and
   skips nothing. The check reports that commit as `previous`, with its id as `previousVersion`,
   under the same rules, and the menu then offers "Go back to <id>" ahead of Dismiss, asks once
   in its place, and runs `rollback --detach`, whose first progress line is `goback`. Only the
   checkout moves: `config.json`, files the newer version wrote elsewhere and stashed edits stay
   as they are, and the confirm says so (#171).
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

`updates.channel` in `config.json` is `stable` or `main`. The default is `main`, which is what every
copy did before channels existed, so nothing moved when they were added.

| Channel  | Follows                | Moves when                                  |
| -------- | ---------------------- | ------------------------------------------- |
| `main`   | `origin/main`          | any push                                    |
| `stable` | `origin/stable`        | the owner promotes a main that passed the checks |

`updates.branch` still works as an override. The rule is one sentence: a branch other than `main`
wins over the channel, and `main` (the default value in every config) means "let the channel
decide". Someone who follows `dev` keeps following `dev` on either channel. The rule exists in two
places that must agree: `branchFor` in `services/update.js` for the menu and `update_branch_for` in
`cli/banditshell` for the CLI. `banditshell version` prints `channel` and `follows`.

A bad channel value is refused with a plain message instead of being read as `main`, because
silently giving a non-developer every push is the failure channels exist to prevent. The menu
reads a bad value as `main` only for display, and the CLI error shows in its place.

The checkout stays on its local `main` while following `stable`. The paused rule accepts that
(`update_on_branch`, `following` in `update.js`); any other local branch is still paused. A copy
that is ahead of `stable`, for example the owner's own checkout, reads as up to date. Stable never
moves a copy backwards. A copy on `stable` that has no `origin/stable` yet (nothing promoted) gets
"GitHub has no stable version yet" and the way out.

The channel is config-only. Settings > Updates has the Branch row from the settings mockup and the
mockup has no channel row, so none was added. Set `"channel": "stable"` under `updates` in
`config.json`. The Branch row keeps working as the override. Settings > About shows the version and
the branch followed, read-only.

### Promoting main to stable

`scripts/promote-stable.sh`, also `banditshell dev promote [--remote <name>] [--no-fetch]`. It
exports `main` as committed (working-tree edits do not count) and runs on it:

- `node --test tests/*.test.js`
- `node scripts/check-modules.js`
- `node scripts/lint-rules.js`
- `scripts/qml-compile-check.sh`

It also requires that local `main` equals `origin/main`, that the newest real entry in
`docs/whats-new.json` has a date id, and that `stable`, when it exists, is an ancestor of `main`
and not already equal to it. Then it prints the commands and stops:

    git push origin main:stable
    git tag -a v2026.10.17 <sha> -m banditshell\ 2026-10-17
    git push origin v2026.10.17

The script pushes only when run with `--push`. Agents never pass `--push`; the owner runs the
printed commands or the flag. `tests/promote-stable.test.js` runs the script against throwaway
repos under the temp folder and checks after each run that the throwaway origin did not change.

## Versions

The version is the id of the newest real entry in `docs/whats-new.json`, such as `2026-10-17` or
`2026-10-16-7`. It is already unique, already written at every push, and already readable, so no
second number exists to drift from it. Where it shows:

- `banditshell version` prints `version`, and `--json` has the same key.
- `banditshell update check --json` carries `version` (this copy) and `targetVersion` (what is
  waiting), each read from `docs/whats-new.json` at that commit, with the short sha as the
  fallback.
- The update menu shows `Version <id>, stable channel`, and `latest: <id>` when one is waiting.
- Settings > About shows `BanditShell <id>`, taken from the same log. `Device.version` (git
  describe) is only the fallback.

Git tags follow the id: `v` plus the id with dots for the date, so `2026-10-17` is `v2026.10.17`
and `2026-10-16-7` is `v2026.10.16-7`. `tagFor` in `services/whatsnew.js` is the one definition
and the promote script prints the tag command from the same rule. A tag marks a commit that
reached `stable`. `main` pushes are not tagged.

## Design note: signed updates (not built)

Nothing here is implemented. It is the plan for the day the repository goes public, when anyone
could try to push to the account that updates read from.

**What is signed.** The annotated tag the promote script already makes, one per stable release,
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
arrive, so forgetting the tag step stops stable (the promote script already prints it, and could
make the tag mandatory). A key rotation needs one `update trust` confirmation. A machine without
`ssh-keygen` cannot take stable updates until it is installed, and `doctor` should say so. It does
not protect against the owner's own machine being compromised, and it does not make `main` safe.

## Where to change things

| To change                         | Edit                                                       |
| --------------------------------- | ---------------------------------------------------------- |
| What the update says or classifies | `services/update.js`, then `tests/update.test.js`          |
| The loop itself                   | `update_*` in `cli/banditshell`, then `tests/update-cli.test.js` |
| The menu or the state shown       | `services/Update.qml`, `modules/menu/content/UpdateMenu.qml` |
| What counts as promotable         | `scripts/promote-stable.sh`, `tests/promote-stable.test.js` |
| The tag or version rule           | `services/whatsnew.js` and the promote script together     |
