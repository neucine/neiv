# Neiv npm SDK

The `neiv` package contains the CLI, TypeScript frontend API in `src/`, and macOS host. The Cyna library source lives at the repository root in `src/`; `prepack` bundles its Cyna package artifact into this npm package.

Install the package in a standalone app and use `neiv new`, `neiv check`, `neiv build`, or `neiv run`. Import frontend services from `neiv/sdk` and native slot placement from `neiv/slots`. App command and event bindings are generated from Cyna exports.

See the [repository README](https://github.com/neucine/neiv) for examples and requirements.
