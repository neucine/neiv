# Neiv

Neiv is a framework for macOS apps with a [Weiv](https://github.com/neucine/weiv) interface and [Cyna](https://github.com/neucine/cyna) application code. Write the page in Weiv and TypeScript, implement app operations in Cyna, and use Neiv to build and run the native app. Neiv supplies the macOS window, webview, and bridge between the two.

## Requirements

- macOS and Xcode Command Line Tools
- Cyna 0.5.0
- Node.js 22 or later

The Neiv package supplies its Weiv dependency. To use the CLI from this checkout, install the package dependencies first:

```sh
cd packages/neiv
npm ci
cd ../..
```

## Create an app

From the repository root:

```sh
node packages/neiv/bin/neiv.mjs new ../my-app --id dev.example.my-app
node packages/neiv/bin/neiv.mjs check ../my-app
node packages/neiv/bin/neiv.mjs run ../my-app
```

`new` creates an app manifest, Cyna source, and a Weiv page. `check` validates the app and generated bindings. `run` builds the `.app` and opens it. The npm package is named `@neucine/neiv`; until it is published, use the CLI from this checkout. The unscoped npm name `neiv` belongs to another project.

Edit `../my-app/src/lib.cy` for native app operations and `../my-app/web/App.weiv` for the interface. Neiv generates typed command and event bindings under `web/generated/`. The [app architecture guide](docs/app-architecture.md) explains where to put behavior; the [API guide](docs/api.md) covers commands, events, native services, and the CLI.

For a desktop client backed by a local server, declare `localHttp` in the app manifest. Neiv can bundle and manage any server executable, and supplies the native loopback HTTP bridge, client module `@neucine/neiv/http`, and macOS local networking permission. See [local HTTP client and server apps](docs/api.md#local-http-client-and-server-apps).

## Examples

The [examples](examples/README.md) are app projects linked to this checkout:

- [Hello](examples/hello) shows commands, windows, and events.
- [Provider](examples/provider) shows an app supplied native view.
- [Metal](examples/metal) shows an optional Metal color surface.
- [Proof](examples/proof) shows an optional video provider.

Build an example from this checkout with `node packages/neiv/bin/neiv.mjs build examples/hello`. The ordinary app does not require a Metal or video provider. The example `package.json` files link to this checkout's `packages/neiv`; see [example setup](examples/README.md).

## Build and package

`neiv build <directory>` creates `build/NeivApp.app`. `neiv dev <directory>` rebuilds and restarts the app when source files change. `neiv package <directory>` creates `build/NeivApp.zip`. For a signed release, pass `--sign "Developer ID Application: ..."` and optionally `--notarize-profile <keychain-profile>`; the signing identity and profile must already be configured in Apple's tools.

To run the repository's clean build and focused checks:

```sh
sh tests/m1-check.sh
```

## Repository layout

- `src/` and `cyna.toml`: the Cyna library.
- `packages/neiv/`: the npm CLI, TypeScript SDK, build scripts, and macOS host.
- `examples/`: standalone app examples.
- `docs/`: public app and API guides.
- `tests/`: build and bridge checks.

## License

Neiv is available under the [Mozilla Public License 2.0](LICENSE).
