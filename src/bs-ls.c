// One directory, as JSON, for a QML file browser that cannot call stat().
//
// QML can read a file (FileView) and run a process (Process), and that is the
// whole of its access to a filesystem: there is no readdir, no stat, no way to
// ask whether a thing is a directory. `ls` almost answers it and is the wrong
// tool anyway - its output is for a person, its columns move under -l, and
// nothing it prints survives a filename with a newline in it.
//
// So the shape of the answer is decided here, once, and it is JSON because that
// is the one format the far end can parse with no parser at all.
//
// WHAT THIS DOES NOT DO IS SNIFF. A class comes off the extension, plus the
// executable bit, and nothing here opens a file to look inside it: a directory
// of forty thousand entries would be forty thousand opens to decide which icon
// to draw, and the icon is a guess either way. --stat is where sniffing lives,
// because that is one file, chosen deliberately, and the question there is
// "should the preview panel try to show this as text", which the extension
// genuinely cannot answer.
#define _GNU_SOURCE

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

// How much of a file to look at before deciding it is text. A page: enough for
// any BOM, any shebang, any header magic, and enough of a body that a binary
// with a text-looking header still gives itself away.
#define SNIFF 4096

struct classing {
    const char *ext;
    const char *cls;
};

// The classes are the browser's own vocabulary, not MIME's: they are what
// decides an icon and a colour, so "an image" is one thing whether it arrived as
// a PNG or a camera raw. Ordered by nothing; looked up linearly, over a list
// this size, once per entry.
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

// The extension, lowercased, or "" when there is none. A leading dot is a hidden
// file rather than an extension: ".zshrc" has no type, it has a name.
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

// A JSON string, from bytes that are not promised to be anything.
//
// A filename is a bag of bytes: the kernel forbids '/' and NUL and permits every
// other arrangement, including sequences that are not UTF-8. JSON is defined
// over text, and JSON.parse on the far end throws on the first invalid byte -
// which would mean one undecodable name in a directory taking the whole listing
// down. So invalid sequences are replaced, not passed through, and the file is
// still shown under a name with a replacement character in it, which is exactly
// what every other file manager does.
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

        // How long this sequence claims to be, and whether it delivers.
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

        struct stat ls;
        if (fstatat(fd, e->d_name, &ls, AT_SYMLINK_NOFOLLOW) != 0)
            continue;

        // A LINK IS SHOWN AS WHAT IT POINTS AT, and says that it is a link.
        // Anything else means a symlinked folder does not open and a symlinked
        // picture draws no thumbnail, which is not what the link is for.
        struct stat st = ls;
        int link = S_ISLNK(ls.st_mode);
        int broken = 0;
        if (link && fstatat(fd, e->d_name, &st, 0) != 0) {
            broken = 1;
            st = ls;
        }

        char ext[32];
        extension(e->d_name, ext, sizeof ext);
        const char *cls = S_ISDIR(st.st_mode) ? "directory" : class_of(ext);
        int exec = !S_ISDIR(st.st_mode) && (st.st_mode & (S_IXUSR | S_IXGRP | S_IXOTH));
        // An executable with nothing else to say about it is a PROGRAM, which
        // is worth its own mark. An executable .sh is still a script.
        if (exec && strcmp(cls, "unknown") == 0)
            cls = "program";

        printf(first ? "" : ",");
        first = 0;

        printf("{\"name\":");
        json_string(e->d_name);
        printf(",\"kind\":");
        json_string(kind_of(st.st_mode));
        printf(",\"class\":");
        json_string(cls);
        printf(",\"ext\":");
        json_string(ext);
        printf(",\"size\":%lld,\"mtime\":%lld,\"mode\":%u,\"link\":%s,\"broken\":%s,\"exec\":%s,\"hidden\":%s",
               (long long)st.st_size, (long long)st.st_mtime,
               (unsigned)(st.st_mode & 07777),
               link ? "true" : "false",
               broken ? "true" : "false",
               exec ? "true" : "false",
               e->d_name[0] == '.' ? "true" : "false");

        // WHETHER YOU CAN GO IN, asked only of directories and only because the
        // answer changes what the tile draws. Everything else about permission
        // is in `mode` for whoever wants to render it.
        if (S_ISDIR(st.st_mode))
            printf(",\"open\":%s", faccessat(fd, e->d_name, R_OK | X_OK, 0) == 0 ? "true" : "false");

        printf("}");
    }

    printf("]}\n");
    closedir(dir);
}

// IS THIS TEXT? The one question a preview panel has to get right, and the one
// the extension cannot answer: the files worth previewing most are the ones
// with no extension at all (README, Makefile, a dotfile, a script).
//
// A NUL is the tell. No text encoding this shell will meet puts one in a
// document, and every binary format has them early. Beyond that, count the bytes
// that are neither printable nor ordinary whitespace: a few is a file with a
// stray control character, a lot is a binary that happened to start with words.
static int sniffs_text(const char *path, long long *bytes) {
    FILE *f = fopen(path, "rb");
    if (!f)
        return 0;

    unsigned char buf[SNIFF];
    size_t n = fread(buf, 1, sizeof buf, f);
    fclose(f);
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
    int text = !S_ISDIR(st.st_mode) && !broken && sniffs_text(path, &sniffed);
    // Only the classes that were a guess get overruled. A .png that sniffs as
    // text is a broken .png, not a text file, and calling it one would put
    // mojibake in the preview panel instead of a broken-image mark.
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

int main(int argc, char **argv) {
    if (argc == 3 && strcmp(argv[1], "--stat") == 0) {
        stat_one(argv[2]);
        return 0;
    }
    if (argc == 2) {
        list(argv[1]);
        return 0;
    }

    fprintf(stderr, "usage: bs-ls <dir> | bs-ls --stat <path>\n");
    return 2;
}
