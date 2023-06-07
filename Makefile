WASI_SDK := $(abspath wasi-sdk/build/install/opt/wasi-sdk/)
WASMTIME := $(abspath wasmtime)
WASM_TOOLS := $(abspath wasm-tools)
WIT_BINDGEN := $(abspath wit-bindgen)
RUNNER := $(abspath runner)
WASM_TOOLS_CLI := $(WASM_TOOLS)/target/release/wasm-tools
WIT_BINDGEN_CLI := $(WIT_BINDGEN)/target/release/wit-bindgen
RUNNER_CLI := $(RUNNER)/target/release/runner
CC := $(WASI_SDK)/bin/clang
LD := $(WASI_SDK)/bin/wasm-ld
LDFLAGS := -shared --Bdynamic -L$(WASI_SDK)/share/wasi-sysroot/lib/wasm32-wasi -lc
CFLAGS := -Wall -Wextra -Werror -Wno-unused-parameter
WASI_ADAPTER := $(WASMTIME)/target/wasm32-unknown-unknown/release/wasi_preview1_component_adapter.wasm
BUILTINS := $(WASI_SDK)/lib/clang/17/lib/wasi/libclang_rt.builtins-wasm32.a
LIBC := $(WASI_SDK)/share/wasi-sysroot/lib/wasm32-wasi/libc.so
BUILD_DIR := build

.PHONY: test
test: $(BUILD_DIR)/bar.wasm $(RUNNER_CLI)
	$(RUNNER_CLI) $<

$(BUILD_DIR)/bar.wasm: $(WASM_TOOLS_CLI)

$(BUILD_DIR)/bar.wasm: $(BUILD_DIR)/libbar.so $(LIBC) $(WASI_ADAPTER)
	$(WASM_TOOLS_CLI) component link --adapt wasi_snapshot_preview1=$(WASI_ADAPTER) $< $(LIBC) -o $@

$(BUILD_DIR)/libbar.so: $(BUILD_DIR)/bar.o $(BUILD_DIR)/bar_component_type.o $(BUILD_DIR)/bar_impl.o
	$(LD) $(LDFLAGS) -o $@ $^ $(BUILTINS)

$(BUILD_DIR)/bar.c $(BUILD_DIR)/bar.h $(BUILD_DIR)/bar_component_type.o: test.wit $(WIT_BINDGEN_CLI)
	@mkdir -p "$(@D)"
	$(WIT_BINDGEN_CLI) c --out-dir "$(@D)" $<

$(BUILD_DIR)/bar.o $(BUILD_DIR)/bar_impl.o: $(CC)

$(BUILD_DIR)/%.o: %.c
	@mkdir -p "$(@D)"
	$(CC) $(CFLAGS) -MD -MP -o $@ -c $<

$(WASI_ADAPTER):
	cargo build --target wasm32-unknown-unknown \
		--manifest-path $(WASMTIME)/crates/wasi-preview1-component-adapter/Cargo.toml --release

$(WASM_TOOLS_CLI):
	cargo build --release --manifest-path $(WASM_TOOLS)/Cargo.toml

$(WIT_BINDGEN_CLI):
	cargo build --release --manifest-path $(WIT_BINDGEN)/Cargo.toml

$(RUNNER_CLI):
	cargo build --release --manifest-path $(RUNNER)/Cargo.toml

$(LIBC) $(CC):
	(cd wasi-sdk && make build/wasi-libc.BUILT)

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
