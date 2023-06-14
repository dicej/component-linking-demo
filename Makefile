WASI_SDK := $(abspath wasi-sdk/build/install/opt/wasi-sdk/)
WASMTIME := $(abspath wasmtime)
WASM_TOOLS := $(abspath wasm-tools)
WIT_BINDGEN := $(abspath wit-bindgen)
CPYTHON := $(abspath cpython/builddir/wasi/install)
RUNNER := $(abspath runner)
WASM_TOOLS_CLI := $(WASM_TOOLS)/target/release/wasm-tools
WIT_BINDGEN_CLI := $(WIT_BINDGEN)/target/release/wit-bindgen
RUNNER_CLI := $(RUNNER)/target/release/runner
BUILD_DIR := build
CC := $(WASI_SDK)/bin/clang
LD := $(WASI_SDK)/bin/wasm-ld
LDFLAGS := -shared --Bdynamic -L$(WASI_SDK)/share/wasi-sysroot/lib/wasm32-wasi -lc
CFLAGS := -Wall -Wextra -Werror -Wno-unused-parameter -MD -MP -I$(BUILD_DIR) -I$(CPYTHON)/include/python3.11 -fPIC
WASI_ADAPTER := $(WASMTIME)/target/wasm32-unknown-unknown/release/wasi_preview1_component_adapter.wasm
BUILTINS := $(WASI_SDK)/lib/clang/17/lib/wasi/libclang_rt.builtins-wasm32.a
LIBC := $(WASI_SDK)/share/wasi-sysroot/lib/wasm32-wasi/libc.so
CPYTHON_ARCHIVES := \
	$(CPYTHON)/lib/libpython3.11.a \
	$(CPYTHON)/../Modules/_decimal/libmpdec/libmpdec.a \
	$(CPYTHON)/../Modules/expat/libexpat.a

.PHONY: test
test: $(BUILD_DIR)/bar.wasm $(RUNNER_CLI)
	$(RUNNER_CLI) --env PYTHONPATH=/python --env PYTHONHOME=/python --mapdir /python::$(CPYTHON)/lib/python3.11 $<

$(BUILD_DIR)/bar.wasm: $(WASM_TOOLS_CLI)

$(BUILD_DIR)/bar.wasm: \
		$(BUILD_DIR)/libbar.so \
		$(BUILD_DIR)/libfoo.so \
		$(BUILD_DIR)/libpython3.11.so \
		$(LIBC) \
		$(WASI_ADAPTER)
	$(WASM_TOOLS_CLI) component link \
		--adapt wasi_snapshot_preview1=$(WASI_ADAPTER) \
		--dl-openable $(BUILD_DIR)/libfoo.so \
		$(BUILD_DIR)/libbar.so \
		$(BUILD_DIR)/libpython3.11.so \
		$(LIBC) \
		-o $@

$(BUILD_DIR)/libbar.so: $(BUILD_DIR)/bar.o $(BUILD_DIR)/bar_component_type.o $(BUILD_DIR)/bar_impl.o
	$(LD) $(LDFLAGS) -o $@ $^ $(BUILTINS)

$(BUILD_DIR)/libfoo.so: $(BUILD_DIR)/foo.o
	$(LD) $(LDFLAGS) -o $@ $^ $(BUILTINS)

$(BUILD_DIR)/libpython3.11.so: $(CPYTHON_ARCHIVES)
	$(LD) $(LDFLAGS) -o $@ \
		--whole-archive $(CPYTHON)/lib/libpython3.11.a --no-whole-archive \
		$(CPYTHON)/../Modules/_decimal/libmpdec/libmpdec.a \
		$(CPYTHON)/../Modules/expat/libexpat.a \
		$(BUILTINS)

$(CPYTHON)/../../build/libpython3.11.a:
	@mkdir -p cpython/builddir/build
	(cd cpython/builddir/build && ../../configure --prefix=$$(pwd)/install && make)

$(CPYTHON_ARCHIVES): $(CPYTHON)/../../build/libpython3.11.a
	@mkdir -p cpython/builddir/wasi
	(cd cpython/builddir/wasi && \
		WASI_SDK_PATH=$(WASI_SDK) \
		CONFIG_SITE=../../Tools/wasm/config.site-wasm32-wasi \
		CFLAGS=-fPIC \
		../../Tools/wasm/wasi-env \
		../../configure \
		-C \
		--host=wasm32-unknown-wasi \
		--build=$$(../../config.guess) \
		--with-build-python=$$(if [ -e $$(pwd)/../build/python.exe ]; \
			then echo $$(pwd)/../build/python.exe; \
			else echo $$(pwd)/../build/python; \
			fi) \
		--prefix=$$(pwd)/install \
		--enable-wasm-dynamic-linking \
		--disable-test-modules && \
		make install)

$(BUILD_DIR)/bar.c: $(CPYTHON_ARCHIVES) $(WIT_BINDGEN_CLI)

$(BUILD_DIR)/bar.c $(BUILD_DIR)/bar.h $(BUILD_DIR)/bar_component_type.o: test.wit
	@mkdir -p "$(@D)"
	$(WIT_BINDGEN_CLI) c --out-dir "$(@D)" $<

$(BUILD_DIR)/bar.o $(BUILD_DIR)/bar_impl.o $(BUILD_DIR)/foo.o: $(CC)

$(BUILD_DIR)/%.o: %.c
	@mkdir -p "$(@D)"
	$(CC) $(CFLAGS) -o $@ -c $<

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
