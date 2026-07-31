//
//  EnglishDetect.cpp
//  OpenKey
//

#include "EnglishDetect.h"

#include <vector>
#include <algorithm>

using namespace std;

static vector<string> _engDict;       // sorted, unique
static vector<string> _vietDict;      // sorted, unique (Telex spellings)

// Parse a raw byte buffer into a sorted/unique lowercase word list.
// Tokens are split on any non a-z/A-Z byte; uppercase is folded to lowercase.
static void buildDict(const Byte* pData, const int& size, vector<string>& out) {
    out.clear();
    if (pData == NULL || size <= 0)
        return;
    string cur;
    cur.reserve(32);
    for (int i = 0; i <= size; i++) {
        char c = (i < size) ? (char)pData[i] : '\n'; // force flush of last token
        if (c >= 'A' && c <= 'Z')
            c = (char)(c - 'A' + 'a');
        if (c >= 'a' && c <= 'z') {
            cur.push_back(c);
        } else {
            if (!cur.empty()) {
                out.push_back(cur);
                cur.clear();
            }
        }
    }
    sort(out.begin(), out.end());
    out.erase(unique(out.begin(), out.end()), out.end());
}

void initEnglishDict(const Byte* pData, const int& size) {
    buildDict(pData, size, _engDict);
}

void initVietByTelexDict(const Byte* pData, const int& size) {
    buildDict(pData, size, _vietDict);
}

bool isEnglishDictReady(void) {
    return !_engDict.empty();
}

static bool dictContains(const vector<string>& dict, const string& w) {
    return binary_search(dict.begin(), dict.end(), w);
}

// True if some entry has `w` as a strict prefix (longer than w).
static bool dictHasLongerPrefix(const vector<string>& dict, const string& w) {
    if (w.empty())
        return false;
    vector<string>::const_iterator it = lower_bound(dict.begin(), dict.end(), w);
    for (; it != dict.end(); ++it) {
        if (it->size() < w.size() || it->compare(0, w.size(), w) != 0)
            break; // no longer entries start with w
        if (it->size() > w.size())
            return true;
    }
    return false;
}

// True if some entry has `w` as a prefix (including an exact match).
static bool dictHasPrefix(const vector<string>& dict, const string& w) {
    if (w.empty())
        return false;
    vector<string>::const_iterator it = lower_bound(dict.begin(), dict.end(), w);
    return it != dict.end() && it->size() >= w.size() && it->compare(0, w.size(), w) == 0;
}

bool isEnglishWord(const string& word) {
    return dictContains(_engDict, word);
}

bool isEnglishPrefix(const string& word) {
    return dictHasLongerPrefix(_engDict, word);
}

bool isVietByTelex(const string& word) {
    return dictContains(_vietDict, word);
}

bool isVietByTelexPrefix(const string& word) {
    return dictHasPrefix(_vietDict, word);
}

// Compound splitting. A piece shorter than this makes the split meaningless
// (two-letter English fragments match a large part of the Vietnamese Telex
// dictionary); more than 3 pieces buys no real word but widens the surface.
static const size_t kMinPiece = 3;
static const size_t kMaxParts = 3;
static const size_t kMaxLen = 32;   // MAX_BUFF: the longest word the engine keeps

// dp[pos][parts]: word[0..pos) is exactly `parts` complete English words.
// O(n^2) over n <= 32, each cell a binary_search over the word list.
static bool compoundSplit(const string& w, const bool& allowLastPrefix) {
    const size_t n = w.size();
    if (n < kMinPiece * 2 || n > kMaxLen)
        return false;

    bool dp[kMaxLen + 1][kMaxParts + 1];
    for (size_t p = 0; p <= n; p++)
        for (size_t k = 0; k <= kMaxParts; k++)
            dp[p][k] = false;
    dp[0][0] = true;

    for (size_t pos = 0; pos < n; pos++) {
        for (size_t parts = 0; parts < kMaxParts; parts++) {
            if (!dp[pos][parts])
                continue;
            for (size_t end = pos + kMinPiece; end <= n; end++) {
                string piece = w.substr(pos, end - pos);
                if (isEnglishWord(piece)) {
                    if (end == n && parts + 1 >= 2)
                        return true;    // 2..kMaxParts complete words
                    dp[end][parts + 1] = true;
                }
                //the trailing piece may still be unfinished, but only after at
                //least one complete word has been matched
                if (allowLastPrefix && end == n && parts >= 1 && isEnglishPrefix(piece))
                    return true;
            }
        }
    }
    return false;
}

bool isEnglishCompound(const string& word) {
    return compoundSplit(word, false);
}

bool isEnglishCompoundPrefix(const string& word) {
    return compoundSplit(word, true);
}
