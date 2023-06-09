#include <stdint.h>
#include <stdio.h>
#include <dlfcn.h>
#include "bar.h"

int32_t exports_test_test_test_bar(int32_t arg) {
    printf("hello, world!\n");

    void* foo_lib = dlopen("libfoo.so", 0);
    if (foo_lib == 0) {
        fprintf(stderr, "unable to dlopen libfoo.so: %s\n", dlerror());
        abort();
    }

    void* foo_func = dlsym(foo_lib, "foo");
    char* error = dlerror();
    if (error) {
        fprintf(stderr, "unable to dlsym foo: %s\n", error);
        abort();
    }

    return ((int32_t (*)(int32_t)) foo_func)(test_test_test_bar(arg + 73));
}
