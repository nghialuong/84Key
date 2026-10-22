//
//  Key84Engine.h
//  84Key — the IBus engine: connects IBus to the typing pipeline (Composer),
//  the VI/EN hotkey, the settings file and the input-source menu.
//

#ifndef KEY84_ENGINE_H
#define KEY84_ENGINE_H

#include <ibus.h>

G_BEGIN_DECLS

// Spelled out rather than G_DECLARE_FINAL_TYPE: IBus defines no g_autoptr
// cleanup for IBusEngine, which that macro needs.
typedef struct _Key84Engine Key84Engine;
typedef struct _Key84EngineClass Key84EngineClass;

#define KEY84_TYPE_ENGINE (key84_engine_get_type())
#define KEY84_ENGINE(obj) (G_TYPE_CHECK_INSTANCE_CAST((obj), KEY84_TYPE_ENGINE, Key84Engine))

GType key84_engine_get_type(void);

// Load the settings and the dictionaries, and start watching the settings file.
// Call once, before the factory creates an engine. `dataDir` holds
// english_words.dat and viet_telex.dat.
void key84_engine_init_host(const char* dataDir);

// IBusFactory::create-engine handler: builds the engine with has-focus-id set,
// so IBus tells it which application has focus (for per-app VI/EN memory).
IBusEngine* key84_engine_create(IBusFactory* factory, const gchar* engineName, gpointer userData);

G_END_DECLS

#endif // KEY84_ENGINE_H
