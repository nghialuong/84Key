//
//  EnglishDetect.h
//  OpenKey
//
//  Lightweight English-vs-Vietnamese word detection used to skip diacritics
//  when an English word is being typed in Vietnamese (Telex) mode.
//
//  Both dictionaries are keyed by the *raw keystroke string* (lowercase a-z):
//   - English dictionary: common English words.
//   - Vietnamese dictionary: the Telex spelling of valid Vietnamese words
//     (e.g. "cu3"-style is NOT used; Telex "cur" -> "củ").
//  This lets the engine compare what was typed against both sets directly,
//  without having to materialise the toned output.
//

#ifndef EnglishDetect_h
#define EnglishDetect_h

#include <string>
#include "DataType.h"

/**
 * Load the English word list from a memory buffer (tokens separated by any
 * non-letter byte, e.g. newlines). Safe to call again to replace the data.
 */
void initEnglishDict(const Byte* pData, const int& size);

/**
 * Load the Vietnamese word list (Telex spellings) from a memory buffer.
 */
void initVietByTelexDict(const Byte* pData, const int& size);

/**
 * True once the English dictionary has at least one entry.
 */
bool isEnglishDictReady(void);

/**
 * Exact match: `word` is a complete English word.
 */
bool isEnglishWord(const std::string& word);

/**
 * `word` is a strict prefix of some longer English word (word itself excluded).
 */
bool isEnglishPrefix(const std::string& word);

/**
 * Exact match: `word` (raw Telex keystrokes) spells a valid Vietnamese word.
 */
bool isVietByTelex(const std::string& word);

/**
 * `word` is a prefix of some Vietnamese Telex spelling (word itself included).
 */
bool isVietByTelexPrefix(const std::string& word);

/**
 * `word` splits into 2..3 English words, each at least 3 letters long
 * (e.g. "dashboard" = "dash"+"board", "imagegen" = "image"+"gen").
 *
 * The dictionary only holds simple words, so a compound the user typed as one
 * token would otherwise look like neither an English word nor an English
 * prefix, and the Telex transform keys inside it would eat letters
 * ("dashboard" -> "dáhboard"). The 3-letter floor is what keeps this safe for
 * Vietnamese: at 2 letters, 27% of the Vietnamese Telex spellings split into
 * English pieces; at 3, only 43 of 29644 do — and every one of those is itself
 * in the Vietnamese dictionary, so the caller's isVietByTelex() guard already
 * covers them.
 */
bool isEnglishCompound(const std::string& word);

/**
 * As isEnglishCompound(), but the LAST piece only has to be an English prefix
 * (still at least 3 letters), so a compound is recognised while it is still
 * being typed ("dashboar" = "dash" + start of "board"). At least one complete
 * English word must precede that prefix.
 */
bool isEnglishCompoundPrefix(const std::string& word);

#endif /* EnglishDetect_h */
