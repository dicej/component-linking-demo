#include <stdint.h>
#include <stdio.h>
#include <dlfcn.h>
#include <Python.h>
#include "bar.h"

int32_t exports_test_test_test_bar(int32_t arg) {
    printf("hello, world!\n");

    Py_Initialize();

    PyObject* globals = PyDict_New();
    PyObject* locals = PyDict_New();
    PyDict_SetItem(globals, PyUnicode_FromString("value"), PyLong_FromLong(arg));
    PyRun_String("import numpy", Py_file_input, globals, locals);

    PyObject* result = PyRun_String("value + numpy.array([18])[0]", Py_eval_input, globals, locals);
    if (result == NULL) {
        fprintf(stderr, "PyRun_String failed\n");
        abort();
    }

    arg = PyLong_AsLong(result);

    void* foo_lib = dlopen("libfoo.so", 0);
    if (foo_lib == NULL) {
        fprintf(stderr, "unable to dlopen libfoo.so: %s\n", dlerror());
        abort();
    }

    void* foo_func = dlsym(foo_lib, "foo");
    char* error = dlerror();
    if (error) {
        fprintf(stderr, "unable to dlsym foo: %s\n", error);
        abort();
    }

    int32_t value = ((int32_t (*)(int32_t)) foo_func)(test_test_test_bar(arg + 73));

    if (dlclose(foo_lib)) {
        fprintf(stderr, "unable to dlclose libfoo.so: %s\n", dlerror());
        abort();
    }

    return value;
}
