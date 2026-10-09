#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#include "gamma-client-protocol.h"

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

static const char *statePath(void) {
    static char path[512];
    const char *state = getenv("XDG_STATE_HOME");
    if (state && *state) {
        snprintf(path, sizeof(path), "%s/banditshell/warmth", state);
    } else {
        const char *home = getenv("HOME");
        if (!home || !*home) return NULL;
        snprintf(path, sizeof(path), "%s/.local/state/banditshell/warmth", home);
    }
    return path;
}

static int readFile(int *out) {
    const char *path = statePath();
    if (!path) return -1;

    FILE *f = fopen(path, "r");
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
    if (!r->control || r->dead || !r->size) return;

    uint32_t n = r->size;
    uint32_t bytes = 3 * n * sizeof(uint16_t);
    uint16_t *table = malloc(bytes);
    if (!table) return;

    double kr = 1, kg = 1, kb = 1;
    if (k > 0) gainsFor(k, &kr, &kg, &kb);

    for (uint32_t i = 0; i < n; i++) {
        double v = (double) i * 65535.0 / (double) (n - 1);
        table[i] = u16(kr * v);
        table[n + i] = u16(kg * v);
        table[2 * n + i] = u16(kb * v);
    }

    int fd = memfd_create("banditshell-gamma", MFD_CLOEXEC);
    if (fd < 0) {
        free(table);
        return;
    }

    ssize_t written = 0;
    while (written < (ssize_t) bytes) {
        ssize_t put = write(fd, (char *) table + written, bytes - written);
        if (put <= 0) break;
        written += put;
    }
    free(table);

    if (written != (ssize_t) bytes) {
        close(fd);
        return;
    }

    if (lseek(fd, 0, SEEK_SET) != 0) {
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

static int stateValue = -1;

static void pollState(void) {
    int want = -1;
    if (readFile(&want) != 0) return;
    if (want == stateValue) return;
    stateValue = want;
    kelvin = want;
    applyAll(kelvin);
}

static void nap(int ms) {
    struct timespec ts = {.tv_sec = ms / 1000, .tv_nsec = (long) (ms % 1000) * 1000000L};
    nanosleep(&ts, NULL);
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

    pollState();

    while (1) {
        for (int i = 0; i < 6; i++) {
            nap(50);

            while (wl_display_prepare_read(display) != 0)
                wl_display_dispatch_pending(display);

            wl_display_flush(display);

            struct pollfd fds[1] = {{.fd = wl_display_get_fd(display), .events = POLLIN, .revents = 0}};
            if (poll(fds, 1, 0) > 0 && (fds[0].revents & (POLLIN | POLLHUP | POLLERR))) {
                if (wl_display_read_events(display) < 0) return 1;
            } else {
                wl_display_cancel_read(display);
            }

            wl_display_dispatch_pending(display);
            bindControls();
        }

        pollState();
    }
}
