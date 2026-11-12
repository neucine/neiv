import { spawnSync } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const sources = ["sdk", "slots", "http"].map(name => join(root, "src", `${name}.ts`));
const outputs = ["sdk", "slots", "http"].flatMap(name => [
  join(root, "dist", `${name}.js`),
  join(root, "dist", `${name}.d.ts`),
]);
const config = join(root, "tsconfig.frontend.json");
if (!existsSync(join(root, "src/sdk.ts"))) {
  if (
    !existsSync(join(root, "dist/sdk.js")) ||
    !existsSync(join(root, "dist/slots.js")) ||
    !existsSync(join(root, "dist/http.js"))
  )
    throw new Error("Neiv frontend runtime is missing from the package");
  process.exit(0);
}
const inputs = [...sources, config, join(root, "package-lock.json")];
if (
  outputs.every(existsSync) &&
  Math.min(...outputs.map(path => statSync(path).mtimeMs)) >=
    Math.max(...inputs.map(path => statSync(path).mtimeMs))
)
  process.exit(0);
const compiler = createRequire(import.meta.url).resolve("typescript/bin/tsc");
const result = spawnSync(process.execPath, [compiler, "--project", config], { stdio: "inherit", cwd: root });
if (result.error) throw result.error;
process.exit(result.status ?? 1);
