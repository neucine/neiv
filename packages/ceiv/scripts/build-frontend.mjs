import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
if (!existsSync(join(root, "src/sdk.ts"))) {
  if (!existsSync(join(root, "dist/sdk.js")) || !existsSync(join(root, "dist/slots.js")))
    throw new Error("Ceiv frontend runtime is missing from the package");
  process.exit(0);
}
const compiler = createRequire(import.meta.url).resolve("typescript/bin/tsc");
const result = spawnSync(process.execPath, [compiler, "--target", "ES2022", "--module", "ESNext",
  "--lib", "ES2022,DOM", "--declaration", "--rootDir", join(root, "src"),
  "--outDir", join(root, "dist"), join(root, "src/sdk.ts"),
  join(root, "src/slots.ts")], { stdio: "inherit" });
if (result.error) throw result.error;
process.exit(result.status ?? 1);
