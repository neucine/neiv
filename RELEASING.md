# Neiv releasing

The canonical release contract is in daydream `shared/decisions/0001-canonical-release-process.md`. Neiv has an npm CLI and a Cyna library bundled into the package. Version sources are `packages/neiv/package.json`, its lockfile, root `cyna.toml`, and the Cyna package path in `packages/neiv/scripts/ensure-cyna-package.sh`. They agree at 0.1.3.

Run `node tools/release.mjs plan --preflight-only` first. Once the version sources agree and the required local Cyna and TypeScript inputs exist, `node tools/release.mjs rehearse` exercises plan, verify, publish to a local sink, verify-published, and record. It leaves only ignored files under `dist/release`, with no tag or network publication.

The manual CI workflow exposes version, macOS ARM64 platform, and preflight or verify mode. It installs the pinned public Cyna 0.5.0 distribution after source preflight, then runs the same release driver. Tag and public publish are not wired. A release record belongs in `daydream/projects/neiv/docs/releases/` after publication.

Making the GitHub repository public and publishing an npm package are separate steps. The unscoped npm name `neiv` is owned by another project; this package uses `@neucine/neiv`. The repository and npm package declare MPL-2.0. The scoped name is absent from the public npm registry as of 12 November 2026; that does not establish publishing rights for the scope. Verify scope access and a fresh install from the public registry before enabling npm publication. Until then, use the source checkout instructions in the root README. These checks do not change repository visibility or publish an artifact.
