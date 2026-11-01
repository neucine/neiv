# Ceiv npm SDK

The `ceiv` package contains the CLI, TypeScript frontend API in `src/`, and macOS host. The Cyna library source lives at the repository root in `src/`; `prepack` bundles its Cyna package artifact into this npm package.

Install the package in a standalone app and use `ceiv new`, `ceiv check`, `ceiv build`, or `ceiv run`. Import frontend services from `ceiv/sdk` and native slot placement from `ceiv/slots`. App command and event bindings are generated from Cyna exports.

See the [repository README](https://github.com/neucine/ceiv) for examples and requirements.
