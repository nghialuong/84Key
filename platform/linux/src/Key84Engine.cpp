//
//  Key84Engine.cpp
//  84Key — the IBus engine. See Key84Engine.h, and Composer.h for why the word
//  being typed lives in the preedit.
//
//  The engine core (core/engine) keeps one word in global state, so there is one
//  Host for the process; IBus creates an engine object per input context, and
//  only the focused one drives the Host. Focus changes reset the word.
//

#include "Key84Engine.h"

#include <string>

#include "Composer.h"
#include "Engine.h"
#include "EnglishDetect.h"
#include "Settings.h"
#include "SwitchKey.h"

#ifndef KEY84_SETUP_PATH
#define KEY84_SETUP_PATH "ibus-setup-84key"
#endif

struct _Key84Engine {
    IBusEngine parent;
    IBusPropList* props;
    std::string* client;      // the focused application, as IBus names it
    gboolean preeditVisible;
};

struct _Key84EngineClass {
    IBusEngineClass parent;
};

G_DEFINE_TYPE(Key84Engine, key84_engine, IBUS_TYPE_ENGINE)

namespace {

struct Host {
    key84::Composer composer;
    key84::Settings settings;
    key84::SwitchKeyMatcher switchKey;
    Key84Engine* focused = nullptr;
    GFileMonitor* monitor = nullptr;
    guint reloadSource = 0;
};

Host& host() {
    static Host* h = new Host();   // lives as long as the process
    return *h;
}

// Run the engine with KEY84_TRACE=1 to log every event and what was done with
// it (the counterpart of the macOS KEY84_TRACE) — for diagnosing live-app issues.
bool tracing() {
    static const bool on = g_getenv("KEY84_TRACE") != nullptr;
    return on;
}

#define TRACE(...) do { if (tracing()) g_message(__VA_ARGS__); } while (0)

std::string utf8(const std::u32string& text) {
    std::string out;
    for (char32_t c : text) {
        gchar buf[6];
        gint n = g_unichar_to_utf8((gunichar)c, buf);
        out.append(buf, (size_t)n);
    }
    return out;
}

// ---- Output ------------------------------------------------------------------

void showPreedit(Key84Engine* engine, const std::u32string& text) {
    IBusEngine* e = IBUS_ENGINE(engine);
    if (text.empty()) {
        if (!engine->preeditVisible)
            return;
        ibus_engine_update_preedit_text_with_mode(e, ibus_text_new_from_static_string(""), 0, FALSE,
                                                  IBUS_ENGINE_PREEDIT_COMMIT);
        engine->preeditVisible = FALSE;
        return;
    }
    const std::string s = utf8(text);
    IBusText* t = ibus_text_new_from_string(s.c_str());
    const guint len = (guint)g_utf8_strlen(s.c_str(), -1);
    ibus_text_append_attribute(t, IBUS_ATTR_TYPE_UNDERLINE, IBUS_ATTR_UNDERLINE_SINGLE, 0, len);
    // COMMIT mode: if the user clicks away or focus moves mid-word, IBus commits
    // what is shown instead of dropping it — and the engine must not commit it
    // a second time from reset()/focus_out(), which is how other engines end up
    // typing a word twice.
    ibus_engine_update_preedit_text_with_mode(e, t, len, TRUE, IBUS_ENGINE_PREEDIT_COMMIT);
    engine->preeditVisible = TRUE;
}

void emit(Key84Engine* engine, const key84::Output& out) {
    if (!out.commit.empty()) {
        // Take the word out of the preedit before committing it, so the client
        // never shows it twice for a moment.
        showPreedit(engine, std::u32string());
        ibus_engine_commit_text(IBUS_ENGINE(engine), ibus_text_new_from_string(utf8(out.commit).c_str()));
    }
    if (out.preeditChanged)
        showPreedit(engine, out.preedit);
}

// The input context changed under the word: IBus has committed the visible
// preedit itself (COMMIT mode), so only our side is reset.
void forgetWord(Key84Engine* engine) {
    host().composer.reset();
    host().switchKey.cancel();   // Ctrl+Shift held through a click is not a switch
    engine->preeditVisible = FALSE;
}

// ---- Properties: the input-source menu ----------------------------------------
//
// GNOME Shell lists these under the keyboard indicator and shows the symbol of
// the "InputMode" property in the top bar, so VI/EN is visible there as on the
// macOS menu bar. Labels are Vietnamese, as everywhere users read them.

struct Choice { const char* label; };

const Choice kInputTypes[] = {{"Telex"}, {"VNI"}, {"Simple Telex 1"}, {"Simple Telex 2"}};
const Choice kCodeTables[] = {{"Unicode"}, {"TCVN3 (ABC)"}, {"VNI Windows"}, {"Unicode tổ hợp"},
                              {"Vietnamese CP1258"}};

struct Toggle { const char* key; const char* label; };

// Shown at the top level: the switches people reach for.
const Toggle kMainToggles[] = {
    {"vAutoDetectEnglish", "Tự động nhận diện tiếng Anh"},
    {"vCheckSpelling", "Kiểm tra chính tả"},
    {"vUseModernOrthography", "Chính tả hiện đại (oà, uý)"},
};

// Under "Tùy chọn khác".
const Toggle kMoreToggles[] = {
    {"vFreeMark", "Bỏ dấu tự do"},
    {"vRestoreIfWrongSpelling", "Khôi phục từ nếu sai chính tả"},
    {"vQuickTelex", "Telex nhanh (cc→ch, gg→gi…)"},
    {"vQuickStartConsonant", "Phụ âm đầu nhanh (f→ph, j→gi, w→qu)"},
    {"vQuickEndConsonant", "Phụ âm cuối nhanh (g→ng, h→nh, k→ch)"},
    {"vAllowConsonantZFWJ", "Cho phép Z / F / W / J là chữ cái"},
    {"vUpperCaseFirstChar", "Viết hoa chữ cái đầu"},
    {"vUseSmartSwitchKey", "Phím chuyển thông minh (nhớ VI/EN theo ứng dụng)"},
};

IBusText* text(const std::string& s) {
    return ibus_text_new_from_string(s.c_str());
}

std::string inputModeLabel() {
    std::string label = vLanguage ? "Chế độ gõ: Tiếng Việt" : "Chế độ gõ: Tiếng Anh";
    const std::string key = host().switchKey.key().toString(
        [](uint32_t kv) { const gchar* n = ibus_keyval_name(kv); return std::string(n ? n : ""); });
    if (!key.empty())
        label += " (" + key + ")";
    return label;
}

void refreshInputMode(IBusProperty* prop) {
    ibus_property_set_label(prop, text(inputModeLabel()));
    ibus_property_set_symbol(prop, text(vLanguage ? "VI" : "EN"));
    ibus_property_set_tooltip(prop, text("Bấm để chuyển giữa tiếng Việt và tiếng Anh"));
}

std::string choiceMenuLabel(const char* title, const Choice* choices, int count, int value) {
    return std::string(title) + ": " + choices[CLAMP(value, 0, count - 1)].label;
}

IBusProperty* choiceMenu(const char* key, const char* title, const Choice* choices, int count, int value) {
    IBusPropList* sub = ibus_prop_list_new();
    for (int i = 0; i < count; i++) {
        std::string subKey = std::string(key) + "." + std::to_string(i);
        ibus_prop_list_append(sub, ibus_property_new(subKey.c_str(), PROP_TYPE_RADIO, text(choices[i].label),
                                                     nullptr, nullptr, TRUE, TRUE,
                                                     i == value ? PROP_STATE_CHECKED : PROP_STATE_UNCHECKED, nullptr));
    }
    return ibus_property_new(key, PROP_TYPE_MENU, text(choiceMenuLabel(title, choices, count, value)), nullptr,
                             nullptr, TRUE, TRUE, PROP_STATE_UNCHECKED, sub);
}

IBusProperty* toggle(const Toggle& t) {
    key84::Option* o = key84::Settings::find(t.key);
    return ibus_property_new(t.key, PROP_TYPE_TOGGLE, text(t.label), nullptr, nullptr, TRUE, TRUE,
                             (o && *o->value) ? PROP_STATE_CHECKED : PROP_STATE_UNCHECKED, nullptr);
}

IBusPropList* buildProperties() {
    IBusPropList* props = ibus_prop_list_new();

    IBusProperty* mode = ibus_property_new("InputMode", PROP_TYPE_NORMAL, text(""), nullptr, nullptr,
                                           TRUE, TRUE, PROP_STATE_UNCHECKED, nullptr);
    refreshInputMode(mode);
    ibus_prop_list_append(props, mode);

    ibus_prop_list_append(props, choiceMenu("InputType", "Kiểu gõ", kInputTypes, G_N_ELEMENTS(kInputTypes), vInputType));
    ibus_prop_list_append(props, choiceMenu("CodeTable", "Bảng mã", kCodeTables, G_N_ELEMENTS(kCodeTables), vCodeTable));
    for (const Toggle& t : kMainToggles)
        ibus_prop_list_append(props, toggle(t));

    IBusPropList* more = ibus_prop_list_new();
    for (const Toggle& t : kMoreToggles)
        ibus_prop_list_append(more, toggle(t));
    ibus_prop_list_append(props, ibus_property_new("More", PROP_TYPE_MENU, text("Tùy chọn khác"), nullptr, nullptr,
                                                   TRUE, TRUE, PROP_STATE_UNCHECKED, more));

    ibus_prop_list_append(props, ibus_property_new("Setup", PROP_TYPE_NORMAL, text("Cài đặt 84Key…"), nullptr,
                                                   nullptr, TRUE, TRUE, PROP_STATE_UNCHECKED, nullptr));
    return props;
}

// Find a property by key, sub-menus included.
IBusProperty* findProperty(IBusPropList* list, const char* key) {
    for (guint i = 0;; i++) {
        IBusProperty* p = ibus_prop_list_get(list, i);
        if (!p)
            return nullptr;
        if (g_strcmp0(ibus_property_get_key(p), key) == 0)
            return p;
        if (IBusPropList* sub = ibus_property_get_sub_props(p))
            if (IBusProperty* found = findProperty(sub, key))
                return found;
    }
}

// Bring every property in line with the current settings. With `notify`, also
// tell the panel; without, the caller registers the whole list afterwards.
void refreshProperties(Key84Engine* engine, bool notify) {
    IBusEngine* e = IBUS_ENGINE(engine);
    auto update = [&](IBusProperty* p) { if (p && notify) ibus_engine_update_property(e, p); };

    if (IBusProperty* mode = findProperty(engine->props, "InputMode")) {
        refreshInputMode(mode);
        update(mode);
    }
    auto syncChoice = [&](const char* key, const char* title, const Choice* choices, int count, int value) {
        IBusProperty* menu = findProperty(engine->props, key);
        if (!menu)
            return;
        ibus_property_set_label(menu, text(choiceMenuLabel(title, choices, count, value)));
        for (int i = 0; i < count; i++) {
            std::string subKey = std::string(key) + "." + std::to_string(i);
            if (IBusProperty* p = findProperty(engine->props, subKey.c_str())) {
                ibus_property_set_state(p, i == value ? PROP_STATE_CHECKED : PROP_STATE_UNCHECKED);
                update(p);
            }
        }
        update(menu);
    };
    syncChoice("InputType", "Kiểu gõ", kInputTypes, G_N_ELEMENTS(kInputTypes), vInputType);
    syncChoice("CodeTable", "Bảng mã", kCodeTables, G_N_ELEMENTS(kCodeTables), vCodeTable);
    for (const key84::Option& o : key84::Settings::options()) {
        if (IBusProperty* p = findProperty(engine->props, o.key)) {
            if (ibus_property_get_prop_type(p) != PROP_TYPE_TOGGLE)
                continue;
            ibus_property_set_state(p, *o.value ? PROP_STATE_CHECKED : PROP_STATE_UNCHECKED);
            update(p);
        }
    }
}

void syncProperties(Key84Engine* engine) {
    refreshProperties(engine, true);
}

// ---- Language, settings ----------------------------------------------------------

bool smartSwitchApplies(Key84Engine* engine) {
    return vUseSmartSwitchKey && engine->client && !engine->client->empty();
}

void setLanguage(Key84Engine* engine, int language, bool remember) {
    Host& h = host();
    if (h.composer.hasPreedit())
        emit(engine, h.composer.flush());   // finish the word in the old language
    else
        h.composer.reset();
    vLanguage = language;
    if (remember) {
        h.settings.save();
        if (smartSwitchApplies(engine)) {
            setAppInputMethodStatus(*engine->client, vLanguage);
            h.settings.saveAppLanguages();
        }
    }
    syncProperties(engine);
}

void applySwitchKey() {
    Host& h = host();
    h.switchKey.set(key84::SwitchKey::parse(h.settings.switchKey(), [](const std::string& name) {
        return (uint32_t)ibus_keyval_from_name(name.c_str());
    }));
}

gboolean reloadSettings(gpointer) {
    Host& h = host();
    h.reloadSource = 0;
    key84::Settings::Values values;
    // Our own saves (the menu, the VI/EN hotkey) come back here too; leave the
    // word being typed alone unless the file says something new.
    if (!h.settings.takeFileChanges(values) || values == h.settings.current())
        return G_SOURCE_REMOVE;
    if (h.focused && h.composer.hasPreedit())
        emit(h.focused, h.composer.flush());   // the word was typed under the old settings
    h.settings.apply(values);
    applySwitchKey();
    h.composer.reset();
    if (h.focused)
        syncProperties(h.focused);
    return G_SOURCE_REMOVE;
}

void onSettingsFileChanged(GFileMonitor*, GFile*, GFile*, GFileMonitorEvent event, gpointer) {
    if (event != G_FILE_MONITOR_EVENT_CHANGES_DONE_HINT && event != G_FILE_MONITOR_EVENT_CREATED &&
        event != G_FILE_MONITOR_EVENT_MOVED_IN && event != G_FILE_MONITOR_EVENT_RENAMED &&
        event != G_FILE_MONITOR_EVENT_DELETED)
        return;
    Host& h = host();
    // A save is a burst of events; read the file once it has settled.
    if (h.reloadSource)
        g_source_remove(h.reloadSource);
    h.reloadSource = g_timeout_add(100, reloadSettings, nullptr);
}

void launchSetup() {
    GError* error = nullptr;
    const gchar* argv[] = {KEY84_SETUP_PATH, nullptr};
    if (!g_spawn_async(nullptr, (gchar**)argv, nullptr, G_SPAWN_SEARCH_PATH, nullptr, nullptr, nullptr, &error)) {
        g_warning("84Key: cannot start %s: %s", KEY84_SETUP_PATH, error->message);
        g_clear_error(&error);
    }
}

// ---- Focus ----------------------------------------------------------------------

bool isPasswordField(IBusEngine* e) {
    guint purpose = 0, hints = 0;
    ibus_engine_get_content_type(e, &purpose, &hints);
    return purpose == IBUS_INPUT_PURPOSE_PASSWORD || purpose == IBUS_INPUT_PURPOSE_PIN;
}

void focusIn(Key84Engine* engine, const gchar* client) {
    Host& h = host();
    TRACE("focus-in %p client=%s", (void*)engine, client ? client : "(none)");
    h.focused = engine;
    forgetWord(engine);
    h.composer.setBypass(isPasswordField(IBUS_ENGINE(engine)));

    if (client) {
        // "fake" is the context IBus uses when no application has focus.
        const bool real = *client && g_strcmp0(client, "fake") != 0;
        *engine->client = real ? client : "";
    }
    if (smartSwitchApplies(engine)) {
        int language = getAppInputMethodStatus(*engine->client, vLanguage);
        if (language >= 0 && language != vLanguage)
            vLanguage = language;
    }
    refreshProperties(engine, false);
    ibus_engine_register_properties(IBUS_ENGINE(engine), engine->props);
}

} // namespace

// ---- IBusEngine vfuncs ------------------------------------------------------------

static gboolean key84_engine_process_key_event(IBusEngine* e, guint keyval, guint keycode, guint state) {
    (void)keycode;
    Key84Engine* engine = KEY84_ENGINE(e);
    Host& h = host();
    if (h.focused != engine)
        focusIn(engine, nullptr);   // a client that sent no focus-in (some XIM clients)
    const bool release = (state & IBUS_RELEASE_MASK) != 0;

    switch (h.switchKey.feed(keyval, state, release)) {
        case key84::SwitchKeyMatcher::Toggle:
            setLanguage(engine, vLanguage ? 0 : 1, true);
            return TRUE;
        case key84::SwitchKeyMatcher::TogglePassThrough:
            setLanguage(engine, vLanguage ? 0 : 1, true);
            return FALSE;
        case key84::SwitchKeyMatcher::None:
            break;
    }
    if (release)
        return FALSE;

    key84::KeyEvent ev;
    ev.keyval = keyval;
    ev.unicode = ibus_keyval_to_unicode(keyval);
    ev.state = state;
    const unsigned overreaches = h.composer.overreaches();
    const key84::Output out = h.composer.processKey(ev);
    emit(engine, out);
    if (!h.composer.bypassed())   // never log what is typed into a password field
        TRACE("key %s state=0x%x lang=%d -> %s commit=\"%s\" preedit=\"%s\"%s",
          ibus_keyval_name(keyval), state, vLanguage, out.consumed ? "consumed" : "passed",
          utf8(out.commit).c_str(), utf8(h.composer.preeditText()).c_str(),
          h.composer.overreaches() != overreaches ? " (engine overreach refused)" : "");
    return out.consumed ? TRUE : FALSE;
}

static void key84_engine_focus_in(IBusEngine* e) {
    focusIn(KEY84_ENGINE(e), nullptr);
}

#if IBUS_CHECK_VERSION(1, 5, 27)
static void key84_engine_focus_in_id(IBusEngine* e, const gchar* objectPath, const gchar* client) {
    (void)objectPath;
    focusIn(KEY84_ENGINE(e), client ? client : "");
}
#endif

static void key84_engine_focus_out(IBusEngine* e) {
    Key84Engine* engine = KEY84_ENGINE(e);
    TRACE("focus-out %p%s", (void*)engine, host().focused == engine ? "" : " (not focused)");
    if (host().focused == engine) {
        forgetWord(engine);
        host().focused = nullptr;
    }
}

#if IBUS_CHECK_VERSION(1, 5, 27)
static void key84_engine_focus_out_id(IBusEngine* e, const gchar* objectPath) {
    (void)objectPath;
    key84_engine_focus_out(e);
}
#endif

static void key84_engine_reset(IBusEngine* e) {
    Key84Engine* engine = KEY84_ENGINE(e);
    TRACE("reset %p%s", (void*)engine, host().focused == engine ? "" : " (not focused)");
    if (host().focused == engine)
        forgetWord(engine);
}

static void key84_engine_enable(IBusEngine* e) {
    Key84Engine* engine = KEY84_ENGINE(e);
    forgetWord(engine);
    refreshProperties(engine, false);
    ibus_engine_register_properties(e, engine->props);
}

static void key84_engine_disable(IBusEngine* e) {
    key84_engine_reset(e);
}

static void key84_engine_set_content_type(IBusEngine* e, guint purpose, guint hints) {
    Key84Engine* engine = KEY84_ENGINE(e);
    TRACE("content-type %p purpose=%u hints=0x%x", (void*)engine, purpose, hints);
    if (host().focused != engine)
        return;
    const bool password = purpose == IBUS_INPUT_PURPOSE_PASSWORD || purpose == IBUS_INPUT_PURPOSE_PIN;
    if (password && host().composer.hasPreedit())
        emit(engine, host().composer.flush());
    host().composer.setBypass(password);
}

static void key84_engine_property_activate(IBusEngine* e, const gchar* name, guint state) {
    Key84Engine* engine = KEY84_ENGINE(e);
    Host& h = host();
    const std::string key(name);

    if (key == "InputMode") {
        setLanguage(engine, vLanguage ? 0 : 1, true);
        return;
    }
    if (key == "Setup") {
        launchSetup();
        return;
    }
    auto choice = [&](const char* prefix, int* target, int count) {
        const std::string p = std::string(prefix) + ".";
        if (key.compare(0, p.size(), p) != 0)
            return false;
        // GNOME Shell activates every radio item of the group, the old one with
        // UNCHECKED; only the CHECKED one names the new value.
        const int value = atoi(key.c_str() + p.size());
        if (state == PROP_STATE_CHECKED && value >= 0 && value < count && value != *target) {
            if (h.composer.hasPreedit())
                emit(engine, h.composer.flush());
            *target = value;
            h.settings.save();
            syncProperties(engine);
        }
        return true;
    };
    if (choice("InputType", &vInputType, G_N_ELEMENTS(kInputTypes)) ||
        choice("CodeTable", &vCodeTable, G_N_ELEMENTS(kCodeTables)))
        return;

    if (key84::Option* o = key84::Settings::find(key)) {
        const int value = (state == PROP_STATE_CHECKED) ? 1 : 0;
        if (*o->value != value) {
            if (h.composer.hasPreedit())
                emit(engine, h.composer.flush());
            *o->value = value;
            if (key == "vCheckSpelling")
                vSetCheckSpelling();
            h.settings.save();
        }
        syncProperties(engine);
    }
}

static void key84_engine_finalize(GObject* object) {
    Key84Engine* engine = KEY84_ENGINE(object);
    if (host().focused == engine)
        host().focused = nullptr;
    g_clear_object(&engine->props);
    delete engine->client;
    G_OBJECT_CLASS(key84_engine_parent_class)->finalize(object);
}

static void key84_engine_init(Key84Engine* engine) {
    engine->client = new std::string();
    engine->preeditVisible = FALSE;
    engine->props = buildProperties();
    g_object_ref_sink(engine->props);
}

static void key84_engine_class_init(Key84EngineClass* klass) {
    GObjectClass* objectClass = G_OBJECT_CLASS(klass);
    IBusEngineClass* engineClass = IBUS_ENGINE_CLASS(klass);
    objectClass->finalize = key84_engine_finalize;
    engineClass->process_key_event = key84_engine_process_key_event;
    engineClass->focus_in = key84_engine_focus_in;
    engineClass->focus_out = key84_engine_focus_out;
#if IBUS_CHECK_VERSION(1, 5, 27)
    engineClass->focus_in_id = key84_engine_focus_in_id;
    engineClass->focus_out_id = key84_engine_focus_out_id;
#endif
    engineClass->reset = key84_engine_reset;
    engineClass->enable = key84_engine_enable;
    engineClass->disable = key84_engine_disable;
    engineClass->set_content_type = key84_engine_set_content_type;
    engineClass->property_activate = key84_engine_property_activate;
}

// ---- Process-wide setup ------------------------------------------------------------

void key84_engine_init_host(const char* dataDir) {
    Host& h = host();
    h.settings.load();
    h.settings.loadAppLanguages();
    applySwitchKey();

    gchar* eng = g_build_filename(dataDir, "english_words.dat", nullptr);
    gchar* viet = g_build_filename(dataDir, "viet_telex.dat", nullptr);
    gchar* data = nullptr;
    gsize size = 0;
    if (g_file_get_contents(eng, &data, &size, nullptr)) {
        initEnglishDict((const Byte*)data, (int)size);
        g_free(data);
    } else {
        g_warning("84Key: %s is missing; automatic English detection is off", eng);
    }
    if (g_file_get_contents(viet, &data, &size, nullptr)) {
        initVietByTelexDict((const Byte*)data, (int)size);
        g_free(data);
    } else {
        g_warning("84Key: %s is missing", viet);
    }
    g_free(eng);
    g_free(viet);

    // Watch the file even before it exists: a first install has no settings
    // yet, and the settings window creates them. Without the directory there is
    // nothing to watch, and GLib falls back to polling for it every few seconds.
    g_mkdir_with_parents(key84::Settings::configDir().c_str(), 0700);
    GFile* file = g_file_new_for_path(h.settings.path().c_str());
    GError* error = nullptr;
    h.monitor = g_file_monitor_file(file, G_FILE_MONITOR_WATCH_MOVES, nullptr, &error);
    if (h.monitor)
        g_signal_connect(h.monitor, "changed", G_CALLBACK(onSettingsFileChanged), nullptr);
    else {
        g_warning("84Key: cannot watch %s: %s", h.settings.path().c_str(), error->message);
        g_clear_error(&error);
    }
    g_object_unref(file);
}

IBusEngine* key84_engine_create(IBusFactory* factory, const gchar* engineName, gpointer userData) {
    (void)userData;
    static guint serial = 0;
    gchar* path = g_strdup_printf("/org/freedesktop/IBus/Engine/Key84/%u", ++serial);
    GDBusConnection* connection = ibus_service_get_connection(IBUS_SERVICE(factory));
    // has-focus-id arrived in IBus 1.5.27; older daemons only send FocusIn, and
    // the language is then simply not remembered per application.
    gpointer klass = g_type_class_ref(KEY84_TYPE_ENGINE);
    const bool focusId = g_object_class_find_property(G_OBJECT_CLASS(klass), "has-focus-id") != nullptr;
    g_type_class_unref(klass);
    IBusEngine* engine;
    if (focusId)
        engine = (IBusEngine*)g_object_new(KEY84_TYPE_ENGINE, "engine-name", engineName, "object-path", path,
                                           "connection", connection, "has-focus-id", TRUE, nullptr);
    else
        engine = (IBusEngine*)g_object_new(KEY84_TYPE_ENGINE, "engine-name", engineName, "object-path", path,
                                           "connection", connection, nullptr);
    g_free(path);
    return engine;
}
