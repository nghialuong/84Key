//
//  Settings.h
//  84Key — the Linux settings file.
//
//  $XDG_CONFIG_HOME/84key/settings.ini (normally ~/.config/84key/settings.ini),
//  shared by the IBus engine and the settings window (ibus-setup-84key). The
//  keys are the engine option names the macOS app stores in UserDefaults, so a
//  setting means the same thing on both platforms:
//
//    [84Key]
//    vInputType=0
//    vAutoDetectEnglish=1
//    ...
//    SwitchKey=Control+Shift
//
//  A key that is missing keeps its default (EngineGlobals.cpp), so a new option
//  that defaults ON is ON for existing users too — the reason the macOS app
//  registers its defaults rather than storing them.
//

#ifndef KEY84_SETTINGS_H
#define KEY84_SETTINGS_H

#include <string>
#include <vector>

namespace key84 {

struct Option {
    const char* key;
    int* value;
    int defaultValue;
};

class Settings {
public:
    static const char* const kGroup;
    static const char* const kDefaultSwitchKey;

    Settings();

    static std::string configDir();

    // A full set of settings: one value per options() entry, in that order.
    struct Values {
        std::vector<int> options;
        std::string switchKey;
        bool operator==(const Values& o) const { return options == o.options && switchKey == o.switchKey; }
        bool operator!=(const Values& o) const { return !(*this == o); }
    };

    // What is in effect now.
    Values current() const;
    // Put `values` into effect (the engine option globals and the switch key).
    void apply(const Values& values);

    // Read the file at startup and put it into effect. A missing file or key is
    // a default; a file that cannot be parsed leaves the defaults in effect.
    void load();
    // The file changed on disk: true, with `updated`, when it says something
    // new. Only the keys that differ from what the file said before are taken,
    // so a value changed in memory since then (VI/EN, by the per-app memory) is
    // not undone by an edit to something else. False for a file that cannot be
    // parsed — a half-finished hand edit must not reset every option.
    bool takeFileChanges(Values& updated);
    // Write the current engine option globals and the switch key, keeping any
    // keys this version does not know. Refuses to overwrite a file that exists
    // but cannot be parsed, rather than throw away the user's edit.
    bool save();

    const std::string& path() const { return path_; }
    const std::string& switchKey() const { return switchKey_; }
    void setSwitchKey(const std::string& key) { switchKey_ = key; }

    static std::vector<Option>& options();
    static Option* find(const std::string& key);

    // The per-app VI/EN memory (core/engine/SmartSwitchKey), kept in its own
    // file because it changes on every switch.
    void loadAppLanguages() const;
    void saveAppLanguages() const;

private:
    // The file over the defaults; false if it exists but cannot be parsed.
    bool read(Values& values) const;

    std::string path_;
    std::string switchKey_;
    Values onDisk_;   // what the file said when last read or written
};

} // namespace key84

#endif // KEY84_SETTINGS_H
