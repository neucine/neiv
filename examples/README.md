# Neiv examples

Each directory is an app project. It has its own `app.json`, `package.json`,
`cyna.toml`, Cyna source, and Weiv page. The npm dependency links to the
sibling `packages/neiv` source checkout. The Cyna dependency names the matching
Neiv version, which the source build packs into the local Cyna package store.

Start with [where app code belongs](../docs/app-architecture.md): Weiv owns the
page, while Cyna owns app operations and native resources. Generated commands
carry requests and typed results between them.

First install the framework's locked npm dependencies from the repository root:

```sh
npm ci --prefix packages/neiv
```

Then, from an example directory, install its local link and run:

```sh
npm install
npm run check
npm run build
npm run run
```

This flow requires the Neiv checkout at `../..`; copy an example elsewhere only
after replacing its local npm dependency and installing a matching Cyna package.
The public npm name `neiv` belongs to an unrelated package. The framework's
package is named `@neucine/neiv` and has not been published. For a clean build
without touching the example directory, run `sh tests/m1-check.sh` from the
repository root.

Proof includes a short synthetic video test pattern for its optional video provider.
