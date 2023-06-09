#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>

#define EXPORT __attribute__((visibility("default"))) __attribute__((used))

#define MIN(X, Y) (((X) < (Y)) ? (X) : (Y))

struct name_t {
    uint32_t length;
    uint8_t *data;
};

struct symbol_t {
    struct name_t name;
    void *address;
};

struct symbols_t {
    uint32_t count;
    struct symbol_t *symbols;
};

struct library_t {
    struct name_t name;
    struct symbols_t symbols;
};

struct libraries_t {
    uint32_t count;
    struct library_t *libraries;
};

static const char *error = 0;
static struct libraries_t *libraries = 0;

EXPORT int dlclose(void *library_void) {
    // TODO
    error = "dlclose not yet supported";
    return -1;
}

EXPORT char *dlerror(void) {
    const char *var = error;
    error = 0;
    return (char*) var;
}

EXPORT void *dlopen(const char *name, int flags) {
    if (libraries == 0) {
        fprintf(stderr, "`__wasm_set_libraries` should have been called during component "
                "instantiation with a non-NULL value\n");
        abort();
    }

    if (flags & ~(RTLD_LAZY | RTLD_NOW)) {
        // TODO
        error = "dlopen flags not yet supported";
        return 0;
    }

    uint32_t length = strlen(name);
    int first = 0;
    int last = libraries->count - 1;
    while (first <= last) {
        int middle = (first + last) / 2;
        struct library_t *library = libraries->libraries + middle;
        int diff = memcmp(library->name.data, name, MIN(library->name.length, length));
        if (diff == 0) {
            if (library->name.length == length) {
                return library;
            } else if (library->name.length < length) {
                first = middle + 1;
            } else {
                last = middle - 1;
            }
        } else if (diff < 0) {
            first = middle + 1;
        } else {
            last = middle - 1;
        }
    }

    error = "library not found";
    return 0;
}

EXPORT void *dlsym(void *library_void, const char *name) {
    if (library_void == RTLD_NEXT || library_void == RTLD_DEFAULT) {
        // TODO
        error = "dlsym RTLD_NEXT and RTLD_DEFAULT not yet supported";
        return 0;
    }

    struct library_t *library = library_void;

    uint32_t length = strlen(name);
    int first = 0;
    int last = library->symbols.count - 1;
    while (first <= last) {
        int middle = (first + last) / 2;
        struct symbol_t *symbol = library->symbols.symbols + middle;
        int diff = memcmp(symbol->name.data, name, MIN(symbol->name.length, length));
        if (diff == 0) {
            if (symbol->name.length == length) {
                return symbol->address;
            } else if (symbol->name.length < length) {
                first = middle + 1;
            } else {
                last = middle - 1;
            }
        } else if (diff < 0) {
            first = middle + 1;
        } else {
            last = middle - 1;
        }
    }

    error = "symbols not found";
    return 0;
}

EXPORT void __wasm_set_libraries(struct libraries_t *new_libraries) {
    libraries = new_libraries;
}
