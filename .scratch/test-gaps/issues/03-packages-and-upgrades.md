# Tests for installing, removing and upgrading packages

Status: ready-for-agent
Tier: 1

The pacman output parser is tested (`tests/system-upgrade.test.js` against
captured logs). The script that runs the upgrade and the QML that drives it
are not, and a mistake there is a partial upgrade.

## scripts/system-upgrade.sh

Run it with a stubbed `pkexec` and `pacman`. Test that a second start while a
runner is alive is refused, that a stale pid file does not block a new run,
that `answer` refuses empty and non-alphanumeric text (it never reads the
prompt, so any word goes through), and that cancel is refused once pacman has
started committing.

## services/SystemUpgrade.qml

Extract the state transitions from the Process handlers. Test the
auto-answer to "Proceed with installation?" and that no other question is ever
answered for the user, and that success and failure are reported from the exit
code and the log, not from one of them alone.

## services/Uninstaller.qml

`plan`, `detailFor` and the exit code mapping: test that the removal reported
is the one that happened, and that the terminal fallback quotes package names.

## services/PackageSearch.qml

`closest`, `narrowed` and the exit code mapping are pure. Test that a
cancelled password prompt reads as cancelled, not failed. The installer path is
single-quoted inside `sh -c` in two places; test it with a path holding an
apostrophe, or pass it as an argument instead.

## services/Pacman.qml

`kernelUpdate` and `due`: test when a reboot is asked for after an upgrade,
and that the update check throttle holds across a restart.
