WASI_SDK := $(abspath wasi-sdk/build/install/opt/wasi-sdk/)
WASMTIME := $(abspath wasmtime)
WASM_TOOLS := $(abspath wasm-tools)
WIT_BINDGEN := $(abspath wit-bindgen)
CPYTHON := $(abspath cpython/builddir/wasi/install)
RUNNER := $(abspath runner)
NUMPY := $(abspath numpy)
WASM_TOOLS_CLI := $(WASM_TOOLS)/target/release/wasm-tools
WIT_BINDGEN_CLI := $(WIT_BINDGEN)/target/release/wit-bindgen
RUNNER_CLI := $(RUNNER)/target/release/runner
BUILD_DIR := build
CC := $(WASI_SDK)/bin/clang
LDFLAGS := -shared
CFLAGS := -Wall -Wextra -Werror -Wno-unused-parameter -MD -MP -I$(BUILD_DIR) -I$(CPYTHON)/include/python3.11 -fPIC
WASI_ADAPTER := $(WASMTIME)/target/wasm32-unknown-unknown/release/wasi_snapshot_preview1.wasm
LIBC := $(WASI_SDK)/share/wasi-sysroot/lib/wasm32-wasi/libc.so
LIBCXX := $(WASI_SDK)/share/wasi-sysroot/lib/wasm32-wasi/libc++.so
LIBCXXABI := $(WASI_SDK)/share/wasi-sysroot/lib/wasm32-wasi/libc++abi.so

CPYTHON_ARCHIVES := \
	$(CPYTHON)/lib/libpython3.11.a \
	$(CPYTHON)/../Modules/_decimal/libmpdec/libmpdec.a \
	$(CPYTHON)/../Modules/expat/libexpat.a

NUMPY_LIBRARIES := \
	$(BUILD_DIR)/numpy/core/_struct_ufunc_tests.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/core/_rational_tests.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/core/_operand_flag_tests.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/core/_umath_tests.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/core/_multiarray_tests.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/core/_multiarray_umath.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/core/_simd.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/linalg/lapack_lite.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/linalg/_umath_linalg.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/fft/_pocketfft_internal.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/random/_common.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/random/_philox.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/random/_pcg64.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/random/_mt19937.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/random/_generator.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/random/bit_generator.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/random/mtrand.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/random/_sfc64.cpython-311-wasm32-wasi.so \
	$(BUILD_DIR)/numpy/random/_bounded_integers.cpython-311-wasm32-wasi.so

.PHONY: test
test: $(BUILD_DIR)/bar.wasm $(RUNNER_CLI)
	$(RUNNER_CLI) \
		--env PYTHONPATH=/python:/build \
		--env PYTHONHOME=/python \
		--mapdir /python::$(CPYTHON)/lib/python3.11 \
		--mapdir /build::$(abspath $(BUILD_DIR)) \
		$<

$(BUILD_DIR)/bar.wasm: $(WASM_TOOLS_CLI)

$(BUILD_DIR)/bar.wasm: \
		$(BUILD_DIR)/libbar.so \
		$(BUILD_DIR)/libfoo.so \
		$(BUILD_DIR)/libpython3.11.so \
		$(LIBC) \
		$(LIBCXX) \
		$(LIBCXXABI) \
		$(NUMPY_LIBRARIES) \
		$(WASI_ADAPTER)
	$(WASM_TOOLS_CLI) component link \
		--adapt wasi_snapshot_preview1=$(WASI_ADAPTER) \
		--dl-openable $(BUILD_DIR)/libfoo.so \
		$(BUILD_DIR)/libbar.so \
		$(BUILD_DIR)/libpython3.11.so \
		$(LIBC) \
		$(LIBCXX) \
		$(LIBCXXABI) \
		$(shell echo $(NUMPY_LIBRARIES) | \
			sed 's_$(BUILD_DIR)/\([^ ]*\)_--dl-openable /build/\1=$(BUILD_DIR)/\1_g') \
		-o $@

$(BUILD_DIR)/libbar.so: $(BUILD_DIR)/bar.o $(BUILD_DIR)/bar_component_type.o $(BUILD_DIR)/bar_impl.o
	$(CC) $(LDFLAGS) -o $@ $^

$(BUILD_DIR)/libfoo.so: $(BUILD_DIR)/foo.o
	$(CC) $(LDFLAGS) -o $@ $^

$(BUILD_DIR)/libpython3.11.so: $(CPYTHON_ARCHIVES)
	$(CC) $(LDFLAGS) -o $@ \
		-Wl,--whole-archive $(CPYTHON)/lib/libpython3.11.a -Wl,--no-whole-archive \
		$(CPYTHON)/../Modules/_decimal/libmpdec/libmpdec.a \
		$(CPYTHON)/../Modules/expat/libexpat.a

$(CPYTHON)/../../build/libpython3.11.a:
	@mkdir -p cpython/builddir/build
	(cd cpython/builddir/build && ../../configure --prefix=$$(pwd)/install && make)

$(CPYTHON)/lib/libpython3.11.a: $(CPYTHON)/../../build/libpython3.11.a $(CC)
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

$(LIBC) $(LIBCXX) $(LIBCXXABI) $(CC): wasi-sdk/build/wasi-libc.BUILT wasi-sdk/build/libcxx.BUILT

wasi-sdk/build/wasi-libc.BUILT wasi-sdk/build/libcxx.BUILT:
	(cd wasi-sdk && make build/wasi-libc.BUILT build/libcxx.BUILT)

$(NUMPY_LIBRARIES):
	bash build-numpy.sh

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
