#!/usr/bin/env python3
"""Generate the dictionary data files for 84Key's automatic English detection.

Two outputs (newline-separated, sorted, unique, lowercase a-z), both keyed by
the *raw Telex keystrokes* a user would type:

  core/data/english_words.dat  - common English words (google-10000-english)
  core/data/viet_telex.dat     - Telex spellings of valid Vietnamese syllables

The Vietnamese dictionary is generated **from linguistic rules** (a curated
inventory of Vietnamese onsets, rhymes/vần and the six tones), NOT from any
external/scraped Vietnamese word list, so the data stays licence-clean
(see NOTICE). Over-generation is acceptable and even desirable: a larger
Vietnamese set only makes the detector favour Vietnamese more often, which is
the safe direction. The one exception is a small, documented blocklist of
over-generated non-words whose Telex spelling collides with common English
words (e.g. "guns" -> gún); those are removed so genuine English words are not
mistaken for Vietnamese.

The English list is the public-domain / MIT `google-10000-english` word list,
reused as-is (filtered to >=2 ascii letters). Provide the raw list path to
regenerate it; otherwise the committed english_words.dat is kept.

Usage (run from repo root):
  python3 tools/gen_dict.py                       # regenerate VN, keep EN
  python3 tools/gen_dict.py --english /path/to/google-10000-english.txt
"""
import argparse
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.normpath(os.path.join(HERE, "..", "core", "data"))

# --- Telex spelling of the Vietnamese letters with diacritic marks -----------
#   â=aa  ê=ee  ô=oo  ơ=ow  ư=uw  ă=aw  đ=dd
# Tone keys appended last: sắc=s huyền=f hỏi=r ngã=x nặng=j (ngang=none).
TONES = ["", "s", "f", "r", "x", "j"]
STOP_CODAS = ("p", "t", "c", "ch")  # only sắc/nặng allowed on a stop coda

# Rhymes (vần) written in their Telex spelling, grouped by nucleus. This is the
# curated linguistic table the Vietnamese syllabary is built from. "front" means
# the main vowel is e/ê/i, which selects the k / gh / ngh spelling of a velar
# onset; everything else takes c / g / ng. u-glide rhymes (uy, uê, uâ, uơ, uyê)
# take the "qu" spelling of a velar onset.
RHYMES_BACK = [
    # a
    "a", "ac", "ach", "ai", "am", "an", "ang", "anh", "ao", "ap", "at", "au", "ay",
    # ă (aw)
    "awc", "awm", "awn", "awng", "awp", "awt",
    # â (aa)
    "aac", "aam", "aan", "aang", "aap", "aat", "aau", "aay",
    # o
    "o", "oc", "oi", "om", "on", "ong", "op", "ot",
    # ô (oo)
    "oo", "ooc", "ooi", "oom", "oon", "oong", "oop", "oot",
    # ơ (ow)
    "ow", "owi", "owm", "own", "owp", "owt",
    # u
    "u", "uc", "ui", "um", "un", "ung", "up", "ut",
    # ư (uw)
    "uw", "uwa", "uwc", "uwi", "uwng", "uwt", "uwu",
    # uô (uoo)
    "uoo", "uooc", "uooi", "uoom", "uoon", "uoong", "uoot",
    # ươ (uwow)
    "uwow", "uwowc", "uwowi", "uwowm", "uwown", "uwowng", "uwowp", "uwowt", "uwowu",
    # ua / oa / oă / oe
    "ua",
    "oa", "oac", "oach", "oai", "oam", "oan", "oang", "oanh", "oao", "oap", "oat", "oay",
    "oawc", "oawn", "oawng", "oawt",
    "oe", "oeo", "oen", "oet",
    # long-o loanword rhymes (xoong, soóc) - distinct from ô handled above
]
RHYMES_FRONT = [
    # e
    "e", "ec", "em", "en", "eng", "eo", "ep", "et",
    # ê (ee)
    "ee", "eech", "eem", "een", "eenh", "eep", "eet", "eeu",
    # i / y
    "i", "ia", "ich", "im", "in", "inh", "ip", "it", "iu",
    "y",
    # iê (iee) and yê (yee)
    "ieec", "ieem", "ieen", "ieeng", "ieep", "ieet", "ieeu",
    "yeem", "yeen", "yeeng", "yeet", "yeeu",
]
RHYMES_UGLIDE = [  # take "qu" form of a velar onset; non-velar onsets attach directly
    "ua", "uan", "uang", "uat", "uay", "uaan", "uaang", "uaat", "uaay",
    "uee", "ueech", "ueen", "ueenh", "uet",
    "uy", "uya", "uyn", "uynh", "uyt", "uych", "uyu", "uyeen", "uyeet",
    "uow",
]

# Onsets (âm đầu) in Telex. Velar/uvular onsets are spelled by following vowel.
# Native Vietnamese has no bare "p" initial (only "ph", and "p" as a final coda),
# so it is intentionally omitted: generating pa/pe/pi... would wrongly mark the
# detector's Vietnamese set and let English words like "password" be diacriticized.
ONSET_NONVELAR = ["", "b", "ch", "d", "dd", "gi", "h", "kh", "l", "m",
                  "n", "nh", "ph", "r", "s", "t", "th", "tr", "v", "x"]

# Documented blocklist: over-generated syllables (onset+rhyme+tone Telex spellings)
# that are NOT real Vietnamese words but collide with common English words, so the
# detector would otherwise treat the English word as Vietnamese. Keep minimal.
BLOCKLIST = {
    # g + "un" is not a Vietnamese syllable; collides with English "gun"/"guns".
    "gun", "guns", "gunf", "gunr", "gunx", "gunj",
}


def velar_for(rhyme_group, sound):
    """Return the Telex onset spelling for a velar /k/, /g/, /ng/ sound given the
    rhyme group, or None if that velar does not occur there."""
    if rhyme_group == "front":
        return {"k": "k", "g": "gh", "ng": "ngh"}[sound]
    if rhyme_group == "back":
        return {"k": "c", "g": "g", "ng": "ng"}[sound]
    return None  # u-glide handled via "qu" separately


# Trailing finals (coda consonants + offglides), longest first. Telex lets the
# tone key be typed either right after the vowel or after the final, so we emit
# both spellings — otherwise the after-vowel form (e.g. "barn" for bản) would not
# be recognised as Vietnamese and could collide with an English word ("barn").
FINALS = ("nh", "ng", "ch", "c", "m", "n", "p", "t", "i", "o", "u", "y")


def split_final(rhyme):
    for f in FINALS:
        if rhyme.endswith(f) and len(rhyme) > len(f):
            return rhyme[:-len(f)], f
    return rhyme, ""


def _emit(out, word):
    if word and word.isascii() and word.isalpha() and word not in BLOCKLIST:
        out.add(word)


def add_syllable(out, onset, rhyme):
    base = onset + rhyme
    vowel, final = split_final(rhyme)
    stop = rhyme.endswith(STOP_CODAS)
    for tone in TONES:
        if tone == "":
            if not stop:           # a bare stop-coda syllable needs sắc/nặng
                _emit(out, base)
            continue
        if stop and tone not in ("s", "j"):
            continue               # stop codas (p/t/c/ch) only carry sắc or nặng
        _emit(out, base + tone)                      # tone after the final
        if final:
            _emit(out, onset + vowel + tone + final)  # tone right after the vowel


def gen_viet():
    out = set()
    # non-velar onsets attach to every rhyme group directly
    for onset in ONSET_NONVELAR:
        for rhyme in RHYMES_BACK + RHYMES_FRONT:
            add_syllable(out, onset, rhyme)
        for rhyme in RHYMES_UGLIDE:
            add_syllable(out, onset, rhyme)
    # velar onsets: spelling depends on the rhyme group
    for group, rhymes in (("back", RHYMES_BACK), ("front", RHYMES_FRONT)):
        for sound in ("k", "g", "ng"):
            onset = velar_for(group, sound)
            for rhyme in rhymes:
                add_syllable(out, onset, rhyme)
    # u-glide rhymes with a velar /k/ are written "qu" + (rhyme without leading u)
    for rhyme in RHYMES_UGLIDE:
        if rhyme.startswith("u"):
            add_syllable(out, "q", rhyme)  # q + u... = "qu..."
    # The "gi" onset can stand with just a tone (gì, gí, gị, gĩ, gỉ, gi): the vowel
    # i is absorbed into the onset, so it isn't produced by onset×rhyme above.
    for tone in TONES:
        _emit(out, "gi" + tone)
    return out


def gen_english(src):
    words = set()
    with open(src, encoding="utf-8", errors="ignore") as f:
        for line in f:
            w = line.strip().lower()
            if len(w) >= 2 and w.isascii() and w.isalpha():
                words.add(w)
    return words


def write(path, words):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="ascii") as f:
        f.write("\n".join(sorted(words)) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--english", help="path to raw google-10000-english word list")
    ap.add_argument("--report-collisions", action="store_true",
                    help="print Vietnamese syllables that collide with English words")
    args = ap.parse_args()

    viet = gen_viet()
    write(os.path.join(DATA, "viet_telex.dat"), viet)
    print(f"viet_telex.dat:    {len(viet)} syllables")

    eng_path = os.path.join(DATA, "english_words.dat")
    if args.english:
        eng = gen_english(args.english)
        write(eng_path, eng)
        print(f"english_words.dat: {len(eng)} words (regenerated)")
    elif os.path.exists(eng_path):
        with open(eng_path, encoding="ascii") as f:
            eng = {l.strip() for l in f if l.strip()}
        print(f"english_words.dat: {len(eng)} words (kept)")
    else:
        eng = set()
        print("english_words.dat: MISSING (pass --english to generate)")

    if args.report_collisions and eng:
        collide = sorted(viet & eng)
        print(f"\n{len(collide)} VN/EN collisions:")
        print(" ".join(collide))


if __name__ == "__main__":
    main()
