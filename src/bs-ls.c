#define _GNU_SOURCE

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <poll.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/inotify.h>
#include <sys/stat.h>
#include <unistd.h>

#define SNIFF 4096
#define QUIET_MS 100
#define BURST_MS 1000
#define BATCH_MS 20

struct classing {
    const char *ext;
    const char *cls;
};

static const struct classing EXTENSIONS[] = {
    {"png", "image"}, {"jpg", "image"}, {"jpeg", "image"}, {"jpe", "image"},
    {"gif", "image"}, {"bmp", "image"}, {"webp", "image"}, {"tif", "image"},
    {"tiff", "image"}, {"svg", "image"}, {"svgz", "image"}, {"ico", "image"},
    {"icns", "image"}, {"avif", "image"}, {"heic", "image"}, {"heif", "image"},
    {"jxl", "image"}, {"ppm", "image"}, {"pgm", "image"}, {"pbm", "image"},
    {"pnm", "image"}, {"tga", "image"}, {"psd", "image"}, {"xcf", "image"},
    {"cr2", "image"}, {"nef", "image"}, {"arw", "image"}, {"dng", "image"},
    {"raw", "image"}, {"exr", "image"}, {"hdr", "image"}, {"qoi", "image"},

    {"mp4", "video"}, {"mkv", "video"}, {"webm", "video"}, {"mov", "video"},
    {"avi", "video"}, {"wmv", "video"}, {"flv", "video"}, {"m4v", "video"},
    {"mpg", "video"}, {"mpeg", "video"}, {"3gp", "video"}, {"ogv", "video"},
    {"ts", "video"}, {"m2ts", "video"}, {"vob", "video"}, {"rmvb", "video"},

    {"mp3", "audio"}, {"flac", "audio"}, {"wav", "audio"}, {"ogg", "audio"},
    {"oga", "audio"}, {"opus", "audio"}, {"m4a", "audio"}, {"aac", "audio"},
    {"wma", "audio"}, {"aiff", "audio"}, {"aif", "audio"}, {"ape", "audio"},
    {"alac", "audio"}, {"mid", "audio"}, {"midi", "audio"}, {"mod", "audio"},
    {"xm", "audio"}, {"it", "audio"}, {"s3m", "audio"},

    {"zip", "archive"}, {"tar", "archive"}, {"gz", "archive"}, {"tgz", "archive"},
    {"bz2", "archive"}, {"tbz", "archive"}, {"xz", "archive"}, {"txz", "archive"},
    {"zst", "archive"}, {"7z", "archive"}, {"rar", "archive"}, {"lz", "archive"},
    {"lzma", "archive"}, {"lz4", "archive"}, {"cab", "archive"}, {"arj", "archive"},
    {"iso", "archive"}, {"img", "archive"}, {"deb", "archive"}, {"rpm", "archive"},
    {"pkg", "archive"}, {"apk", "archive"}, {"jar", "archive"}, {"war", "archive"},

    {"pdf", "pdf"},

    {"doc", "document"}, {"docx", "document"}, {"odt", "document"},
    {"rtf", "document"}, {"xls", "document"}, {"xlsx", "document"},
    {"ods", "document"}, {"ppt", "document"}, {"pptx", "document"},
    {"odp", "document"}, {"epub", "document"}, {"mobi", "document"},
    {"azw3", "document"}, {"djvu", "document"},

    {"ttf", "font"}, {"otf", "font"}, {"woff", "font"}, {"woff2", "font"},
    {"ttc", "font"}, {"pfb", "font"}, {"bdf", "font"}, {"pcf", "font"},

    {"c", "code"}, {"h", "code"}, {"cpp", "code"}, {"cc", "code"},
    {"cxx", "code"}, {"hpp", "code"}, {"hh", "code"}, {"rs", "code"},
    {"go", "code"}, {"py", "code"}, {"rb", "code"}, {"js", "code"},
    {"jsx", "code"}, {"ts", "code"}, {"tsx", "code"}, {"qml", "code"},
    {"java", "code"}, {"kt", "code"}, {"swift", "code"}, {"php", "code"},
    {"pl", "code"}, {"pm", "code"}, {"lua", "code"}, {"sh", "code"},
    {"bash", "code"}, {"zsh", "code"}, {"fish", "code"}, {"ps1", "code"},
    {"sql", "code"}, {"jl", "code"}, {"scala", "code"}, {"clj", "code"},
    {"ex", "code"}, {"exs", "code"}, {"erl", "code"}, {"hs", "code"},
    {"ml", "code"}, {"nim", "code"}, {"zig", "code"}, {"v", "code"},
    {"cs", "code"}, {"vb", "code"}, {"asm", "code"}, {"frag", "code"},
    {"vert", "code"}, {"glsl", "code"}, {"patch", "code"}, {"diff", "code"},

    {"txt", "text"}, {"md", "text"}, {"markdown", "text"}, {"rst", "text"},
    {"org", "text"}, {"tex", "text"}, {"bib", "text"}, {"log", "text"},
    {"conf", "text"}, {"cfg", "text"}, {"ini", "text"}, {"toml", "text"},
    {"yaml", "text"}, {"yml", "text"}, {"json", "text"}, {"xml", "text"},
    {"html", "text"}, {"htm", "text"}, {"css", "text"}, {"scss", "text"},
    {"sass", "text"}, {"less", "text"}, {"csv", "text"}, {"tsv", "text"},
    {"desktop", "text"}, {"service", "text"}, {"lock", "text"}, {"rules", "text"},

    {"so", "binary"}, {"o", "binary"}, {"a", "binary"}, {"dll", "binary"},
    {"exe", "binary"}, {"dylib", "binary"}, {"ko", "binary"}, {"class", "binary"},
    {"pyc", "binary"}, {"wasm", "binary"}, {"db", "binary"}, {"sqlite", "binary"},
};

static void extension(const char *name, char *out, size_t cap) {
    out[0] = '\0';
    const char *dot = strrchr(name, '.');
    if (!dot || dot == name || !dot[1])
        return;

    size_t n = 0;
    for (const char *p = dot + 1; *p && n + 1 < cap; p++)
        out[n++] = (char)(*p >= 'A' && *p <= 'Z' ? *p + 32 : *p);
    out[n] = '\0';
}

static const char *class_of(const char *ext) {
    if (!*ext)
        return "unknown";
    for (size_t i = 0; i < sizeof EXTENSIONS / sizeof *EXTENSIONS; i++)
        if (strcmp(EXTENSIONS[i].ext, ext) == 0)
            return EXTENSIONS[i].cls;
    return "unknown";
}

static void json_string(const char *in) {
    static const char *HEX = "0123456789abcdef";
    putchar('"');

    const unsigned char *p = (const unsigned char *)in;
    while (*p) {
        unsigned char c = *p;

        if (c == '"' || c == '\\') {
            putchar('\\');
            putchar((char)c);
            p++;
            continue;
        }
        if (c < 0x20) {
            printf("\\u00%c%c", HEX[c >> 4], HEX[c & 15]);
            p++;
            continue;
        }
        if (c < 0x80) {
            putchar((char)c);
            p++;
            continue;
        }

        int len = (c & 0xe0) == 0xc0 ? 2 : (c & 0xf0) == 0xe0 ? 3 : (c & 0xf8) == 0xf0 ? 4 : 0;
        int ok = len > 0;
        for (int i = 1; ok && i < len; i++)
            ok = (p[i] & 0xc0) == 0x80;

        if (!ok) {
            fputs("\\ufffd", stdout);
            p++;
            continue;
        }
        for (int i = 0; i < len; i++)
            putchar((char)p[i]);
        p += len;
    }

    putchar('"');
}

static const char *kind_of(mode_t m) {
    if (S_ISDIR(m))
        return "dir";
    if (S_ISLNK(m))
        return "link";
    if (S_ISFIFO(m))
        return "fifo";
    if (S_ISSOCK(m))
        return "sock";
    if (S_ISBLK(m))
        return "block";
    if (S_ISCHR(m))
        return "char";
    return "file";
}

static int print_entry(int fd, const char *name, const char *dir, int first) {
    struct stat ls;
    if (fstatat(fd, name, &ls, AT_SYMLINK_NOFOLLOW) != 0)
        return 0;

    struct stat st = ls;
    int link = S_ISLNK(ls.st_mode);
    int broken = 0;
    if (link && fstatat(fd, name, &st, 0) != 0) {
        broken = 1;
        st = ls;
    }

    char ext[32];
    extension(name, ext, sizeof ext);
    const char *cls = S_ISDIR(st.st_mode) ? "directory" : class_of(ext);
    int exec = !S_ISDIR(st.st_mode) && (st.st_mode & (S_IXUSR | S_IXGRP | S_IXOTH));

    if (exec && strcmp(cls, "unknown") == 0)
        cls = "program";

    printf(first ? "{" : ",{");
    if (dir) {
        printf("\"dir\":");
        json_string(dir);
        printf(",");
    }
    printf("\"name\":");
    json_string(name);
    printf(",\"kind\":");
    json_string(kind_of(st.st_mode));
    printf(",\"class\":");
    json_string(cls);
    printf(",\"ext\":");
    json_string(ext);

    printf(",\"size\":%lld,\"mtime\":%lld,\"mode\":%u,\"link\":%s,\"broken\":%s,\"exec\":%s,\"hidden\":%s,\"read\":%s,\"write\":%s,\"root\":%s,\"mine\":%s,\"world\":%s",
           (long long)st.st_size, (long long)st.st_mtime,
           (unsigned)(st.st_mode & 07777),
           link ? "true" : "false",
           broken ? "true" : "false",
           exec ? "true" : "false",
           name[0] == '.' ? "true" : "false",
           faccessat(fd, name, R_OK, 0) == 0 ? "true" : "false",
           faccessat(fd, name, W_OK, 0) == 0 ? "true" : "false",
           st.st_uid == 0 ? "true" : "false",
           st.st_uid == getuid() ? "true" : "false",
           (st.st_mode & S_IWOTH) ? "true" : "false");

    if (S_ISDIR(st.st_mode))
        printf(",\"open\":%s", faccessat(fd, name, R_OK | X_OK, 0) == 0 ? "true" : "false");

    printf("}");
    return 1;
}

static void list(const char *path) {
    int fd = open(path, O_RDONLY | O_DIRECTORY);
    DIR *dir = fd >= 0 ? fdopendir(fd) : NULL;
    if (!dir) {
        printf("{\"path\":");
        json_string(path);
        printf(",\"ok\":false,\"error\":");
        json_string(strerror(errno));
        printf("}\n");
        if (fd >= 0)
            close(fd);
        return;
    }

    printf("{\"path\":");
    json_string(path);
    printf(",\"ok\":true,\"entries\":[");

    struct dirent *e;
    int first = 1;
    while ((e = readdir(dir))) {
        if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0)
            continue;

        if (print_entry(fd, e->d_name, NULL, first))
            first = 0;
    }

    printf("]}\n");
    closedir(dir);
}

static int sniffs_text(const char *path, long long *bytes) {
    int fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOCTTY);
    if (fd < 0)
        return 0;

    struct stat opened;
    if (fstat(fd, &opened) != 0 || !S_ISREG(opened.st_mode)) {
        close(fd);
        return 0;
    }

    unsigned char buf[SNIFF];
    size_t n = 0;
    while (n < sizeof buf) {
        ssize_t got = read(fd, buf + n, sizeof buf - n);
        if (got > 0) {
            n += (size_t)got;
            continue;
        }
        if (got < 0 && errno == EINTR)
            continue;
        break;
    }
    close(fd);
    *bytes = (long long)n;
    if (n == 0)
        return 1;

    size_t odd = 0;
    for (size_t i = 0; i < n; i++) {
        if (buf[i] == 0)
            return 0;
        if (buf[i] < 0x20 && buf[i] != '\t' && buf[i] != '\n' && buf[i] != '\r' && buf[i] != '\f' && buf[i] != 0x1b)
            odd++;
    }
    return odd * 100 < n * 5;
}

static void stat_one(const char *path) {
    struct stat ls;
    if (lstat(path, &ls) != 0) {
        printf("{\"path\":");
        json_string(path);
        printf(",\"ok\":false,\"error\":");
        json_string(strerror(errno));
        printf("}\n");
        return;
    }

    struct stat st = ls;
    int link = S_ISLNK(ls.st_mode);
    int broken = link && stat(path, &st) != 0;
    if (broken)
        st = ls;

    const char *slash = strrchr(path, '/');
    const char *name = slash ? slash + 1 : path;

    char ext[32];
    extension(name, ext, sizeof ext);
    const char *cls = S_ISDIR(st.st_mode) ? "directory" : class_of(ext);
    int exec = !S_ISDIR(st.st_mode) && (st.st_mode & (S_IXUSR | S_IXGRP | S_IXOTH));
    if (exec && strcmp(cls, "unknown") == 0)
        cls = "program";

    long long sniffed = 0;
    int text = S_ISREG(st.st_mode) && !broken && sniffs_text(path, &sniffed);

    if (text && (strcmp(cls, "unknown") == 0 || strcmp(cls, "program") == 0))
        cls = "text";

    struct passwd *pw = getpwuid(st.st_uid);
    struct group *gr = getgrgid(st.st_gid);

    printf("{\"path\":");
    json_string(path);
    printf(",\"ok\":true,\"name\":");
    json_string(name);
    printf(",\"kind\":");
    json_string(kind_of(st.st_mode));
    printf(",\"class\":");
    json_string(cls);
    printf(",\"ext\":");
    json_string(ext);
    printf(",\"owner\":");
    json_string(pw ? pw->pw_name : "");
    printf(",\"group\":");
    json_string(gr ? gr->gr_name : "");
    printf(",\"size\":%lld,\"mtime\":%lld,\"mode\":%u,\"link\":%s,\"broken\":%s,\"exec\":%s,\"text\":%s,\"readable\":%s",
           (long long)st.st_size, (long long)st.st_mtime,
           (unsigned)(st.st_mode & 07777),
           link ? "true" : "false",
           broken ? "true" : "false",
           exec ? "true" : "false",
           text ? "true" : "false",
           access(path, R_OK) == 0 ? "true" : "false");

    if (link) {
        char target[4096];
        ssize_t n = readlink(path, target, sizeof target - 1);
        if (n >= 0) {
            target[n] = '\0';
            printf(",\"target\":");
            json_string(target);
        }
    }

    printf("}\n");
}

struct search {
    const char *query;
    int hidden;
    int deep;
    long limit;
    long found;
    long scanned;
    int capped;
    char **names;
    int nnames;
    char **paths;
    int npaths;
};

struct queue {
    char **items;
    size_t head;
    size_t tail;
    size_t cap;
};

static void push(struct queue *q, char *path) {
    if (q->head > 0 && q->head * 2 >= q->tail) {
        memmove(q->items, q->items + q->head, (q->tail - q->head) * sizeof *q->items);
        q->tail -= q->head;
        q->head = 0;
    }
    if (q->tail == q->cap) {
        q->cap = q->cap ? q->cap * 2 : 256;
        q->items = realloc(q->items, q->cap * sizeof *q->items);
        if (!q->items)
            exit(1);
    }
    q->items[q->tail++] = path;
}

static int skipped(const struct search *s, const char *name, const char *path) {
    if (s->deep)
        return 0;
    for (int i = 0; i < s->nnames; i++)
        if (strcmp(s->names[i], name) == 0)
            return 1;
    for (int i = 0; i < s->npaths; i++)
        if (strcmp(s->paths[i], path) == 0)
            return 1;
    return 0;
}

static char *joined(const char *dir, const char *name) {
    size_t a = strlen(dir), b = strlen(name);
    int slash = a > 0 && dir[a - 1] == '/';
    char *out = malloc(a + b + 2);
    if (!out)
        exit(1);
    memcpy(out, dir, a);
    if (!slash)
        out[a++] = '/';
    memcpy(out + a, name, b + 1);
    return out;
}

static void progress(const struct search *s) {
    printf("{\"scanned\":%ld,\"found\":%ld}\n", s->scanned, s->found);
    fflush(stdout);
}

static void walk(struct search *s, const char *root, const struct stat *avoid) {
    struct stat top;
    if (s->capped || stat(root, &top) != 0 || !S_ISDIR(top.st_mode))
        return;

    struct queue q = {0};
    push(&q, strdup(root));

    while (q.head < q.tail && !s->capped) {
        char *path = q.items[q.head++];
        int fd = open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        struct stat here;
        DIR *dir = NULL;
        if (fd >= 0 && fstat(fd, &here) == 0 && (s->deep || here.st_dev == top.st_dev) &&
            !(avoid && here.st_dev == avoid->st_dev && here.st_ino == avoid->st_ino))
            dir = fdopendir(fd);
        if (!dir) {
            if (fd >= 0)
                close(fd);
            free(path);
            continue;
        }

        if (++s->scanned % 500 == 0)
            progress(s);

        struct dirent *e;
        while ((e = readdir(dir)) && !s->capped) {
            const char *name = e->d_name;
            if (strcmp(name, ".") == 0 || strcmp(name, "..") == 0)
                continue;
            if (!s->hidden && name[0] == '.')
                continue;

            unsigned char type = e->d_type;
            if (type == DT_UNKNOWN) {
                struct stat ls;
                if (fstatat(fd, name, &ls, AT_SYMLINK_NOFOLLOW) != 0)
                    continue;
                type = S_ISDIR(ls.st_mode) ? DT_DIR : DT_REG;
            }

            if (strcasestr(name, s->query) && print_entry(fd, name, path, 1)) {
                putchar('\n');
                fflush(stdout);
                if (++s->found >= s->limit)
                    s->capped = 1;
            }

            if (type != DT_DIR)
                continue;
            char *child = joined(path, name);
            if (skipped(s, name, child))
                free(child);
            else
                push(&q, child);
        }

        closedir(dir);
        free(path);
    }

    while (q.head < q.tail)
        free(q.items[q.head++]);
    free(q.items);
}

static int inside(const char *path, const char *root) {
    size_t n = strlen(root);
    if (n == 1)
        return path[1] != '\0';
    return strncmp(path, root, n) == 0 && path[n] == '/';
}

static int find(int argc, char **argv) {
    struct search s = {0};
    s.limit = 1000;
    s.names = calloc((size_t)argc, sizeof *s.names);
    s.paths = calloc((size_t)argc, sizeof *s.paths);
    const char *query = NULL, *home = NULL, *first = NULL;

    for (int i = 2; i < argc; i++) {
        const char *a = argv[i];
        int more = i + 1 < argc;
        if (strcmp(a, "--hidden") == 0)
            s.hidden = 1;
        else if (strcmp(a, "--deep") == 0)
            s.deep = 1;
        else if (strcmp(a, "--limit") == 0 && more)
            s.limit = strtol(argv[++i], NULL, 10);
        else if (strcmp(a, "--first") == 0 && more)
            first = argv[++i];
        else if (strcmp(a, "--skip") == 0 && more)
            s.names[s.nnames++] = argv[++i];
        else if (strcmp(a, "--skip-path") == 0 && more)
            s.paths[s.npaths++] = argv[++i];
        else if (strcmp(a, "--") == 0 && i + 2 < argc) {
            query = argv[i + 1];
            home = argv[i + 2];
            break;
        } else {
            fprintf(stderr, "bs-ls: unknown --find argument: %s\n", a);
            return 2;
        }
    }
    if (!query || !*query || !home) {
        fprintf(stderr, "usage: bs-ls --find [options] -- <query> <home>\n");
        return 2;
    }
    if (s.limit < 1)
        s.limit = 1;
    s.query = query;

    char *realhome = realpath(home, NULL);
    char *realfirst = first ? realpath(first, NULL) : NULL;
    if (!realhome) {
        fprintf(stderr, "bs-ls: cannot search %s: %s\n", home, strerror(errno));
        return 1;
    }
    struct stat avoid;
    int nearer = realfirst && inside(realfirst, realhome) && stat(first, &avoid) == 0;

    if (nearer)
        walk(&s, first, NULL);
    walk(&s, home, nearer ? &avoid : NULL);

    printf("{\"done\":true,\"scanned\":%ld,\"found\":%ld,\"capped\":%s}\n", s.scanned, s.found, s.capped ? "true" : "false");
    fflush(stdout);
    free(realhome);
    free(realfirst);
    return 0;
}

static long long now_ms(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (long long)t.tv_sec * 1000 + t.tv_nsec / 1000000;
}

static int watch(const char *path) {
    int fd = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    uint32_t mask = IN_CREATE | IN_DELETE | IN_MOVED_FROM | IN_MOVED_TO | IN_CLOSE_WRITE | IN_ATTRIB |
                    IN_DELETE_SELF | IN_MOVE_SELF | IN_ONLYDIR | IN_EXCL_UNLINK;
    if (fd < 0 || inotify_add_watch(fd, path, mask) < 0) {
        fprintf(stderr, "bs-ls: cannot watch %s: %s\n", path, strerror(errno));
        return 1;
    }
    printf("ready\n");
    fflush(stdout);

    char buf[64 * 1024] __attribute__((aligned(__alignof__(struct inotify_event))));
    long long first = 0, last = 0;
    int gone = 0;

    for (;;) {
        int timeout = -1;
        if (first) {
            long long due = last + QUIET_MS < first + BURST_MS ? last + QUIET_MS : first + BURST_MS;
            long long left = due - now_ms();
            timeout = left > 0 ? (int)left : 0;
        }

        struct pollfd fds[2] = {{fd, POLLIN, 0}, {STDIN_FILENO, POLLIN, 0}};
        if (poll(fds, 2, timeout) < 0) {
            if (errno == EINTR)
                continue;
            return 1;
        }
        if (fds[1].revents)
            return 0;

        if (fds[0].revents & POLLIN) {
            ssize_t got;
            while ((got = read(fd, buf, sizeof buf)) > 0)
                for (char *p = buf; p < buf + got;) {
                    const struct inotify_event *event = (const struct inotify_event *)p;
                    if (event->mask & (IN_DELETE_SELF | IN_MOVE_SELF | IN_IGNORED))
                        gone = 1;
                    p += sizeof *event + event->len;
                }
            last = now_ms();
            if (!first)
                first = last;
        }

        if (first && (now_ms() >= last + QUIET_MS || now_ms() >= first + BURST_MS)) {
            printf("changed\n");
            fflush(stdout);
            first = 0;
            if (gone)
                return 0;
        } else if (first) {
            struct timespec pause = {0, BATCH_MS * 1000000L};
            nanosleep(&pause, NULL);
        }
    }
}

int main(int argc, char **argv) {
    if (argc >= 2 && strcmp(argv[1], "--find") == 0)
        return find(argc, argv);
    if (argc == 3 && strcmp(argv[1], "--stat") == 0) {
        stat_one(argv[2]);
        return 0;
    }
    if (argc == 3 && strcmp(argv[1], "--watch") == 0)
        return watch(argv[2]);
    if (argc == 2) {
        list(argv[1]);
        return 0;
    }

    fprintf(stderr, "usage: bs-ls <dir> | bs-ls --stat <path> | bs-ls --watch <dir> | bs-ls --find [options] -- <query> <home>\n");
    return 2;
}
