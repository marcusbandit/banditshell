// A real terminal, for something that cannot open one.
//
// Quickshell's Process gives a pipe, and a pipe is not a terminal: isatty() is
// false down it, so zsh starts non-interactive, reads no .zshrc, draws no
// prompt, and completion does not exist because ZLE never loads. Everything the
// terminal panel is FOR lives on the other side of that test. So the shell gets
// what it actually wants - a pseudoterminal - and this process sits between the
// two ends translating.
//
// THE USER'S OWN SHELL, WITH THE USER'S OWN CONFIG, and nothing of ours in it.
// $SHELL, interactive, no --no-rcs, no ZDOTDIR of our own pointing at a
// generated rc file. Their prompt, their aliases, their completion style, their
// plugins, however slow or strange. A file browser that quietly ran a sanitised
// shell would be lying about being a terminal, and the first `alias` that did
// not work would say so.
//
// WHICH IS ALSO WHY THE CWD IS NOT ASKED FOR. The usual way to learn where a
// shell is is OSC 7, and the usual way to get OSC 7 is to install a precmd hook,
// which means writing into the user's shell after all. /proc/<pid>/cwd is the
// kernel's own answer to the same question, it needs no cooperation from the
// shell, it is right for any shell rather than for the two we thought to
// support, and it cannot be broken by a prompt that overwrites the hook.
//
// It is read off the pty's FOREGROUND PROCESS GROUP rather than off the shell
// we spawned. Same answer at a prompt, since the shell is its own foreground
// group and `cd` is a builtin; a better one while something is running, because
// a command that moves is the thing the panel should be following.
//
// AND THEN THERE IS TMUX, which breaks the whole approach and is not a corner
// case: an .zshrc that attaches to a session on startup is a common setup, and
// it is the setup on this machine. The process on our pty is then the tmux
// CLIENT, and a client is a relay - it holds whatever directory it was started
// in, forever, while the shell that is actually moving lives under a server we
// are not related to and cannot reach through /proc. So when the foreground
// process is a client, the question is put to the server instead, addressed by
// the one handle we are certain of: our own slave tty, which is that client.
// Throttled harder than the readlink, because it costs a process.
//
// AND SINCE THERE IS A SESSION, THE PANEL WANTS TO OWN ONE. Tabs in the file
// browser are tmux windows, which only works if the session holding them is
// ours to rename, add to and kill on the way out. But the session we land in is
// whatever the user's config produced, and killing somebody's afternoon because
// they happened to have a session lying around is not a thing to get wrong. So
// the session is only ADOPTED when it is provably empty - one window, one pane,
// nothing but the shell in it, tmux's own numeric name, our client the only one
// attached - and otherwise our client walks away from it into a session we made
// ourselves. Either way the name is ours afterwards, and `k` may kill it.
//
// The wire, one frame per line, in both directions:
//
//   out   o <base64>   bytes the terminal produced
//         c <base64>   the shell's working directory, when it changes
//         s <base64>   which shell this is, once, at startup
//         b <0|1>      whether something is RUNNING in it, when that changes
//         t <base64>   the tmux session this pty owns, once it is settled
//         w <base64>   its windows, "id\tname\tactive" per line, when they change
//         x <status>   the shell exited
//   in    i <base64>   bytes to type into it
//         r <cols> <rows>   the window resized
//         k            kill the session
//         q            quit
#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pty.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

#include "bs-b64.h"

// One read off the master. Bigger than a screen's worth of escape codes, so a
// burst of output is a handful of frames rather than hundreds.
#define CHUNK 16384

static int master = -1;
static pid_t child = -1;

static long long now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static void emit(const char *tag, const unsigned char *data, size_t len) {
    char *b64 = malloc(4 * ((len + 2) / 3) + 1);
    if (!b64)
        return;
    bs_b64_encode(data, len, b64);
    printf("%s %s\n", tag, b64);
    fflush(stdout);
    free(b64);
}

// The short name of a process, or "" if it has gone.
static void proc_name(pid_t pid, char *out, size_t cap) {
    char path[64];
    snprintf(path, sizeof path, "/proc/%d/comm", (int)pid);
    out[0] = '\0';
    FILE *f = fopen(path, "r");
    if (!f)
        return;
    if (fgets(out, (int)cap, f))
        out[strcspn(out, "\n")] = '\0';
    fclose(f);
}

// Whether the thing on our tty is a tmux client, without spawning anything to
// find out. The process itself is usually not called tmux: an .zshrc that
// attaches on startup does it through a wrapper, and this machine's is called
// tmux-wrapper.sh, so the client is that script's child rather than the
// foreground process. One level down is enough for every arrangement of this
// shape, and it is a handful of small reads out of /proc rather than a fork.
// WHETHER THE SHELL IS BUSY, which decides whether anything may be typed at it.
//
// A file browser that types `cd` at a prompt is using the shell. One that types
// `cd` into a running vim is corrupting a file. The two are indistinguishable
// from the outside unless somebody asks, so this asks: the foreground process
// group is the shell itself when it is waiting for you, and something else when
// it is not.
//
// Under tmux it is always the client, so the question goes to the server along
// with the directory - one query answers both.
static int shell_busy = -1;
static char shell_name[64] = "";

static int looks_like_tmux(pid_t pid) {
    char name[64];
    proc_name(pid, name, sizeof name);
    if (strstr(name, "tmux"))
        return 1;

    char path[80];
    snprintf(path, sizeof path, "/proc/%d/task/%d/children", (int)pid, (int)pid);
    FILE *f = fopen(path, "r");
    if (!f)
        return 0;

    int found = 0;
    int kid;
    while (!found && fscanf(f, "%d", &kid) == 1) {
        proc_name(kid, name, sizeof name);
        found = strstr(name, "tmux") != NULL;
    }
    fclose(f);
    return found;
}

// Where the tmux session on OUR tty currently is.
//
// The whole client list, matched on tty, rather than `display-message -c`: the
// targeted form fails in ways that are indistinguishable from having no answer,
// and this way the tty match is ours to make and a client that is not there is
// simply absent from the list.
static int tmux_cwd(char *out, size_t cap) {
    const char *tty = ptsname(master);
    if (!tty)
        return 0;

    FILE *f = popen("tmux list-clients -F '#{client_tty}\t#{pane_current_path}\t#{pane_current_command}' 2>/dev/null", "r");
    if (!f)
        return 0;

    char line[8192];
    int found = 0;
    while (!found && fgets(line, sizeof line, f)) {
        line[strcspn(line, "\n")] = '\0';
        char *tab = strchr(line, '\t');
        if (!tab)
            continue;
        *tab = '\0';
        if (strcmp(line, tty) != 0 || tab[1] != '/')
            continue;

        char *rest = tab + 1;
        char *second = strchr(rest, '\t');
        if (second) {
            *second = '\0';
            // The command the pane is running. When it is the shell, the shell
            // is what is waiting for you.
            shell_busy = strcmp(second + 1, shell_name) != 0;
        }

        snprintf(out, cap, "%s", rest);
        found = 1;
    }
    pclose(f);
    return found;
}

// THE SESSION THIS PTY OWNS, and the windows in it.
//
// Every query is addressed by #{session_id} rather than by name. A session
// called "0" is what the user's tmux wrapper produces, and a bare number as a
// target is ambiguous - tmux will happily read it as an index - so the one
// unambiguous handle is the id, and the name exists only to be reported.
static char session_id[64] = "";
static char session_name[128] = "";
static char last_windows[8192] = "";
static int session_settled = 0;

// Everything a command said, up to cap. Small outputs by construction: a client
// list, a pane list, a session id.
static size_t run_capture(const char *cmd, char *out, size_t cap) {
    out[0] = '\0';
    FILE *f = popen(cmd, "r");
    if (!f)
        return 0;
    size_t len = fread(out, 1, cap - 1, f);
    out[len] = '\0';
    pclose(f);
    return len;
}

// A name tmux invented rather than one a person chose. The wrapper names
// sessions 0, 1, 2..., so a session still wearing a number is one nobody has
// claimed; a name with a letter in it is somebody's, and is left alone.
static int auto_named(const char *s) {
    if (!*s)
        return 0;
    for (; *s; s++)
        if (*s < '0' || *s > '9')
            return 0;
    return 1;
}

// THE SESSION HUNT. Runs on the cwd poll until it settles, which is either when
// a session is ours or when give_up says the shell has had long enough and
// there is evidently no tmux here at all. Emits t exactly once, or never.
//
// give_up also decides the one test that is not stable. Windows, clients and
// the name are what they are, but a pane running something is a pane that might
// simply still be sourcing .zshrc - the user's config runs tmux itself in
// there, so the first look after a session appears reliably reports the pane as
// busy. Deciding on that would abandon a perfectly empty session and leave it
// behind detached, so a busy pane is a reason to look again rather than an
// answer, until the deadline turns it into one.
static void adopt_session(int give_up) {
    const char *tty = ptsname(master);
    if (!tty)
        return;

    char buf[8192];
    run_capture("tmux list-clients -F '#{client_tty}\t#{session_id}\t#{session_name}\t#{session_attached}\t#{session_windows}' 2>/dev/null",
                buf, sizeof buf);

    char sid[64] = "", name[128] = "";
    int attached = 0, windows = 0;
    for (char *line = strtok(buf, "\n"); line; line = strtok(NULL, "\n")) {
        char ctty[256];
        if (sscanf(line, "%255[^\t]\t%63[^\t]\t%127[^\t]\t%d\t%d", ctty, sid, name, &attached, &windows) != 5)
            continue;
        if (strcmp(ctty, tty) == 0)
            break;
        sid[0] = '\0';
    }

    if (!sid[0]) {
        // No client of ours on the server: either tmux has not come up yet, or
        // this is a shell that does not use it. Both look the same until the
        // deadline says which it was.
        session_settled = give_up;
        return;
    }

    int empty = windows == 1 && attached == 1 && auto_named(name);
    if (empty) {
        char cmd[256];
        snprintf(cmd, sizeof cmd, "tmux list-panes -s -t '%s' -F '#{pane_current_command}' 2>/dev/null", sid);
        size_t n = run_capture(cmd, buf, sizeof buf);
        while (n && buf[n - 1] == '\n')
            buf[--n] = '\0';
        // One line only - a second pane would leave a newline inside what is
        // left - and that one line is the shell doing nothing.
        empty = n > 0 && strchr(buf, '\n') == NULL && strcmp(buf, shell_name) == 0;
        if (!empty && !give_up)
            return;
    }

    char ours[128];
    snprintf(ours, sizeof ours, "banditshell-files-%d", (int)getpid());

    char cmd[512];
    if (empty) {
        snprintf(cmd, sizeof cmd, "tmux rename-session -t '%s' '%s' 2>/dev/null", sid, ours);
        if (system(cmd) != 0) {
            session_settled = give_up;
            return;
        }
    } else {
        // Somebody's session. Ours is made detached and the client is walked
        // over to it, which leaves theirs exactly as it was, minus a viewer.
        snprintf(cmd, sizeof cmd, "tmux new-session -d -P -F '#{session_id}' -s '%s' 2>/dev/null", ours);
        run_capture(cmd, buf, sizeof buf);
        buf[strcspn(buf, "\n")] = '\0';
        if (buf[0] != '$') {
            session_settled = give_up;
            return;
        }
        snprintf(sid, sizeof sid, "%s", buf);
        snprintf(cmd, sizeof cmd, "tmux switch-client -c '%s' -t '%s' 2>/dev/null", tty, sid);
        system(cmd);
    }

    snprintf(session_id, sizeof session_id, "%s", sid);
    snprintf(session_name, sizeof session_name, "%s", ours);
    session_settled = 1;
    emit("t", (const unsigned char *)session_name, strlen(session_name));
}

// The windows of that session, as the browser's tabs. Sent only when the string
// changes: it is polled, so every unchanged answer that went out would be a tab
// bar rebuilding itself three times a second for nothing.
static void poll_windows(void) {
    if (!session_id[0])
        return;

    char cmd[256];
    snprintf(cmd, sizeof cmd, "tmux list-windows -t '%s' -F '#{window_id}\t#{window_name}\t#{window_active}' 2>/dev/null", session_id);

    char buf[8192];
    size_t n = run_capture(cmd, buf, sizeof buf);
    // The trailing newline goes: it is a separator here and not a line, and the
    // far end splits on it.
    while (n && buf[n - 1] == '\n')
        buf[--n] = '\0';
    if (!n || strcmp(buf, last_windows) == 0)
        return;

    snprintf(last_windows, sizeof last_windows, "%s", buf);
    emit("w", (const unsigned char *)buf, n);
}

// THE DIRECTORY THE PANEL SHOULD BE SHOWING, or nothing if it cannot be worked
// out. Polled rather than pushed, because there is no event for it; see the
// header note for why it is read off the kernel instead of asked for, and for
// what tmux does to that.
static int read_cwd(char *out, size_t cap) {
    pid_t fg = tcgetpgrp(master);
    if (fg <= 0)
        fg = child;

    if (looks_like_tmux(fg))
        return tmux_cwd(out, cap);

    // Not under tmux: the shell is idle exactly when it is its own foreground
    // process group.
    shell_busy = fg != child;

    char link[64];
    snprintf(link, sizeof link, "/proc/%d/cwd", (int)fg);
    ssize_t n = readlink(link, out, cap - 1);
    if (n < 0)
        return 0;
    out[n] = '\0';
    return 1;
}

static void resize(int cols, int rows) {
    struct winsize ws = {0};
    ws.ws_col = (unsigned short)(cols > 0 ? cols : 80);
    ws.ws_row = (unsigned short)(rows > 0 ? rows : 24);
    ioctl(master, TIOCSWINSZ, &ws);
}

// One command line off stdin. Returns 0 when the caller should stop.
static int command(char *line) {
    if (line[0] == 'q')
        return 0;

    // OURS AND ONLY OURS. The id is the one we reported in t, so a session the
    // browser never owned cannot be reached through this frame however it is
    // asked; if adoption never settled there is nothing to kill and this is
    // just a quit.
    if (line[0] == 'k') {
        if (session_id[0]) {
            char cmd[256];
            snprintf(cmd, sizeof cmd, "tmux kill-session -t '%s' 2>/dev/null", session_id);
            system(cmd);
        }
        return 0;
    }

    if (line[0] == 'i' && line[1] == ' ') {
        unsigned char *buf = malloc(strlen(line));
        if (!buf)
            return 1;
        size_t n = bs_b64_decode(line + 2, buf);
        // WRITE ALL OF IT. A pty master's buffer is finite and a paste is not:
        // a short write here drops the tail of what was typed, which is the
        // kind of bug that only shows up on the one long line that mattered.
        for (size_t off = 0; off < n;) {
            ssize_t w = write(master, buf + off, n - off);
            if (w > 0) {
                off += (size_t)w;
                continue;
            }
            if (errno == EINTR)
                continue;
            if (errno == EAGAIN) {
                struct pollfd p = {master, POLLOUT, 0};
                poll(&p, 1, 100);
                continue;
            }
            break;
        }
        free(buf);
        return 1;
    }

    if (line[0] == 'r') {
        int cols = 0, rows = 0;
        if (sscanf(line + 1, "%d %d", &cols, &rows) == 2)
            resize(cols, rows);
        return 1;
    }

    return 1;
}

int main(int argc, char **argv) {
    int cols = argc > 1 ? atoi(argv[1]) : 80;
    int rows = argc > 2 ? atoi(argv[2]) : 24;

    struct winsize ws = {0};
    ws.ws_col = (unsigned short)(cols > 0 ? cols : 80);
    ws.ws_row = (unsigned short)(rows > 0 ? rows : 24);

    child = forkpty(&master, NULL, NULL, &ws);
    if (child < 0) {
        fprintf(stderr, "bs-pty: forkpty: %s\n", strerror(errno));
        return 1;
    }

    if (child == 0) {
        // WHAT THE SHELL IS TOLD IT IS TALKING TO. The emulator on the other
        // end (components/vt.js) implements xterm's vocabulary, so it says
        // xterm-256color; claiming anything richer would invite sequences that
        // get drawn as mojibake instead of obeyed.
        setenv("TERM", "xterm-256color", 1);
        setenv("COLORTERM", "truecolor", 1);
        // Stale from whatever spawned the shell, and wrong the moment the
        // window is resized. The tty's own size is the truth.
        unsetenv("COLUMNS");
        unsetenv("LINES");

        // AND THE PREVIOUS TERMINAL'S IDENTITY, which is not stale so much as
        // someone else's.
        //
        // The shell drawing this window was itself started from a terminal, and
        // on this machine that terminal was inside tmux - so TMUX, TMUX_PANE and
        // TERM_PROGRAM were in its environment, were inherited straight through
        // here, and an .zshrc whose auto-start reads `[[ -z "$TMUX" ]]` decided
        // it was already inside a session and did nothing. The user's config was
        // being read perfectly and then correctly declining to do the thing they
        // were looking for.
        //
        // A new terminal window inherits none of this, so neither does this one.
        // It is the one place where NOT passing the environment on is what makes
        // the config behave the way it does everywhere else.
        unsetenv("TMUX");
        unsetenv("TMUX_PANE");
        unsetenv("TERM_PROGRAM");
        unsetenv("TERM_PROGRAM_VERSION");
        // screen's equivalent, for the same reason.
        unsetenv("STY");

        const char *shell = getenv("SHELL");
        if (!shell || !*shell)
            shell = "/bin/sh";

        // INTERACTIVE, and not a login shell. That is what a terminal emulator
        // opens by default, so it is what loads the config the user has
        // actually been editing: .zshrc rather than .zprofile. -i is belt and
        // braces - a shell with a tty on stdin is already interactive - but it
        // is what makes this correct for the shells that decide otherwise.
        execlp(shell, shell, "-i", (char *)NULL);
        _exit(127);
    }

    signal(SIGPIPE, SIG_IGN);
    // NON-BLOCKING MASTER, blocking stdin. A read off the master must never
    // park this process while the shell has nothing to say, because the same
    // loop is what delivers keystrokes to it.
    fcntl(master, F_SETFL, O_NONBLOCK);

    char cwd[4096] = "";
    char last[4096] = "";
    long long next_cwd = 0;
    long long give_up_at = now_ms() + 8000;
    int last_busy = -1;

    // WHICH SHELL THIS IS, said once. The far end needs it to know how to clear
    // a half-typed line: zsh can push it aside and give it back afterwards,
    // which is a nicer thing to do to somebody's typing than deleting it, and
    // not every shell can.
    {
        const char *shell = getenv("SHELL");
        const char *base = shell ? strrchr(shell, '/') : NULL;
        snprintf(shell_name, sizeof shell_name, "%s", base ? base + 1 : shell ? shell : "sh");
        emit("s", (const unsigned char *)shell_name, strlen(shell_name));
    }

    // A growable line buffer for stdin: a paste arrives as one frame and there
    // is no useful ceiling on how long that is.
    size_t cap = 8192, len = 0;
    char *line = malloc(cap);
    if (!line)
        return 1;

    unsigned char chunk[CHUNK];
    int running = 1;

    while (running) {
        struct pollfd fds[2] = {{master, POLLIN, 0}, {STDIN_FILENO, POLLIN, 0}};
        int ready = poll(fds, 2, 100);
        if (ready < 0 && errno != EINTR)
            break;

        if (fds[0].revents & (POLLIN | POLLHUP)) {
            for (;;) {
                ssize_t n = read(master, chunk, sizeof chunk);
                if (n > 0) {
                    emit("o", chunk, (size_t)n);
                    continue;
                }
                // EIO off a pty master is the far end closing, not an error
                // worth reporting: it is how a shell says goodbye.
                if (n == 0 || (n < 0 && errno != EAGAIN && errno != EINTR))
                    running = 0;
                break;
            }
        }

        // POLLHUP AS WELL AS POLLIN, and this is not belt and braces: it is the
        // difference between a helper that dies with the window that opened it
        // and one that does not.
        //
        // When the shell that spawned this goes away, our stdin is closed. A
        // closed pipe reports POLLHUP and NOT POLLIN, so a loop that tests only
        // for readability never notices, poll() returns immediately forever, and
        // the process spins on undying - along with the whole shell session
        // under it. Six of them were found running after an afternoon of opening
        // and closing preview windows.
        if (fds[1].revents & (POLLIN | POLLHUP | POLLERR)) {
            char in[4096];
            ssize_t n = read(STDIN_FILENO, in, sizeof in);
            if (n <= 0)
                break;
            for (ssize_t i = 0; i < n; i++) {
                if (in[i] != '\n') {
                    if (len + 2 > cap) {
                        cap *= 2;
                        char *grown = realloc(line, cap);
                        if (!grown)
                            return 1;
                        line = grown;
                    }
                    line[len++] = in[i];
                    continue;
                }
                line[len] = '\0';
                len = 0;
                if (!command(line))
                    running = 0;
            }
        }

        long long t = now_ms();
        if (t >= next_cwd) {
            // Wide enough that the tmux path (a process per poll) is not a
            // load, tight enough that a `cd` lands before you have looked back
            // up at the grid.
            next_cwd = t + 300;

            // THE SESSION FIRST, because everything else about it is answered
            // against the id this finds, and because renaming it later - once
            // the browser has drawn tabs for a session under another name -
            // would be a rename the far end has to cope with. A few seconds is
            // long enough for the user's config to have attached if it was ever
            // going to; after that this is a shell without tmux and t simply
            // never comes.
            if (!session_settled)
                adopt_session(t >= give_up_at);
            else
                poll_windows();

            if (read_cwd(cwd, sizeof cwd) && strcmp(cwd, last) != 0) {
                strcpy(last, cwd);
                emit("c", (const unsigned char *)cwd, strlen(cwd));
            }

            if (shell_busy >= 0 && shell_busy != last_busy) {
                last_busy = shell_busy;
                printf("b %d\n", shell_busy);
                fflush(stdout);
            }
        }

        int status;
        if (waitpid(child, &status, WNOHANG) == child) {
            printf("x %d\n", WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status));
            fflush(stdout);
            running = 0;
        }
    }

    if (child > 0)
        kill(child, SIGHUP);
    free(line);
    return 0;
}
