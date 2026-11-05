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
