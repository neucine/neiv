# Neiv npm SDK

The `neiv` package contains the CLI, TypeScript frontend API in `src/`, and macOS host. The Cyna library source lives at the repository root in `src/`; `prepack` bundles its Cyna package artifact into this npm package.

From a Neiv source checkout, install dependencies with `npm ci --prefix packages/neiv`, then run `node packages/neiv/bin/neiv.mjs new`, `check`, `build`, or `run` from the repository root. The [examples](https://github.com/neucine/neiv/tree/main/examples) link to this local package. Import frontend services from `@neucine/neiv/sdk` and native slot placement from `@neucine/neiv/slots`. App command and event bindings are generated from Cyna exports.

The package name is `@neucine/neiv`, but it has not been published. The unscoped npm name `neiv` belongs to an unrelated project; do not install it expecting this framework.

See the [repository README](https://github.com/neucine/neiv) for examples and requirements.

For a source checkout using newer Weiv managed state, build the matching Weiv compiler and package runtime, then set `WEIV_PACKAGE_ROOT` to that checkout's `packages/weiv` directory when running `neiv build`. Neiv uses that package's CLI and runtime together. Without the override, Neiv uses its pinned `weivjs` dependency (0.1.2), whose component callbacks still require the legacy update contract. Do not combine a newer compiler binary with the pinned package runtime through `WEIV_BINARY_PATH` alone.
