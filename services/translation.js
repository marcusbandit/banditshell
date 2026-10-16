.pragma library

var LANGUAGES = [
    ["af", "Afrikaans", "afrikaans"],
    ["sq", "Albanian", "shqip"],
    ["am", "Amharic", "አማርኛ"],
    ["ar", "Arabic", "العربية", "عربي"],
    ["hy", "Armenian", "հայերեն"],
    ["as", "Assamese", "অসমীয়া"],
    ["az", "Azerbaijani", "azərbaycan", "azerbaycan"],
    ["eu", "Basque", "euskara"],
    ["be", "Belarusian", "беларуская"],
    ["bn", "Bengali", "বাংলা", "bangla"],
    ["bs", "Bosnian", "bosanski"],
    ["bg", "Bulgarian", "български"],
    ["my", "Burmese", "မြန်မာ", "myanmar"],
    ["ca", "Catalan", "català", "catala"],
    ["ny", "Chichewa", "chichewa"],
    ["zh-CN", "Chinese", "中文", "简体中文", "mandarin", "simplified chinese", "chinese simplified"],
    ["zh-TW", "Traditional Chinese", "繁體中文", "chinese traditional"],
    ["co", "Corsican", "corsu"],
    ["hr", "Croatian", "hrvatski"],
    ["cs", "Czech", "čeština", "cestina"],
    ["da", "Danish", "dansk"],
    ["nl", "Dutch", "nederlands", "flemish", "vlaams"],
    ["en", "English", "english"],
    ["eo", "Esperanto", "esperanto"],
    ["et", "Estonian", "eesti"],
    ["tl", "Filipino", "filipino", "tagalog"],
    ["fi", "Finnish", "suomi"],
    ["fr", "French", "français", "francais"],
    ["fy", "Frisian", "frysk"],
    ["gl", "Galician", "galego"],
    ["ka", "Georgian", "ქართული"],
    ["de", "German", "deutsch"],
    ["el", "Greek", "ελληνικά", "ελληνικα"],
    ["gu", "Gujarati", "ગુજરાતી"],
    ["ht", "Haitian Creole", "kreyòl ayisyen", "kreyol"],
    ["ha", "Hausa", "hausa"],
    ["haw", "Hawaiian", "ʻōlelo hawaiʻi"],
    ["iw", "Hebrew", "עברית"],
    ["hi", "Hindi", "हिन्दी", "हिंदी"],
    ["hu", "Hungarian", "magyar"],
    ["is", "Icelandic", "íslenska", "islenska"],
    ["ig", "Igbo", "igbo"],
    ["id", "Indonesian", "bahasa indonesia"],
    ["ga", "Irish", "gaeilge"],
    ["it", "Italian", "italiano"],
    ["ja", "Japanese", "日本語", "nihongo"],
    ["jw", "Javanese", "basa jawa"],
    ["kn", "Kannada", "ಕನ್ನಡ"],
    ["kk", "Kazakh", "қазақ"],
    ["km", "Khmer", "ខ្មែរ"],
    ["rw", "Kinyarwanda", "kinyarwanda"],
    ["ko", "Korean", "한국어"],
    ["ku", "Kurdish", "kurdî", "kurdi"],
    ["ky", "Kyrgyz", "кыргызча"],
    ["lo", "Lao", "ລາວ"],
    ["la", "Latin", "latina"],
    ["lv", "Latvian", "latviešu", "latviesu"],
    ["lt", "Lithuanian", "lietuvių", "lietuviu"],
    ["lb", "Luxembourgish", "lëtzebuergesch"],
    ["mk", "Macedonian", "македонски"],
    ["mg", "Malagasy", "malagasy"],
    ["ms", "Malay", "bahasa melayu"],
    ["ml", "Malayalam", "മലയാളം"],
    ["mt", "Maltese", "malti"],
    ["mi", "Maori", "māori"],
    ["mr", "Marathi", "मराठी"],
    ["mn", "Mongolian", "монгол"],
    ["ne", "Nepali", "नेपाली"],
    ["no", "Norwegian", "norsk", "bokmål", "bokmal"],
    ["or", "Odia", "ଓଡ଼ିଆ", "oriya"],
    ["ps", "Pashto", "پښتو"],
    ["fa", "Persian", "فارسی", "farsi"],
    ["pl", "Polish", "polski"],
    ["pt", "Portuguese", "português", "portugues", "brazilian"],
    ["pa", "Punjabi", "ਪੰਜਾਬੀ"],
    ["ro", "Romanian", "română", "romana"],
    ["ru", "Russian", "русский"],
    ["sm", "Samoan", "samoa"],
    ["gd", "Scottish Gaelic", "gàidhlig", "gaelic"],
    ["sr", "Serbian", "српски", "srpski"],
    ["st", "Sesotho", "sesotho"],
    ["sn", "Shona", "chishona"],
    ["sd", "Sindhi", "سنڌي"],
    ["si", "Sinhala", "සිංහල"],
    ["sk", "Slovak", "slovenčina", "slovencina"],
    ["sl", "Slovenian", "slovenščina", "slovenscina", "slovene"],
    ["so", "Somali", "soomaali"],
    ["es", "Spanish", "español", "espanol", "castilian"],
    ["su", "Sundanese", "basa sunda"],
    ["sw", "Swahili", "kiswahili"],
    ["sv", "Swedish", "svenska"],
    ["tg", "Tajik", "тоҷикӣ"],
    ["ta", "Tamil", "தமிழ்"],
    ["tt", "Tatar", "татар"],
    ["te", "Telugu", "తెలుగు"],
    ["th", "Thai", "ไทย"],
    ["tr", "Turkish", "türkçe", "turkce"],
    ["tk", "Turkmen", "türkmen"],
    ["uk", "Ukrainian", "українська"],
    ["ur", "Urdu", "اردو"],
    ["ug", "Uyghur", "ئۇيغۇرچە"],
    ["uz", "Uzbek", "oʻzbek", "ozbek"],
    ["vi", "Vietnamese", "tiếng việt", "tieng viet"],
    ["cy", "Welsh", "cymraeg"],
    ["xh", "Xhosa", "isixhosa"],
    ["yi", "Yiddish", "ייִדיש"],
    ["yo", "Yoruba", "yorùbá"],
    ["zu", "Zulu", "isizulu"]
];

var CODE_ALIASES = {
    he: "iw",
    jv: "jw",
    zh: "zh-CN",
    "zh-hans": "zh-CN",
    "zh-hant": "zh-TW",
    nb: "no",
    nn: "no",
    fil: "tl"
};

var BY_NAME = {};
var BY_CODE = {};

LANGUAGES.forEach(function (entry) {
    BY_CODE[entry[0].toLowerCase()] = entry;
    BY_NAME[entry[1].toLowerCase()] = entry;
    for (var i = 2; i < entry.length; i++)
        BY_NAME[entry[i].toLowerCase()] = entry;
});

var CONNECTORS = ["to", "into", "in"];
var LEAD = /^(?:translate|tr)\s+(.+)$/i;
var ASKING = /^(?:how (?:do (?:you|i)|to) say|what(?:'s| is))\s+/i;
var ENDING = /\s*[?!.]+$/;
var LONGEST_NAME = 3;
var GAPS = /\s+/;
var NUMERIC = /^[\d\s.,:+\-*/%]+$/;
var CODE_PARTS = /[-_]/;
var LOCALE_PARTS = /[_.@]/;

function codeOf(code) {
    var c = String(code || "").toLowerCase();
    var entry = BY_CODE[CODE_ALIASES[c] ? CODE_ALIASES[c].toLowerCase() : c] || BY_CODE[c.split(CODE_PARTS)[0]];
    return entry ? entry[0] : "";
}

function byName(name) {
    var entry = BY_NAME[String(name || "").trim().toLowerCase()];
    return entry ? entry[0] : "";
}

function languageCode(word) {
    return byName(word) || codeOf(word);
}

function languageName(code) {
    var c = codeOf(code);
    return c ? BY_CODE[c.toLowerCase()][1] : "";
}

function splitTarget(text, codesToo) {
    var words = text.split(GAPS);
    for (var k = 1; k <= LONGEST_NAME && k < words.length - 1; k++) {
        var link = words[words.length - k - 1].toLowerCase();
        if (CONNECTORS.indexOf(link) < 0)
            continue;
        var said = words.slice(words.length - k).join(" ");
        var code = byName(said) || (codesToo && k === 1 ? codeOf(said) : "");
        if (code)
            return {
                text: words.slice(0, words.length - k - 1).join(" "),
                to: code
            };
    }
    return null;
}

function ask(input) {
    var text = String(input || "").trim().replace(ENDING, "");
    if (!text)
        return null;
    var lead = LEAD.exec(text);
    if (lead) {
        var rest = lead[1].trim();
        var target = splitTarget(rest, true);
        if (target && target.text)
            return {
                text: target.text,
                to: target.to,
                explicit: true
            };
        return {
            text: rest,
            to: "",
            explicit: false
        };
    }
    var plain = splitTarget(text.replace(ASKING, ""), false);
    if (!plain || !plain.text || NUMERIC.test(plain.text))
        return null;
    return {
        text: plain.text,
        to: plain.to,
        explicit: true
    };
}

function keyOf(text, to) {
    return to + "|" + text;
}

function splitKey(key) {
    var cut = String(key).indexOf("|");
    return {
        to: key.slice(0, cut),
        text: key.slice(cut + 1)
    };
}

function readAnswer(raw) {
    var text = String(raw || "").trim();
    if (!text)
        return null;
    if (text.charAt(0) !== "[")
        return text.charAt(0) === "<" ? null : {
            text: text,
            from: ""
        };
    var data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return null;
    }
    if (!Array.isArray(data) || !data.length)
        return null;
    if (Array.isArray(data[0]) && Array.isArray(data[0][0])) {
        var joined = data[0].map(function (part) {
            return part && typeof part[0] === "string" ? part[0] : "";
        }).join("");
        return joined ? {
            text: joined,
            from: typeof data[2] === "string" ? data[2] : ""
        } : null;
    }
    if (Array.isArray(data[0])) {
        var parts = data.filter(function (part) {
            return Array.isArray(part) && typeof part[0] === "string";
        });
        return parts.length ? {
            text: parts.map(function (part) {
                return part[0];
            }).join(" "),
            from: typeof parts[0][1] === "string" ? parts[0][1] : ""
        } : null;
    }
    if (typeof data[0] === "string")
        return {
            text: data.join(" "),
            from: ""
        };
    return null;
}

function pageUrl(text, to) {
    return "https://translate.google.com/?sl=auto&tl=" + encodeURIComponent(to) + "&text=" + encodeURIComponent(text) + "&op=translate";
}

function localeCode(locale) {
    return codeOf(String(locale || "").split(LOCALE_PARTS)[0]);
}
