#!/usr/bin/env python3
import argparse
import os
import sys
import tempfile
import unicodedata
import urllib.request
import xml.etree.ElementTree as ElementTree

SOURCES = {
    "emoji-test.txt": "https://unicode.org/Public/emoji/latest/emoji-test.txt",
    "annotations.xml": "https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotations/en.xml",
    "derived.xml": "https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotationsDerived/en.xml",
}

GROUPS = ["Smileys", "People", "Animals", "Food", "Travel", "Activities", "Objects", "Symbols", "Flags", "Arrows", "Maths", "Currency", "Typography", "Fractions", "Greek", "Keys", "Marks"]

EMOJI_GROUPS = {
    "Smileys & Emotion": "Smileys",
    "People & Body": "People",
    "Animals & Nature": "Animals",
    "Food & Drink": "Food",
    "Travel & Places": "Travel",
    "Activities": "Activities",
    "Objects": "Objects",
    "Symbols": "Symbols",
    "Flags": "Flags",
}

TONES = [0x1F3FB, 0x1F3FC, 0x1F3FD, 0x1F3FE, 0x1F3FF]
TONE_NAMES = ["light skin tone", "medium-light skin tone", "medium skin tone", "medium-dark skin tone", "dark skin tone"]
PRESENTATION = 0xFE0F
FORBIDDEN = {chr(0x2013): "-", chr(0x2014): "-"}


def spans(*ranges):
    out = []
    for item in ranges:
        if isinstance(item, tuple):
            out.extend(range(item[0], item[1] + 1))
        else:
            out.append(item)
    return out


SYMBOLS = {
    "Arrows": spans((0x2190, 0x2199), 0x21A9, 0x21AA, (0x21B0, 0x21B3), 0x21BA, 0x21BB, (0x21C4, 0x21C6), 0x21CB, 0x21CC, (0x21D0, 0x21D5), 0x21E6, 0x21E8, 0x21E9, (0x27F5, 0x27FA)),
    "Maths": spans(0x00B1, 0x00D7, 0x00F7, 0x2212, 0x2213, 0x2260, 0x2248, 0x2261, 0x2264, 0x2265, 0x226A, 0x226B, 0x221E, 0x221A, 0x221B, 0x2211, 0x220F, 0x222B, 0x222E, 0x2202, 0x2206, 0x2207, 0x2208, 0x2209, 0x220B, 0x2229, 0x222A, 0x2282, 0x2283, 0x2286, 0x2287, 0x2200, 0x2203, 0x2204, 0x00AC, 0x2227, 0x2228, 0x2295, 0x2297, 0x2205, 0x221D, 0x2220, 0x22A5, 0x2225, 0x2245, 0x223C, 0x2234, 0x2235, 0x2218, 0x22C5, 0x00B7, 0x2032, 0x2033, 0x2030, 0x00B0, 0x00B5, 0x211D, 0x2115, 0x2124, 0x211A, 0x2102, 0x2135, 0x230A, 0x230B, 0x2308, 0x2309, 0x27E8, 0x27E9, 0x220E, 0x00B9, 0x00B2, 0x00B3, 0x2070, (0x2074, 0x2079), 0x207F, 0x207A, 0x207B, (0x2080, 0x2089)),
    "Currency": spans(0x20AC, 0x00A3, 0x00A5, 0x00A2, 0x20B9, 0x20BF, 0x20BD, 0x20A9, 0x20BA, 0x20B4, 0x20AA, 0x20AB, 0x20B1, 0x20A6, 0x20B5, 0x20A1, 0x20B2, 0x20AD, 0x20AE, 0x0E3F, 0x20B8, 0x20BC, 0x20BE, 0x20A3, 0x20A4, 0x20A8, 0x00A4),
    "Typography": spans(0x00A9, 0x00AE, 0x2122, 0x2120, 0x00A7, 0x00B6, 0x2020, 0x2021, 0x2026, 0x2022, 0x2023, 0x00AB, 0x00BB, 0x2039, 0x203A, 0x201C, 0x201D, 0x2018, 0x2019, 0x201E, 0x201A, 0x00A1, 0x00BF, 0x203D, 0x2116, 0x2103, 0x2109, 0x2113, 0x212E, 0x2042, 0x203B, 0x00A6, 0x00B4),
    "Fractions": spans(0x00BD, 0x2153, 0x2154, 0x00BC, 0x00BE, (0x2155, 0x215A), 0x2150, (0x215B, 0x215E), 0x2151, 0x2152, 0x2189, 0x2044),
    "Greek": spans((0x03B1, 0x03C9), (0x0391, 0x03A1), (0x03A3, 0x03A9), 0x03D1, 0x03D5, 0x03D6, 0x03F5),
    "Keys": spans(0x2318, 0x2325, 0x21E7, 0x2303, 0x238B, 0x23CE, 0x232B, 0x2326, 0x21E5, 0x21E4, 0x2423, 0x21EA),
    "Marks": spans(0x2713, 0x2717, 0x2718, 0x2605, 0x2606, 0x2665, 0x2661, 0x2660, 0x2663, 0x2666, 0x2664, 0x2667, 0x2662, 0x266A, 0x266B, 0x2610, 0x2611, 0x2612, 0x25CF, 0x25CB, 0x25A0, 0x25A1, 0x25B2, 0x25BC, 0x25C6, 0x25C7),
}

EXTRA = {
    "°": "deg degrees temperature",
    "™": "tm trademark",
    "©": "c copyright (c)",
    "®": "r registered (r)",
    "€": "euro eur",
    "£": "pound gbp sterling",
    "¥": "yen yuan jpy cny",
    "¢": "cent cents",
    "₹": "rupee inr",
    "₿": "bitcoin btc",
    "₽": "ruble rub",
    "₩": "won krw",
    "±": "plus minus +-",
    "×": "times multiply x",
    "÷": "divide division",
    "−": "minus",
    "≠": "not equal != =/=",
    "≈": "approx approximately about ~=",
    "≡": "identical equivalent ===",
    "≤": "less than or equal <=",
    "≥": "greater than or equal >=",
    "∞": "infinity inf",
    "√": "sqrt square root",
    "∑": "sum sigma",
    "∏": "product",
    "∫": "integral",
    "∂": "partial derivative",
    "∆": "delta increment change",
    "∇": "nabla del gradient",
    "∈": "in element of",
    "∀": "for all",
    "∃": "exists there exists",
    "∅": "empty set",
    "→": "right arrow to ->",
    "←": "left arrow <-",
    "↑": "up arrow",
    "↓": "down arrow",
    "↔": "left right arrow <->",
    "⇒": "implies =>",
    "⇐": "implied by <=",
    "⇔": "iff if and only if <=>",
    "⟶": "long right arrow -->",
    "⟵": "long left arrow <--",
    "…": "ellipsis dots ...",
    "•": "bullet",
    "·": "middle dot interpunct",
    "§": "section",
    "¶": "paragraph pilcrow",
    "†": "dagger",
    "‡": "double dagger",
    "“": "quote quotes smart quotes left double",
    "”": "quote quotes smart quotes right double",
    "‘": "quote single left",
    "’": "apostrophe single quote right",
    "«": "guillemet quotes",
    "»": "guillemet quotes",
    "‽": "interrobang",
    "℃": "celsius degrees c",
    "℉": "fahrenheit degrees f",
    "µ": "micro mu",
    "π": "pi",
    "Ω": "ohm omega",
    "⌘": "cmd command super",
    "⌥": "option alt",
    "⇧": "shift",
    "⌃": "control ctrl",
    "⏎": "return enter",
    "⌫": "backspace delete",
    "⌦": "delete forward",
    "⎋": "escape esc",
    "⇥": "tab",
    "⇤": "backtab shift tab",
    "␣": "space",
    "⇪": "caps lock",
    "✓": "check tick done yes",
    "✗": "cross x no",
    "✘": "cross x no",
    "★": "star",
    "☆": "star outline",
    "♥": "heart",
    "♡": "heart outline",
    "♪": "note music",
    "♫": "notes music",
    "²": "squared power two",
    "³": "cubed power three",
    "¹": "power one",
    "½": "half 1/2",
    "⅓": "third 1/3",
    "⅔": "two thirds 2/3",
    "¼": "quarter 1/4",
    "¾": "three quarters 3/4",
    "⅕": "fifth 1/5",
    "⅛": "eighth 1/8",
    "🙂": ":)",
    "🙁": ":(",
    "😀": ":D",
    "😉": ";)",
    "😛": ":P",
    "😢": ":'(",
    "😮": ":o",
    "😆": "xD",
    "❤️": "<3",
    "😘": ":*",
}

SHORTCODES = {
    "😄": "smile", "😃": "smiley", "😁": "grin", "😆": "laughing satisfied", "😅": "sweat_smile", "🤣": "rofl", "😂": "joy", "🙂": "slightly_smiling_face",
    "🙃": "upside_down_face", "😉": "wink", "😊": "blush", "😇": "innocent", "🥰": "smiling_face_with_three_hearts", "😍": "heart_eyes", "🤩": "star_struck",
    "😘": "kissing_heart", "😋": "yum", "😛": "stuck_out_tongue", "😜": "stuck_out_tongue_winking_eye", "🤪": "zany_face", "🤗": "hugs hug", "🤭": "hand_over_mouth",
    "🤫": "shushing_face shh", "🤔": "thinking hmm", "😐": "neutral_face", "😑": "expressionless", "😶": "no_mouth", "😏": "smirk", "😒": "unamused",
    "🙄": "roll_eyes eyeroll", "😬": "grimacing", "😌": "relieved", "😔": "pensive", "😴": "sleeping", "😷": "mask", "🤒": "face_with_thermometer",
    "🤢": "nauseated_face", "🤮": "vomiting_face", "🥵": "hot_face", "🥶": "cold_face", "🥴": "woozy_face", "🤯": "exploding_head mind blown", "🤠": "cowboy_hat_face",
    "🥳": "partying_face", "😎": "sunglasses cool", "🤓": "nerd_face", "😕": "confused", "😟": "worried", "🙁": "slightly_frowning_face", "😮": "open_mouth",
    "😲": "astonished", "😳": "flushed", "🥺": "pleading_face", "😦": "frowning", "😧": "anguished", "😨": "fearful", "😰": "cold_sweat", "😥": "disappointed_relieved",
    "😢": "cry", "😭": "sob", "😱": "scream", "😖": "confounded", "😣": "persevere", "😞": "disappointed", "😓": "sweat", "😩": "weary", "😫": "tired_face",
    "🥱": "yawning_face", "😤": "triumph", "😡": "rage pout", "😠": "angry", "🤬": "cursing_face", "😈": "smiling_imp", "💀": "skull dead", "💩": "poop hankey",
    "🤡": "clown_face", "👻": "ghost", "👽": "alien", "🤖": "robot", "🙈": "see_no_evil", "🙉": "hear_no_evil", "🙊": "speak_no_evil", "💯": "100",
    "💥": "boom collision", "💫": "dizzy", "💦": "sweat_drops", "💤": "zzz", "👋": "wave hi bye", "✋": "raised_hand hand", "👌": "ok_hand", "✌️": "v",
    "🤞": "crossed_fingers", "🤘": "metal", "👈": "point_left", "👉": "point_right", "👆": "point_up_2", "👇": "point_down", "👍": "thumbsup +1 like",
    "👎": "thumbsdown -1 dislike", "👊": "fist_oncoming punch", "👏": "clap", "🙌": "raised_hands hooray", "🤝": "handshake", "🙏": "pray thanks please",
    "💪": "muscle strong flex", "🧠": "brain", "👀": "eyes look", "🤷": "shrug", "🤦": "facepalm", "❤️": "heart", "💔": "broken_heart", "✨": "sparkles",
    "⭐": "star", "🔥": "fire lit", "⚡": "zap", "🌈": "rainbow", "☀️": "sunny", "❄️": "snowflake", "☕": "coffee", "🍺": "beer", "🍻": "beers cheers",
    "🍕": "pizza", "🎉": "tada", "🎊": "confetti_ball", "🎁": "gift present", "🎂": "birthday cake", "🎈": "balloon", "🏆": "trophy", "🚀": "rocket ship",
    "💡": "bulb idea", "🔒": "lock", "🔑": "key", "🔨": "hammer", "🔧": "wrench", "⚙️": "gear settings", "🔗": "link", "📌": "pushpin pin", "📝": "memo note",
    "📅": "date calendar", "📈": "chart_with_upwards_trend", "✅": "white_check_mark done", "❌": "x", "⚠️": "warning", "🐛": "bug", "💰": "moneybag",
    "👑": "crown", "🫡": "salute", "🫠": "melting_face",
}

TEXT_DEFAULT_SYMBOLS = {cp for group in SYMBOLS.values() for cp in group}


def fetch(folder):
    paths = {}
    for name, url in SOURCES.items():
        path = os.path.join(folder, name)
        print(f"fetching {url}", file=sys.stderr)
        with urllib.request.urlopen(url) as reply, open(path, "wb") as out:
            out.write(reply.read())
        paths[name] = path
    return paths


def clean(text):
    for bad, good in FORBIDDEN.items():
        text = text.replace(bad, good)
    return text.replace("|", " ").strip()


def clean_word(text):
    return " ".join(clean(text).replace(",", " ").split())


def read_annotations(*paths):
    names = {}
    words = {}
    for path in paths:
        for node in ElementTree.parse(path).getroot().iter("annotation"):
            point = node.get("cp")
            text = clean(node.text or "") if node.get("type") == "tts" else node.text or ""
            if node.get("type") == "tts":
                names.setdefault(point, text)
            else:
                words.setdefault(point, [clean_word(w) for w in text.split("|") if clean_word(w)])
    return names, words


def read_emoji(path, newest):
    entries = []
    toned = {}
    group = ""
    for line in open(path, encoding="utf8"):
        if line.startswith("# group:"):
            group = line.split(":", 1)[1].strip()
            continue
        if not line.strip() or line.startswith("#"):
            continue
        points, rest = line.split(";", 1)
        status, comment = rest.split("#", 1)
        if status.strip() != "fully-qualified" or group not in EMOJI_GROUPS:
            continue
        fields = comment.strip().split(" ", 2)
        version = float(fields[1].lstrip("E"))
        if version > newest:
            continue
        codes = [int(c, 16) for c in points.split()]
        name = fields[2]
        if any(c in TONES for c in codes):
            toned[name] = codes
            continue
        if len(codes) == 2 and codes[1] == PRESENTATION and codes[0] in TEXT_DEFAULT_SYMBOLS:
            continue
        entries.append({"codes": codes, "name": name, "group": EMOJI_GROUPS[group]})
    return entries, toned


def with_tone(codes, places, tone):
    out = []
    for i, code in enumerate(codes):
        if code == PRESENTATION and i - 1 in places:
            continue
        out.append(code)
        if i in places:
            out.append(tone)
    return out


def tone_places(entry, toned):
    variants = [toned.get(f"{entry['name']}: {tone}") for tone in TONE_NAMES]
    if not all(variants):
        return None
    codes = entry["codes"]
    first = variants[0]
    places = []
    i = 0
    for code in first:
        if code == TONES[0]:
            places.append(i - 1)
            if i < len(codes) and codes[i] == PRESENTATION:
                i += 1
            continue
        if i < len(codes) and codes[i] == code:
            i += 1
    if all(with_tone(codes, places, TONES[t]) == variants[t] for t in range(5)):
        return places
    return None


def keywords_for(char, name, words):
    have = set(name.lower().replace(":", " ").replace(",", " ").split())
    found = [":" + code for code in SHORTCODES.get(char, "").split(" ") if code] + EXTRA.get(char, "").split(" ") + words.get(char.replace(chr(PRESENTATION), ""), words.get(char, []))
    out = []
    for word in found:
        lowered = clean_word(word).lower()
        if not lowered or lowered == name.lower() or lowered in out:
            continue
        if " " not in lowered and lowered in have:
            continue
        out.append(lowered)
    return out[:10]


def symbol_name(code, names):
    char = chr(code)
    if char in names:
        return names[char]
    official = unicodedata.name(char, "").lower()
    if official.startswith("greek capital letter "):
        return "capital " + official[len("greek capital letter "):]
    if official.startswith("greek small letter "):
        return official[len("greek small letter "):]
    if official.startswith("greek ") and official.endswith(" symbol"):
        return official[len("greek "):]
    if official.startswith("vulgar fraction "):
        return official[len("vulgar fraction "):]
    return official


def symbol_words(code, words):
    char = chr(code)
    official = unicodedata.name(char, "").lower()
    out = list(words.get(char, []))
    if official.startswith("greek"):
        out.append("greek letter")
        out.append("uppercase" if "capital" in official else "lowercase")
    elif official.startswith("vulgar fraction"):
        out.append("fraction")
    elif official.startswith("superscript"):
        out.append("superscript")
    elif official.startswith("subscript"):
        out.append("subscript")
    return out


def build(paths, newest):
    names, words = read_annotations(paths["annotations.xml"], paths["derived.xml"])
    entries, toned = read_emoji(paths["emoji-test.txt"], newest)
    lines = []
    for entry in entries:
        char = "".join(chr(c) for c in entry["codes"])
        name = clean(entry["name"])
        places = tone_places(entry, toned)
        found = keywords_for(char, name, words)
        tone = ".".join(str(p) for p in places) if places else ""
        lines.append([char, name, ",".join(found), str(GROUPS.index(entry["group"])), tone])
    for group, codes in SYMBOLS.items():
        for code in codes:
            char = chr(code)
            name = clean(symbol_name(code, names))
            extended = dict(words)
            extended[char] = symbol_words(code, words)
            found = keywords_for(char, name, extended)
            lines.append([char, name, ",".join(found), str(GROUPS.index(group)), ""])
    return lines


def write(lines, path, version):
    with open(path, "w", encoding="utf8") as out:
        out.write(".pragma library\n\n")
        out.write(f"var VERSION = \"{version}\";\n\n")
        out.write("var GROUPS = [" + ", ".join(f"\"{g}\"" for g in GROUPS) + "];\n\n")
        out.write(f"var FIRST_SYMBOL_GROUP = {GROUPS.index('Arrows')};\n\n")
        out.write("var TABLE = [\n")
        out.write(",\n".join("\"" + "|".join(line).replace("\\", "\\\\").replace("\"", "\\\"") + "\"" for line in lines))
        out.write("\n];\n")


def main():
    parser = argparse.ArgumentParser(description="Build services/emoji-table.js from Unicode emoji-test.txt and CLDR English annotations.")
    parser.add_argument("--from", dest="folder", help="folder holding emoji-test.txt, annotations.xml and derived.xml; fetched when left out")
    parser.add_argument("--newest", type=float, default=16.0, help="leave out emoji newer than this Unicode emoji version, so older fonts still draw every row")
    parser.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "services", "emoji-table.js"))
    options = parser.parse_args()
    if options.folder:
        paths = {name: os.path.join(options.folder, name) for name in SOURCES}
        lines = build(paths, options.newest)
    else:
        with tempfile.TemporaryDirectory() as folder:
            lines = build(fetch(folder), options.newest)
    write(lines, options.out, f"{options.newest}")
    print(f"wrote {len(lines)} rows to {os.path.normpath(options.out)}", file=sys.stderr)


if __name__ == "__main__":
    main()
