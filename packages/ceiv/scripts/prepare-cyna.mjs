import { copyFileSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";

const root = resolve(process.argv[2] || ".");
const source = join(root, "src");
const staged = join(root, "build", "cyna-src");
const generated = join(source, "generated");
const manifest = readFileSync(join(root, "cyna.toml"), "utf8");
const entry = manifest.match(/^entry\s*=\s*"src\/([^"]+\.cy)"\s*$/m)?.[1];
if (!/^src\s*=\s*"src"\s*$/m.test(manifest) || !entry)
  throw new Error("Ceiv requires src = \"src\" and an entry under src in cyna.toml");
const entryModule = entry.slice(0, -3).split(/[\\/]/).join(".");
const generatedManifest = manifest
  .replace(/^src\s*=\s*"src"\s*$/m, 'src = "cyna-src"')
  .replace(/^entry\s*=\s*"src\/([^"]+\.cy)"\s*$/m, 'entry = "cyna-src/ceiv_generated_entry.cy"')
  .replace(/\bpath\s*=\s*"([^"]+)"/g, (_match, path) => `path = "${relative(join(root, "build"), resolve(root, path))}"`);

rmSync(staged, { recursive: true, force: true });
mkdirSync(staged, { recursive: true });
for (const file of readdirSync(source, { recursive: true })) {
  if (!file.endsWith(".cy") || ["ceiv_callbacks.cy", "ceiv_commands.cy"].includes(file)) continue;
  const target = join(staged, file);
  mkdirSync(dirname(target), { recursive: true });
  copyFileSync(join(source, file), target);
}
mkdirSync(generated, { recursive: true });
writeFileSync(join(generated, "ceiv_generated_entry.cy"), [
  "// Generated Ceiv build entry. Do not edit.",
  `import .${entryModule};`,
  "import .generated.ceiv_generated_commands;",
  "import .generated.ceiv_generated_callbacks;",
  ""
].join("\n"));
copyFileSync(join(generated, "ceiv_generated_entry.cy"), join(staged, "ceiv_generated_entry.cy"));
writeFileSync(join(root, "build", "cyna.toml"), generatedManifest);
