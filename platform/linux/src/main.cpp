//
//  main.cpp
//  84Key — entry point of ibus-engine-84key.
//
//    --ibus    started by ibus-daemon from the installed component file
//    --xml     print the engine description (the component file runs this,
//              so the description below is the only copy)
//    (none)    development: register with the running ibus-daemon directly,
//              no install needed — then `ibus engine 84key` selects it
//

#include <clocale>
#include <cstdio>

#include <ibus.h>

#include "Key84Engine.h"

#ifndef KEY84_VERSION
#define KEY84_VERSION "0.0.0"
#endif
#ifndef KEY84_DATADIR
#define KEY84_DATADIR "/usr/share/84key"
#endif
#ifndef KEY84_SETUP_PATH
#define KEY84_SETUP_PATH "ibus-setup-84key"
#endif

namespace {

// D-Bus names may not have an element that starts with a digit, hence Key84
// (as in the macOS bundle id, com.nghialuong.key84).
constexpr const char* kBusName = "org.freedesktop.IBus.Key84";
constexpr const char* kEngineName = "84key";

IBusEngineDesc* engineDesc(const char* dataDir) {
    gchar* icon = g_build_filename(dataDir, "icons", "84key.png", nullptr);
    IBusEngineDesc* desc = ibus_engine_desc_new_varargs(
        "name", kEngineName,
        "longname", "84Key",
        "description", "Bộ gõ tiếng Việt 84Key — Telex, VNI, tự động nhận diện tiếng Anh",
        "language", "vi",
        "license", "GPL-3.0-or-later",
        "author", "84Key contributors",
        "icon", icon,
        // Keep whatever keyboard layout is active: the engine reads characters,
        // not key positions, so AZERTY or Dvorak users keep their layout.
        "layout", "default",
        "symbol", "VI",
        "setup", KEY84_SETUP_PATH,
        "version", KEY84_VERSION,
        "rank", 99,
        nullptr);
    g_free(icon);
    return desc;
}

void onDisconnected(IBusBus*, gpointer) {
    ibus_quit();
}

} // namespace

int main(int argc, char* argv[]) {
    gboolean startedByIBus = FALSE, printXml = FALSE, printVersion = FALSE;
    const GOptionEntry entries[] = {
        {"ibus", 'i', 0, G_OPTION_ARG_NONE, &startedByIBus, "Started by ibus-daemon", nullptr},
        {"xml", 'x', 0, G_OPTION_ARG_NONE, &printXml, "Print the engine description as XML", nullptr},
        {"version", 'V', 0, G_OPTION_ARG_NONE, &printVersion, "Print the version", nullptr},
        {nullptr, 0, 0, G_OPTION_ARG_NONE, nullptr, nullptr, nullptr},
    };
    GOptionContext* options = g_option_context_new("- 84Key Vietnamese input method for IBus");
    g_option_context_add_main_entries(options, entries, nullptr);
    GError* error = nullptr;
    if (!g_option_context_parse(options, &argc, &argv, &error)) {
        g_printerr("%s\n", error->message);
        return 1;
    }
    g_option_context_free(options);

    // KEY84_DATA_DIR points a development build at core/data.
    const char* dataDir = g_getenv("KEY84_DATA_DIR");
    if (!dataDir || !*dataDir)
        dataDir = KEY84_DATADIR;

    if (printVersion) {
        printf("84Key %s\n", KEY84_VERSION);
        return 0;
    }
    if (printXml) {
        GString* xml = g_string_new("<engines>\n");
        IBusEngineDesc* desc = engineDesc(dataDir);
        ibus_engine_desc_output(desc, xml, 1);
        g_object_unref(desc);
        g_string_append(xml, "</engines>\n");
        fputs(xml->str, stdout);
        g_string_free(xml, TRUE);
        return 0;
    }

    setlocale(LC_ALL, "");
    ibus_init();
    IBusBus* bus = ibus_bus_new();
    if (!ibus_bus_is_connected(bus)) {
        g_printerr("84Key: cannot connect to ibus-daemon\n");
        return 1;
    }
    g_signal_connect(bus, "disconnected", G_CALLBACK(onDisconnected), nullptr);

    key84_engine_init_host(dataDir);

    IBusFactory* factory = ibus_factory_new(ibus_bus_get_connection(bus));
    g_signal_connect(factory, "create-engine", G_CALLBACK(key84_engine_create), nullptr);
    ibus_factory_add_engine(factory, kEngineName, KEY84_TYPE_ENGINE);

    if (startedByIBus) {
        ibus_bus_request_name(bus, kBusName, 0);
    } else {
        IBusComponent* component = ibus_component_new(kBusName, "84Key", KEY84_VERSION, "GPL-3.0-or-later",
                                                      "84Key contributors", "https://github.com/nghialuong/84Key",
                                                      "", "84key");
        ibus_component_add_engine(component, engineDesc(dataDir));
        const gboolean registered = ibus_bus_register_component(bus, component);
        g_object_unref(component);
        if (!registered) {
            g_printerr("84Key: ibus-daemon refused the component\n");
            return 1;
        }
    }

    ibus_main();
    return 0;
}
