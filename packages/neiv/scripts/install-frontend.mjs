import { copyFileSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

const output = resolve(process.argv[2]);
const packages = join(output, "__weiv_packages/@neucine/neiv");
mkdirSync(packages, { recursive: true });
for (const name of ["sdk", "slots", "http"]) {
  copyFileSync(new URL(`../dist/${name}.js`, import.meta.url), join(packages, `${name}.js`));
}
const packageRoots = ["@neucine/neiv", "neiv"];
function rewrite(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== "__weiv_packages") rewrite(path);
      continue;
    }
    if (!/\.(m?js)$/.test(entry.name)) continue;
    const source = readFileSync(path, "utf8");
    let updated = source;
    for (const packageRoot of packageRoots) {
      for (const name of ["sdk", "slots", "http"]) {
        const bare = `"/__weiv_packages/${packageRoot}/${name}"`;
        updated = updated.replaceAll(bare, `${bare.slice(0, -1)}.js"`);
      }
    }
    if (updated !== source) writeFileSync(path, updated);
  }
}
rewrite(output);
