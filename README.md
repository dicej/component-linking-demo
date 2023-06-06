# component-linking-demo

This is an experiment in implementing [shared-everything linking](https://github.com/WebAssembly/component-model/blob/main/design/mvp/examples/SharedEverythingDynamicLinking.md) using the WebAssembly [component model](https://github.com/WebAssembly/component-model) proposal.  It uses a modified version of [wasi-sdk](https://github.com/WebAssembly/wasi-sdk) and [wasm-tools](https://github.com/bytecodealliance/wasm-tools/).

## Building

Prerequisites:
- Rust (including the wasm32-unknown-unknown target)
- CMake
- Clang
- Ninja

Note that the fork of `wasm-tools` I'm using to do the linking does not yet support cyclic dependencies, so this won't run all the way to completion yet.  I'm planning to address that soon-ish.

```
git submodule update --init --recursive
make
```
