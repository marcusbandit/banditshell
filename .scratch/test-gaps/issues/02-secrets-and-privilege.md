# Tests for passwords, keys and anything that asks for root

Status: ready-for-agent
Tier: 1

A bug here leaks a secret or hangs a password prompt. The scripts can be
tested today with their own stub folder on `PATH`, as in
`tests/online-scripts.test.js`; the QML pieces need their decisions moved into
`.js` first.

## installer/askpass.sh

Drive it with a stub `qs` that plays the prompt window; the one in
`cli-stubs.js` refuses to run. Test the ask and retry tokens, that only the
secret reaches stdout, that the folder is 700 and the FIFOs 600, that cancel exits 1,
and that a UI which dies after taking the request makes askpass exit instead
of hanging (#107).

## scripts/write-private.sh

Test that the file is written 600 through a temporary file and an atomic
move, that a failed write leaves the old file and no temporary behind, and
which folder gets `chmod 700`. Today that is the file's parent, which would be
`$HOME` for a file written straight into it; the callers use a subfolder, so
pin that down.

## scripts/assistant-request.sh

Test that the API key arrives on fd 3 and never appears in the argument list
of the stubbed `curl`. The script branches on the auth prefix, not on the key:
with a prefix and an empty key it still sends the bare prefix, and only
`Assistant.qml` blanking the prefix prevents that. Test both halves, or make
the script check the key itself.

## services/Keyring.qml

`take` and `reply`: the unlock password must go back with the request id it
was asked under, and a refused or cancelled prompt must not leave a request
waiting.

## services/Polkit.qml and scripts/polkit-takeover.sh

Test the takeover parse, the title and warning shown for an action, and that
`handBack` restarts what was stopped, including an agent whose binary was
replaced while it ran (#108).

## services/Clipboard.qml

Extract `sweep`'s decision and `classify`. Test that nothing is swept while
the history file is unreadable (#105), and that `classify` does not call
`2024` or `cafe` a colour.

## services/DevUtilities.qml

`copySecret`: test that a password is only copied with `--sensitive`, and what
happens when `wl-copy` lacks it.

## modules/launcher/sources/ScriptSource.qml

Check the audit's claim that a password argument is typed into the plain
search field and reaches `fd` as an argument. If it does, file it, fix it, and
test that a password argument never reaches a search command.
