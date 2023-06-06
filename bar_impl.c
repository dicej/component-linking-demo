#include <stdint.h>

int32_t exports_test_test_test_bar(int32_t arg) {
    return arg + 73;
}


__attribute__((__export_name__("__main_argc_argv")))
int main_argc_argv(int argc, int argv) {
    return 0;
}
