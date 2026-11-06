#!/usr/bin/env python3
"""
rebuild-categories.py
Regenerates the emoji category data files with:
1. Official Unicode CLDR French annotations (100% coverage)
2. The official Emojilib English database
3. Official French country names for the flags
4. Accented and unaccented variants for every French word
5. Each tab lists its own emojis FIRST (category view when unfiltered),
   followed by all emojis of every other category (unified global search from any tab).
"""

import os, json, re, unicodedata, urllib.request

SOURCE_JSON    = os.environ.get("EMOJI_SOURCE_JSON", "/usr/share/noctalia/assets/emoji.json")
CATEGORIES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "emoji-categories")

URL_CLDR_BASE    = "https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json/cldr-annotations-full/annotations/fr/annotations.json"
URL_CLDR_DERIVED = "https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json/cldr-annotations-derived-full/annotationsDerived/fr/annotations.json"
URL_CLDR_TERR    = "https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json/cldr-localenames-full/main/fr/territories.json"
URL_EMOJILIB     = "https://raw.githubusercontent.com/muan/emojilib/main/dist/emoji-en-US.json"

def strip_accents(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')

def clean_tokens(text):
    words = re.findall(r'[a-zA-Z0-9\u00C0-\u017F]+', text.lower())
    res = []
    for w in words:
        if len(w) > 1:
            res.append(w)
            unaccented = strip_accents(w)
            if unaccented != w and len(unaccented) > 1:
                res.append(unaccented)
    return res

def flag_to_code(flag):
    codes = [chr(ord(c) - 0x1F1E6 + ord('A')) for c in flag if 0x1F1E6 <= ord(c) <= 0x1F1FF]
    return ''.join(codes)

def fetch_json(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read())

def main():
    print("Chargement de /usr/share/noctalia/assets/emoji.json...", flush=True)
    with open(SOURCE_JSON, encoding="utf-8") as f:
        noctalia = json.load(f)
    print(f"  {len(noctalia)} émojis dans Noctalia", flush=True)

    print("Téléchargement des annotations CLDR officielles en français...", flush=True)
    cldr = fetch_json(URL_CLDR_BASE)['annotations']['annotations']
    cldr.update(fetch_json(URL_CLDR_DERIVED)['annotationsDerived']['annotations'])
    cldr_norm = {k.replace('\uFE0F', ''): v for k, v in cldr.items()}

    print("Téléchargement des noms de pays CLDR pour les drapeaux...", flush=True)
    territories = fetch_json(URL_CLDR_TERR)['main']['fr']['localeDisplayNames']['territories']

    print("Téléchargement d'Emojilib (anglais)...", flush=True)
    emojilib = fetch_json(URL_EMOJILIB)

    # Metadata dictionary for each emoji
    emoji_records = []
    for e in noctalia:
        ch = e.get("emoji")
        if not ch:
            continue
        name = e.get("name", "")
        cat = e.get("category", "objects")

        tokens = set()

        # 1. Noctalia English name
        for t in clean_tokens(name):
            tokens.add(t)

        # 2. Category
        tokens.add(cat.lower())

        # 3. Emojilib (English)
        for kw in emojilib.get(ch, []):
            for t in clean_tokens(kw.replace('_', ' ')):
                tokens.add(t)

        # 4. CLDR French
        cldr_entry = cldr.get(ch) or cldr_norm.get(ch.replace('\uFE0F', ''))
        if cldr_entry:
            for fr_kw in cldr_entry.get('default', []):
                for t in clean_tokens(fr_kw):
                    tokens.add(t)

        # 5. Flags: French country name + "drapeau"/"flag"
        if cat == "flags":
            tokens.add("drapeau")
            tokens.add("flag")
            code = flag_to_code(ch)
            country_fr = territories.get(code)
            if country_fr:
                for t in clean_tokens(country_fr):
                    tokens.add(t)

        # Extra synonyms / common French words
        extra_fr = {
            "🚗": ["voiture", "auto", "bagnole"],
            "🚙": ["voiture", "suv", "auto"],
            "🏎️": ["voiture", "formule1", "f1", "course"],
            "⛪": ["eglise", "eglises", "cathedrale"],
            "🕌": ["mosquee", "mosquees"],
            "🐱": ["chat", "chaton", "minou"],
            "🐈": ["chat", "felin"],
            "🐶": ["chien", "toutou"],
            "🐕": ["chien"],
            "❤️": ["coeur", "amour", "love"],
            "💔": ["coeur", "brise"],
            "💖": ["coeur"],
            "💕": ["coeurs", "coeur"],
        }
        for ex in extra_fr.get(ch, []):
            tokens.add(ex)
            tokens.add(strip_accents(ex))

        meta_str = " ".join(sorted(tokens))
        emoji_records.append({
            "emoji": ch,
            "category": cat,
            "line": f"{ch}\x00meta\x1f{meta_str}\n"
        })

    os.makedirs(CATEGORIES_DIR, exist_ok=True)

    # Ordered list of all categories
    categories = ["people", "animals", "nature", "food", "activity", "travel", "objects", "symbols", "flags"]

    for cat in categories:
        out_path = os.path.join(CATEGORIES_DIR, f"{cat}.txt")
        # This category's emojis first
        primary = [e["line"] for e in emoji_records if e["category"] == cat]
        # All other emojis second, for unified global search
        secondary = [e["line"] for e in emoji_records if e["category"] != cat]

        with open(out_path, "wb") as f:
            for l in primary:
                f.write(l.encode("utf-8"))
            for l in secondary:
                f.write(l.encode("utf-8"))

        print(f"  {cat:10s}: {len(primary):3d} primaires + {len(secondary):4d} secondaires -> {out_path}", flush=True)

    print("\nTerminé avec succès !", flush=True)

if __name__ == "__main__":
    main()
