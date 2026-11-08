import { copyFileSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

const output = resolve(process.argv[2]);
const packages = join(output, "__weiv_packages/neiv");
mkdirSync(packages, { recursive: true });
for (const name of ["sdk", "slots"]) {
  copyFileSync(new URL(`../dist/${name}.js`, import.meta.url), join(packages, `${name}.js`));
}
function rewrite(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) { if (entry.name !== "__weiv_packages") rewrite(path); continue; }
    if (!/\.(m?js)$/.test(entry.name)) continue;
    const source = readFileSync(path, "utf8");
    const updated = source.replaceAll('"/__weiv_packages/neiv/sdk"', '"/__weiv_packages/neiv/sdk.js"')
      .replaceAll('"/__weiv_packages/neiv/slots"', '"/__weiv_packages/neiv/slots.js"');
    if (updated !== source) writeFileSync(path, updated);
  }
}
rewrite(output);
