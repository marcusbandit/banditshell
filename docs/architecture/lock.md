# The lock screen's password check

The lock screen asks PAM one question: is the person at the keyboard the one already logged in.
The stack is a single line, kept in `services/lock-pam.js`:

    auth required pam_unix.so nullok nodelay

`pam_unix` reads `/etc/shadow` through the setuid `unix_chkpwd` helper, so it works from the
unprivileged shell. The shell slows guessing itself (three free tries, then 5 s doubling to 60 s),
so `pam_unix` runs `nodelay` and there is no `pam_faillock`, whose tally in `/run/faillock` the
shell cannot write. It does not `include system-login`: `pam_shells` and `pam_nologin` answer
whether the account may start a session, which was settled at login, and an `/etc/nologin` from
a routine update must never make a locked screen unopenable.

## Never read from the checkout

The stack is held in memory and written to `$XDG_RUNTIME_DIR/banditshell/pam.d/banditshell` at
start and again right before every check. Nothing about unlocking reads the folder the shell was
started from. On 2026-11-05 a tried worktree was deleted under the running shell while the screen
was locked, PAM could not find its file, and every password got "couldn't check the password"
(#453). A shell running from a deleted folder must still open.

## The face, beside the password

A second PAM context runs a second file, `banditshell-face`, written next to the password's the
same way. It names every face module `lock.face` allows and `services/lock-pam.js` finds
installed, Gaze first:

    auth sufficient pam_gaze.so
    auth required pam_howdy.so

Gaze checks for a live face on the colour camera, so a photo that matches is still refused; in a
trial on the owner's camera (#885) it answered in 1.1 s where howdy took 1.4 to 2.3 s. It needs
light, and howdy's IR camera does not, so howdy stays behind it for a dark room. The price is
howdy's: a printed photo Gaze refuses can still reach howdy, as it can at sudo and login today.
`lock.face` is `auto` (both, whichever are installed), `gaze`, `howdy` or `off`; the older `true`
and `false` read as `auto` and `off`.

It runs alongside the password check, never inside it, so a face can open the lock while a
password is half typed, and a password still works while the camera looks. Both modules read
their root-only data through their own daemon or setuid helper, the way `pam_unix` reads
`/etc/shadow`. No `workaround=` or `simultaneous` option: those exist to end a password prompt the
module does not own, and here the prompt is ours.

When it looks is `services/lock-face.js`, tested in `tests/lock-face.test.js`. Never as the lock
comes up: only on a key, move or touch once the lock has covered the screen for 1.5 s, and no
sooner than 3 s after the last look ended. Three misses in a row stop it until the tab is pressed
or the screen wakes from rest, so a stranger at the keyboard does not keep the camera blinking. A
face miss never counts toward the password's lockout, and a lockout does not stop the face.
