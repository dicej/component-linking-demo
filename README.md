# component-linking-demo

This is an experiment in implementing [shared-everything linking](https://github.com/WebAssembly/component-model/blob/main/design/mvp/examples/SharedEverythingDynamicLinking.md) using the WebAssembly [component model](https://github.com/WebAssembly/component-model) proposal.  It uses a modified version of [wasi-sdk](https://github.com/WebAssembly/wasi-sdk) and [wasm-tools](https://github.com/bytecodealliance/wasm-tools/).

## Building

Prerequisites:
- Rust (including the wasm32-unknown-unknown target)
- CMake
- Clang
- Ninja

```
git submodule update --init --recursive
make
```
