//
//  Settings.cpp
//  84Key — the Linux settings file. See Settings.h.
//

#include "Settings.h"

#include <glib.h>
#include <glib/gstdio.h>

#include "Engine.h"

namespace key84 {

const char* const Settings::kGroup = "84Key";
const char* const Settings::kDefaultSwitchKey = "Control+Shift";

namespace {

constexpr const char* kSwitchKey = "SwitchKey";
constexpr const char* kAppsFile = "apps.dat";

// The defaults, captured from EngineGlobals.cpp before any file is applied.
std::vector<Option> buildOptions() {
    std::vector<Option> list = {
        {"vLanguage", &vLanguage, 0},
        {"vInputType", &vInputType, 0},
        {"vCodeTable", &vCodeTable, 0},
        {"vFreeMark", &vFreeMark, 0},
        {"vCheckSpelling", &vCheckSpelling, 0},
        {"vUseModernOrthography", &vUseModernOrthography, 0},
        {"vQuickTelex", &vQuickTelex, 0},
        {"vRestoreIfWrongSpelling", &vRestoreIfWrongSpelling, 0},
        {"vUseSmartSwitchKey", &vUseSmartSwitchKey, 0},
        {"vUpperCaseFirstChar", &vUpperCaseFirstChar, 0},
        {"vAllowConsonantZFWJ", &vAllowConsonantZFWJ, 0},
        {"vQuickStartConsonant", &vQuickStartConsonant, 0},
        {"vQuickEndConsonant", &vQuickEndConsonant, 0},
        {"vAutoDetectEnglish", &vAutoDetectEnglish, 0},
    };
    for (Option& o : list)
        o.defaultValue = *o.value;
    return list;
}

int clampOption(const char* key, int value) {
    if (g_str_equal(key, "vInputType")) return CLAMP(value, 0, 3);
    if (g_str_equal(key, "vCodeTable")) return CLAMP(value, 0, 4);
    return value ? 1 : 0;
}

} // namespace

std::vector<Option>& Settings::options() {
    static std::vector<Option> list = buildOptions();
    return list;
}

Option* Settings::find(const std::string& key) {
    for (Option& o : options())
        if (key == o.key)
            return &o;
    return nullptr;
}

std::string Settings::configDir() {
    gchar* dir = g_build_filename(g_get_user_config_dir(), "84key", nullptr);
    std::string result(dir);
    g_free(dir);
    return result;
}

Settings::Settings() : switchKey_(kDefaultSwitchKey) {
    gchar* file = g_build_filename(configDir().c_str(), "settings.ini", nullptr);
    path_ = file;
    g_free(file);
    options();   // capture the defaults before anything is loaded
}

bool Settings::read(Values& values) const {
    values.options.clear();
    for (const Option& o : options())
        values.options.push_back(o.defaultValue);
    values.switchKey = kDefaultSwitchKey;

    GKeyFile* kf = g_key_file_new();
    GError* error = nullptr;
    if (!g_key_file_load_from_file(kf, path_.c_str(), G_KEY_FILE_KEEP_COMMENTS, &error)) {
        const bool missing = g_error_matches(error, G_FILE_ERROR, G_FILE_ERROR_NOENT);
        if (!missing)
            g_warning("84Key: cannot read %s: %s", path_.c_str(), error->message);
        g_clear_error(&error);
        g_key_file_unref(kf);
        return missing;   // no file: all defaults
    }
    for (size_t i = 0; i < options().size(); i++) {
        const char* key = options()[i].key;
        const int value = g_key_file_get_integer(kf, kGroup, key, &error);
        if (error)
            g_clear_error(&error);   // absent or not a number: keep the default
        else
            values.options[i] = clampOption(key, value);
    }
    if (gchar* key = g_key_file_get_string(kf, kGroup, kSwitchKey, nullptr)) {
        values.switchKey = key;
        g_free(key);
    }
    g_key_file_unref(kf);
    return true;
}

void Settings::load() {
    Values values;
    read(values);   // on a parse error `values` holds the defaults
    apply(values);
    onDisk_ = values;
}

bool Settings::takeFileChanges(Values& updated) {
    Values file;
    if (!read(file) || file == onDisk_)
        return false;
    updated = current();
    for (size_t i = 0; i < file.options.size(); i++)
        if (i >= onDisk_.options.size() || file.options[i] != onDisk_.options[i])
            updated.options[i] = file.options[i];
    if (file.switchKey != onDisk_.switchKey)
        updated.switchKey = file.switchKey;
    onDisk_ = file;
    return true;
}

Settings::Values Settings::current() const {
    Values values;
    for (const Option& o : options())
        values.options.push_back(*o.value);
    values.switchKey = switchKey_;
    return values;
}

void Settings::apply(const Values& values) {
    for (size_t i = 0; i < options().size() && i < values.options.size(); i++)
        *options()[i].value = values.options[i];
    switchKey_ = values.switchKey;
    // The engine restores spell checking from this after a temporary toggle.
    vSetCheckSpelling();
}

bool Settings::save() {
    g_mkdir_with_parents(configDir().c_str(), 0700);
    GKeyFile* kf = g_key_file_new();
    // Start from what is on disk, so keys this version does not know survive —
    // and leave a file we cannot parse alone: it is someone's edit in progress.
    GError* error = nullptr;
    if (!g_key_file_load_from_file(kf, path_.c_str(), G_KEY_FILE_KEEP_COMMENTS, &error) &&
        !g_error_matches(error, G_FILE_ERROR, G_FILE_ERROR_NOENT)) {
        g_warning("84Key: not saving: %s cannot be parsed (%s)", path_.c_str(), error->message);
        g_clear_error(&error);
        g_key_file_unref(kf);
        return false;
    }
    g_clear_error(&error);
    for (const Option& o : options())
        g_key_file_set_integer(kf, kGroup, o.key, *o.value);
    g_key_file_set_string(kf, kGroup, kSwitchKey, switchKey_.c_str());

    // g_key_file_save_to_file writes a temporary file and renames it over the
    // old one, so a reader never sees half a file.
    const bool ok = g_key_file_save_to_file(kf, path_.c_str(), &error);
    if (ok) {
        onDisk_ = current();
    } else {
        g_warning("84Key: cannot write %s: %s", path_.c_str(), error->message);
        g_clear_error(&error);
    }
    g_key_file_unref(kf);
    return ok;
}

void Settings::loadAppLanguages() const {
    gchar* file = g_build_filename(configDir().c_str(), kAppsFile, nullptr);
    gchar* data = nullptr;
    gsize size = 0;
    if (g_file_get_contents(file, &data, &size, nullptr)) {
        initSmartSwitchKey((const Byte*)data, (int)size);
        g_free(data);
    }
    g_free(file);
}

void Settings::saveAppLanguages() const {
    std::vector<Byte> data;
    getSmartSwitchKeySaveData(data);
    g_mkdir_with_parents(configDir().c_str(), 0700);
    gchar* file = g_build_filename(configDir().c_str(), kAppsFile, nullptr);
    GError* error = nullptr;
    if (!g_file_set_contents(file, (const gchar*)data.data(), (gssize)data.size(), &error)) {
        g_warning("84Key: cannot write %s: %s", file, error->message);
        g_clear_error(&error);
    }
    g_free(file);
}

} // namespace key84
