# Ceiv examples

Each directory is an app project. It has its own `app.json`, `package.json`,
`cyna.toml`, Cyna source, and Weiv page. The Cyna dependency names a version;
it does not point into this repository.

Start with [where app code belongs](../docs/app-architecture.md): Weiv owns the
page, while Cyna owns app operations and native resources. Generated commands
carry requests and typed results between them.

From an example directory, install its npm dependencies and run:

```sh
npm install
npm run check
npm run build
npm run run
```

These commands require `ceiv@0.1.0` from npm. Its package includes the
matching Cyna library, which the CLI installs when needed. The npm package is
not published yet. Framework development can build an example with the CLI
in this checkout, and `scripts/m1-check.sh` uses a temporary local Cyna
dependency to test current source.
