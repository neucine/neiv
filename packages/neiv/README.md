# Neiv npm SDK

The `neiv` package contains the CLI, TypeScript frontend API in `src/`, and macOS host. The Cyna library source lives at the repository root in `src/`; `prepack` bundles its Cyna package artifact into this npm package.

Install the package in a standalone app and use `neiv new`, `neiv check`, `neiv build`, or `neiv run`. Import frontend services from `neiv/sdk` and native slot placement from `neiv/slots`. App command and event bindings are generated from Cyna exports.

See the [repository README](https://github.com/neucine/neiv) for examples and requirements.

For a source checkout using newer Weiv managed state, build the matching Weiv compiler and package runtime, then set `WEIV_PACKAGE_ROOT` to that checkout's `packages/weiv` directory when running `neiv build`. Neiv uses that package's CLI and runtime together. Without the override, Neiv uses its pinned `weivjs` dependency (0.1.2), whose component callbacks still require the legacy update contract. Do not combine a newer compiler binary with the pinned package runtime through `WEIV_BINARY_PATH` alone.
