import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const output = mkdtempSync(join(tmpdir(), "neiv-install-frontend-"));
const installer = new URL("../packages/neiv/scripts/install-frontend.mjs", import.meta.url).pathname;
try {
  mkdirSync(join(output, "components"));
  writeFileSync(
    join(output, "App.mjs"),
    [
      'import { attachNativeSlot } from "/__weiv_packages/neiv/slots";',
      'import { invoke } from "/__weiv_packages/@neucine/neiv/sdk";',
      'import { localHttp } from "/__weiv_packages/neiv/http";',
      'const keep = "/__weiv_packages/elsewhere/slots";',
    ].join("\n"),
  );
  writeFileSync(
    join(output, "components", "Panel.mjs"),
    'import { invoke } from "/__weiv_packages/neiv/sdk";\n',
  );

  const result = spawnSync(process.execPath, [installer, output], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);

  const app = readFileSync(join(output, "App.mjs"), "utf8");
  const panel = readFileSync(join(output, "components", "Panel.mjs"), "utf8");
  assert.match(app, /"\/__weiv_packages\/neiv\/slots\.js"/);
  assert.match(app, /"\/__weiv_packages\/@neucine\/neiv\/sdk\.js"/);
  assert.match(app, /"\/__weiv_packages\/neiv\/http\.js"/);
  assert.match(app, /"\/__weiv_packages\/elsewhere\/slots"/);
  assert.match(panel, /"\/__weiv_packages\/neiv\/sdk\.js"/);
  assert.doesNotMatch(app, /"\/__weiv_packages\/(?:@neucine\/)?neiv\/(?:sdk|slots|http)"/);
  console.log("Neiv frontend package imports: passed");
} finally {
  rmSync(output, { recursive: true, force: true });
}
