# Neiv releasing

The canonical release contract is in daydream `shared/decisions/0001-canonical-release-process.md`. Neiv has an npm CLI and a Cyna library bundled into the package. Version sources are `packages/neiv/package.json`, its lockfile, root `cyna.toml`, and the Cyna package path in `packages/neiv/scripts/ensure-cyna-package.sh`. They agree at 0.1.3.

Run `node tools/release.mjs plan --preflight-only` first. Once the version sources agree and the required local Cyna and TypeScript inputs exist, `node tools/release.mjs rehearse` exercises plan, verify, publish to a local sink, verify-published, and record. It leaves only ignored files under `dist/release`, with no tag or network publication.

The manual CI workflow exposes version, macOS ARM64 platform, and preflight or verify mode. It installs the pinned public Cyna 0.5.0 distribution after source preflight, then runs the same release driver. It has not yet had a green CI run. Tag and public publish are not wired. A release record belongs in `daydream/projects/neiv/docs/releases/` after publication.
