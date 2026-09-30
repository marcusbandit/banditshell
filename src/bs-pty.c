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

            shell_busy = strcmp(second + 1, shell_name) != 0;
        }

        snprintf(out, cap, "%s", rest);
        found = 1;
    }
    pclose(f);
    return found;
}

static char session_id[64] = "";
static char session_name[128] = "";
static char last_windows[8192] = "";
static int session_settled = 0;

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

static int auto_named(const char *s) {
    if (!*s)
        return 0;
    for (; *s; s++)
        if (*s < '0' || *s > '9')
            return 0;
    return 1;
}

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

static void poll_windows(void) {
    if (!session_id[0])
        return;

    char cmd[256];
    snprintf(cmd, sizeof cmd, "tmux list-windows -t '%s' -F '#{window_id}\t#{window_name}\t#{window_active}' 2>/dev/null", session_id);

    char buf[8192];
    size_t n = run_capture(cmd, buf, sizeof buf);

    while (n && buf[n - 1] == '\n')
        buf[--n] = '\0';
    if (!n || strcmp(buf, last_windows) == 0)
        return;

    snprintf(last_windows, sizeof last_windows, "%s", buf);
    emit("w", (const unsigned char *)buf, n);
}

static int read_cwd(char *out, size_t cap) {
    pid_t fg = tcgetpgrp(master);
    if (fg <= 0)
        fg = child;

    if (looks_like_tmux(fg))
        return tmux_cwd(out, cap);

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

static int command(char *line) {
    if (line[0] == 'q')
        return 0;

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

        setenv("TERM", "xterm-256color", 1);
        setenv("COLORTERM", "truecolor", 1);

        unsetenv("COLUMNS");
        unsetenv("LINES");

        unsetenv("TMUX");
        unsetenv("TMUX_PANE");
        unsetenv("TERM_PROGRAM");
        unsetenv("TERM_PROGRAM_VERSION");

        unsetenv("STY");

        const char *shell = getenv("SHELL");
        if (!shell || !*shell)
            shell = "/bin/sh";

        execlp(shell, shell, "-i", (char *)NULL);
        _exit(127);
    }

    signal(SIGPIPE, SIG_IGN);

    fcntl(master, F_SETFL, O_NONBLOCK);

    char cwd[4096] = "";
    char last[4096] = "";
    long long next_cwd = 0;
    long long give_up_at = now_ms() + 8000;
    int last_busy = -1;

    {
        const char *shell = getenv("SHELL");
        const char *base = shell ? strrchr(shell, '/') : NULL;
        snprintf(shell_name, sizeof shell_name, "%s", base ? base + 1 : shell ? shell : "sh");
        emit("s", (const unsigned char *)shell_name, strlen(shell_name));
    }

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

                if (n == 0 || (n < 0 && errno != EAGAIN && errno != EINTR))
                    running = 0;
                break;
            }
        }

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

            next_cwd = t + 300;

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
