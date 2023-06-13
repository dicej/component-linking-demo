# component-linking-demo

This is an experiment in implementing [shared-everything linking](https://github.com/WebAssembly/component-model/blob/main/design/mvp/examples/SharedEverythingDynamicLinking.md) using the WebAssembly [component model](https://github.com/WebAssembly/component-model) proposal.  It uses a modified version of [wasi-sdk](https://github.com/WebAssembly/wasi-sdk) and [wasm-tools](https://github.com/bytecodealliance/wasm-tools/).

## Building

Prerequisites:
- A UNIX-style OS, e.g. Linux, WSL2 or MacOS
- Rust (including the wasm32-unknown-unknown target)
- CMake
- Clang
- Ninja
- [CPython](https://github.com/python/cpython) build dependencies

Note that the `make` step will take quite a while the first time you run it since it needs to build LLVM, wasi-libc, CPython, Wasmtime, wit-bindgen, and wasm-tools.  Subsequent builds should be quite fast, though.

```
git submodule update --init --recursive
make
```
