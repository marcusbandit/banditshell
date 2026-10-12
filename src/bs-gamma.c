#define _GNU_SOURCE

#include <errno.h>
#include <math.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/inotify.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#include "gamma-client-protocol.h"

enum { largestRamp = 65536 };

struct ramp {
    struct wl_output *output;
    struct zwlr_gamma_control_v1 *control;
    uint32_t registryName;
    uint32_t size;
    int dead;
};

static struct wl_display *display;
static struct zwlr_gamma_control_manager_v1 *manager;
static struct ramp ramps[64];
static int rampCount;
static int kelvin = -1;
static int stateValue = -1;

static const char stateName[] = "warmth";
static char stateDirectory[512];
static char statePath[600];
static int stateWatch = -1;

static int resolveState(void) {
    const char *state = getenv("XDG_STATE_HOME");
    int length;
    if (state && *state) {
        length = snprintf(stateDirectory, sizeof(stateDirectory), "%s/banditshell", state);
    } else {
        const char *home = getenv("HOME");
        if (!home || !*home) return -1;
        length = snprintf(stateDirectory, sizeof(stateDirectory), "%s/.local/state/banditshell", home);
    }
    if (length < 0 || (size_t) length >= sizeof(stateDirectory)) return -1;
    snprintf(statePath, sizeof(statePath), "%s/%s", stateDirectory, stateName);
    return 0;
}

static int makeDirectories(void) {
    char path[sizeof(stateDirectory)];
    memcpy(path, stateDirectory, sizeof(path));
    for (char *cursor = path + 1; *cursor; cursor++) {
        if (*cursor != '/') continue;
        *cursor = '\0';
        if (mkdir(path, 0700) != 0 && errno != EEXIST) return -1;
        *cursor = '/';
    }
    if (mkdir(path, 0700) != 0 && errno != EEXIST) return -1;
    return 0;
}

static int readState(int *out) {
    FILE *f = fopen(statePath, "r");
    if (!f) return -1;

    char buf[64] = {0};
    const char *got = fgets(buf, sizeof(buf), f);
    fclose(f);
    if (!got) return -1;

    while (*got == ' ' || *got == '\t') got++;
    if (strncmp(got, "off", 3) == 0) {
        *out = 0;
        return 0;
    }

    char *end = NULL;
    long k = strtol(got, &end, 10);
    if (end == got) return -1;
    if (k < 0) k = 0;
    if (k > 0 && k < 1000) k = 1000;
    if (k > 20000) k = 20000;
    *out = (int) k;
    return 0;
}

static void gainsFor(double k, double *r, double *g, double *b) {
    double t = k / 100.0;
    double rr, gg, bb;

    if (t <= 66) {
        rr = 255;
        gg = 99.4708025861 * log(t) - 161.1195681661;
    } else {
        rr = 329.698727446 * pow(t - 60, -0.1332047592);
        gg = 288.1221695283 * pow(t - 60, -0.0755148492);
    }
    if (t >= 66) {
        bb = 255;
    } else if (t <= 19) {
        bb = 0;
    } else {
        bb = 138.5177312231 * log(t - 10) - 305.0447927307;
    }

    double m = rr;
    if (gg > m) m = gg;
    if (bb > m) m = bb;

    *r = rr / m;
    *g = gg / m;
    *b = bb / m;
}

static uint16_t u16(double v) {
    if (v < 0) v = 0;
    if (v > 65535) v = 65535;
    return (uint16_t) lround(v);
}

static void applyTo(struct ramp *r, int k) {
    if (!r->control || r->dead || r->size == 0 || r->size > largestRamp) return;

    size_t n = r->size;
    size_t bytes = 3 * n * sizeof(uint16_t);
    uint16_t *table = malloc(bytes);
    if (!table) return;

    double kr = 1, kg = 1, kb = 1;
    if (k > 0) gainsFor(k, &kr, &kg, &kb);

    for (size_t i = 0; i < n; i++) {
        double v = n > 1 ? (double) i * 65535.0 / (double) (n - 1) : 65535.0;
        table[i] = u16(kr * v);
        table[n + i] = u16(kg * v);
        table[2 * n + i] = u16(kb * v);
    }

    int fd = memfd_create("banditshell-gamma", MFD_CLOEXEC);
    if (fd < 0) {
        free(table);
        return;
    }

    size_t written = 0;
    while (written < bytes) {
        ssize_t put = write(fd, (char *) table + written, bytes - written);
        if (put <= 0) break;
        written += (size_t) put;
    }
    free(table);

    if (written != bytes || lseek(fd, 0, SEEK_SET) != 0) {
        close(fd);
        return;
    }

    zwlr_gamma_control_v1_set_gamma(r->control, fd);
    wl_display_flush(display);
    close(fd);

    fprintf(stdout, "set %u %d\n", r->registryName, k);
    fflush(stdout);
}

static void applyAll(int k) {
    for (int i = 0; i < rampCount; i++)
        applyTo(&ramps[i], k);
}

static struct ramp *findControl(struct zwlr_gamma_control_v1 *control) {
    for (int i = 0; i < rampCount; i++)
        if (ramps[i].control == control) return &ramps[i];
    return NULL;
}

static void sizeHandler(void *data, struct zwlr_gamma_control_v1 *control, uint32_t size) {
    (void) data;
    struct ramp *r = findControl(control);
    if (!r || size == r->size) return;
    r->size = size;
    if (size > largestRamp)
        fprintf(stderr, "bs-gamma: output %u asks for a ramp of %u entries, which is ignored\n", r->registryName, size);
    if (kelvin >= 0) applyTo(r, kelvin);
}

static void failedHandler(void *data, struct zwlr_gamma_control_v1 *control) {
    (void) data;
    struct ramp *r = findControl(control);
    if (!r) return;
    r->dead = 1;
    fprintf(stdout, "failed %u\n", r->registryName);
    fflush(stdout);
}

static const struct zwlr_gamma_control_v1_listener gammaListener = {
    .gamma_size = sizeHandler,
    .failed = failedHandler,
};

static void registryGlobal(void *data, struct wl_registry *registry, uint32_t name, const char *iface, uint32_t version) {
    (void) data;
    if (strcmp(iface, "wl_output") == 0) {
        if (rampCount >= (int) (sizeof(ramps) / sizeof(ramps[0]))) return;
        struct wl_output *output = wl_registry_bind(registry, name, &wl_output_interface, version < 2 ? version : 2);
        if (!output) return;
        ramps[rampCount].output = output;
        ramps[rampCount].control = NULL;
        ramps[rampCount].registryName = name;
        ramps[rampCount].size = 0;
        ramps[rampCount].dead = 0;
        rampCount++;
    } else if (strcmp(iface, zwlr_gamma_control_manager_v1_interface.name) == 0) {
        manager = wl_registry_bind(registry, name, &zwlr_gamma_control_manager_v1_interface, 1);
    }
}

static void registryGlobalRemove(void *data, struct wl_registry *registry, uint32_t name) {
    (void) data;
    (void) registry;
    for (int i = 0; i < rampCount; i++) {
        if (ramps[i].registryName != name) continue;
        if (ramps[i].control)
            zwlr_gamma_control_v1_destroy(ramps[i].control);
        wl_output_destroy(ramps[i].output);
        ramps[i] = ramps[rampCount - 1];
        rampCount--;
        return;
    }
}

static const struct wl_registry_listener registryListener = {
    .global = registryGlobal,
    .global_remove = registryGlobalRemove,
};

static void bindControls(void) {
    if (!manager) return;
    for (int i = 0; i < rampCount; i++) {
        if (ramps[i].control || ramps[i].dead) continue;
        ramps[i].control = zwlr_gamma_control_manager_v1_get_gamma_control(manager, ramps[i].output);
        if (!ramps[i].control) continue;
        zwlr_gamma_control_v1_add_listener(ramps[i].control, &gammaListener, NULL);
    }
}

static void applyState(void) {
    int want = -1;
    if (readState(&want) != 0) return;
    if (want == stateValue) return;
    stateValue = want;
    kelvin = want;
    applyAll(kelvin);
}

static int watchState(int watcher) {
    if (stateWatch >= 0) inotify_rm_watch(watcher, stateWatch);
    if (makeDirectories() != 0) return -1;
    stateWatch = inotify_add_watch(watcher, stateDirectory, IN_CLOSE_WRITE | IN_MOVED_TO | IN_DELETE_SELF | IN_MOVE_SELF);
    return stateWatch < 0 ? -1 : 0;
}

static int drainWatch(int watcher) {
    char buffer[4096] __attribute__((aligned(__alignof__(struct inotify_event))));
    int touched = 0;
    int lost = 0;

    for (;;) {
        ssize_t length = read(watcher, buffer, sizeof(buffer));
        if (length <= 0) break;
        for (char *cursor = buffer; cursor < buffer + length;) {
            const struct inotify_event *event = (const struct inotify_event *) cursor;
            if (event->wd == stateWatch) {
                if (event->mask & (IN_IGNORED | IN_DELETE_SELF | IN_MOVE_SELF))
                    lost = 1;
                else if (event->len && strcmp(event->name, stateName) == 0)
                    touched = 1;
            }
            cursor += sizeof(struct inotify_event) + event->len;
        }
    }

    if (lost) {
        if (watchState(watcher) != 0) return -1;
        touched = 1;
    }
    return touched;
}

int main(int argc, char **argv) {
    (void) argc;
    (void) argv;

    display = wl_display_connect(NULL);
    if (!display) {
        fprintf(stderr, "bs-gamma: cannot connect to the Wayland display\n");
        return 1;
    }

    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registryListener, NULL);
    wl_display_roundtrip(display);

    bindControls();
    wl_display_roundtrip(display);

    if (!manager || !rampCount) {
        fprintf(stderr, "bs-gamma: no gamma control available (compositor lacks wlr-gamma-control-v1, or no outputs)\n");
        return 1;
    }

    if (resolveState() != 0) {
        fprintf(stderr, "bs-gamma: neither XDG_STATE_HOME nor HOME gives a usable state directory\n");
        return 1;
    }

    int watcher = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (watcher < 0 || watchState(watcher) != 0) {
        fprintf(stderr, "bs-gamma: cannot watch %s: %s\n", stateDirectory, strerror(errno));
        return 1;
    }

    applyState();

    int wayland = wl_display_get_fd(display);
    for (;;) {
        while (wl_display_prepare_read(display) != 0)
            if (wl_display_dispatch_pending(display) < 0) return 1;

        short outgoing = 0;
        if (wl_display_flush(display) < 0) {
            if (errno != EAGAIN) {
                wl_display_cancel_read(display);
                return 1;
            }
            outgoing = POLLOUT;
        }

        struct pollfd fds[2] = {
            {.fd = wayland, .events = (short) (POLLIN | outgoing), .revents = 0},
            {.fd = watcher, .events = POLLIN, .revents = 0},
        };
        if (poll(fds, 2, -1) < 0) {
            wl_display_cancel_read(display);
            if (errno == EINTR) continue;
            return 1;
        }

        if (fds[0].revents & POLLIN) {
            if (wl_display_read_events(display) < 0) return 1;
        } else {
            wl_display_cancel_read(display);
            if (fds[0].revents & (POLLERR | POLLHUP | POLLNVAL)) return 1;
        }

        if (wl_display_dispatch_pending(display) < 0) return 1;
        bindControls();

        if (fds[1].revents & POLLIN) {
            int touched = drainWatch(watcher);
            if (touched < 0) return 1;
            if (touched) applyState();
        }
    }
}
