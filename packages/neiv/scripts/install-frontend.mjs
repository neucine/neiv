import { copyFileSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

const output = resolve(process.argv[2]);
const packages = join(output, "__weiv_packages/@neucine/neiv");
mkdirSync(packages, { recursive: true });
for (const name of ["sdk", "slots", "http"]) {
  copyFileSync(new URL(`../dist/${name}.js`, import.meta.url), join(packages, `${name}.js`));
}
const packageRoots = ["@neucine/neiv", "neiv"];
const canonicalPackageRoot = "@neucine/neiv";
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
        const request = `/__weiv_packages/${packageRoot}/${name}`;
        const canonical = `"/__weiv_packages/${canonicalPackageRoot}/${name}.js"`;
        updated = updated.replaceAll(`"${request}"`, canonical);
        updated = updated.replaceAll(`"${request}.js"`, canonical);
      }
    }
    if (updated !== source) writeFileSync(path, updated);
  }
}
rewrite(output);
