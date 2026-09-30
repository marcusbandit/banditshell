#ifndef BS_B64_H
#define BS_B64_H

#include <stddef.h>
#include <stdlib.h>

static const char bs_b64_alphabet[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static void bs_b64_encode(const unsigned char *in, size_t len, char *out) {
    size_t i = 0, o = 0;
    for (; i + 2 < len; i += 3) {
        unsigned v = (unsigned)in[i] << 16 | (unsigned)in[i + 1] << 8 | in[i + 2];
        out[o++] = bs_b64_alphabet[v >> 18 & 63];
        out[o++] = bs_b64_alphabet[v >> 12 & 63];
        out[o++] = bs_b64_alphabet[v >> 6 & 63];
        out[o++] = bs_b64_alphabet[v & 63];
    }
    if (i < len) {
        unsigned v = (unsigned)in[i] << 16 | (i + 1 < len ? (unsigned)in[i + 1] << 8 : 0);
        out[o++] = bs_b64_alphabet[v >> 18 & 63];
        out[o++] = bs_b64_alphabet[v >> 12 & 63];
        out[o++] = i + 1 < len ? bs_b64_alphabet[v >> 6 & 63] : '=';
        out[o++] = '=';
    }
    out[o] = '\0';
}

static size_t bs_b64_decode(const char *in, unsigned char *out) {
    static signed char table[256];
    static int built = 0;
    if (!built) {
        for (int i = 0; i < 256; i++)
            table[i] = -1;
        for (int i = 0; i < 64; i++)
            table[(unsigned char)bs_b64_alphabet[i]] = (signed char)i;
        built = 1;
    }

    size_t o = 0;
    unsigned acc = 0;
    int bits = 0;
    for (const char *p = in; *p; p++) {
        signed char v = table[(unsigned char)*p];
        if (v < 0)
            continue;
        acc = acc << 6 | (unsigned)v;
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            out[o++] = (unsigned char)(acc >> bits & 0xff);
        }
    }
    return o;
}

#endif
