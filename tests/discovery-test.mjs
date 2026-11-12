import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { discoverCommands } from "../packages/neiv/scripts/discover-commands.mjs";

const root = mkdtempSync(join(tmpdir(), "neiv-discovery-"));
mkdirSync(join(root, "src"));
const source = join(root, "src", "lib.cy");
const generate = () => {
  const result = spawnSync(
    process.execPath,
    [new URL("../packages/neiv/scripts/generate-commands.mjs", import.meta.url).pathname, root],
    { encoding: "utf8" },
  );
  assert.equal(result.status, 0, result.stderr);
};
try {
  writeFileSync(source, 'export c("demo_value") fn demo_value(value: c_int): c_int { return value; }\n');
  assert.deepEqual(discoverCommands(root).commands[0], {
    name: "demoValue",
    binding: "demoValue",
    symbol: "demo_value",
    args: [{ name: "value", type: "int32" }],
    returns: { type: "int32" },
  });
  generate();
  assert.match(readFileSync(join(root, "web/generated/commands.ts"), "utf8"), /demoValue\(value: number/);
  assert.match(
    readFileSync(join(root, "web/generated/commands.d.ts"), "utf8"),
    /demoValue\(value: number, options\?: InvokeOptions\): Promise<number>/,
  );
  assert.match(
    readFileSync(join(root, "native/generated/dispatch.inc"), "utf8"),
    /extern int demo_value\(int\)/,
  );
  writeFileSync(source, 'export c("demo_value") fn demo_value(value: c_str): c_double { return 1.0; }\n');
  const changed = discoverCommands(root).commands[0];
  assert.equal(changed.args[0].type, "string");
  assert.equal(changed.returns.type, "number");
  generate();
  assert.match(readFileSync(join(root, "web/generated/commands.ts"), "utf8"), /demoValue\(value: string/);
  assert.match(
    readFileSync(join(root, "web/generated/commands.d.ts"), "utf8"),
    /demoValue\(value: string, options\?: InvokeOptions\): Promise<number>/,
  );
  assert.match(
    readFileSync(join(root, "native/generated/dispatch.inc"), "utf8"),
    /extern double demo_value\(const char \*\)/,
  );
  writeFileSync(
    source,
    "// @neiv-configure\npub fn configure(): void {}\n" +
      '// @neiv {"returns":"boolean"}\npub fn demo_value(value: i32): i32 { return value; }\n',
  );
  generate();
  const native = readFileSync(join(root, "src/generated/neiv_generated_commands.cy"), "utf8");
  assert.match(native, /export c\("neiv_app_configure"\)/);
  assert.match(native, /demo_value\(value as i32\) as c_int/);
  writeFileSync(source, "// @neiv\npub fn typed_score(value: i32): i32 { return value; }\n");
  generate();
  assert.match(
    readFileSync(join(root, "src/generated/neiv_generated_commands.cy"), "utf8"),
    /export c\("neiv_command_typed_score"\)/,
  );
  assert.match(readFileSync(join(root, "web/generated/commands.ts"), "utf8"), /typedScore\(value: number/);
  writeFileSync(
    source,
    '// @neiv {"returns":{"type":"record","fields":{"count":"int32"}}}\n' +
      'pub fn snapshot(): string { return "{\\"count\\":1}"; }\n',
  );
  generate();
  assert.match(
    readFileSync(join(root, "src/generated/neiv_generated_commands.cy"), "utf8"),
    /bytes\.len\(\) >= capacity as usize/,
  );
  writeFileSync(
    source,
    '// @neiv-event {"topic":"demo.changed","payload":{"type":"record","fields":{"count":"int32"}}}\nexport c("demo_value") fn demo_value(value: c_int): c_int { return value; }\n',
  );
  assert.equal(discoverCommands(root).events[0].topic, "demo.changed");
  generate();
  assert.match(
    readFileSync(join(root, "web/generated/events.ts"), "utf8"),
    /"demo.changed": \{ count: number \}/,
  );
  assert.match(readFileSync(join(root, "web/generated/events.d.ts"), "utf8"), /"demo.changed": \{/);
  assert.equal(
    JSON.parse(readFileSync(join(root, "native/generated/events.json"), "utf8"))["demo.changed"].type,
    "record",
  );
  writeFileSync(
    source,
    '// @neiv {"args":{"value":{"type":"boolean"}}}\nexport c("demo_value") fn demo_value(value: c_str): c_double { return 1.0; }\n',
  );
  assert.throws(() => discoverCommands(root), /incompatible bridge type/);
  writeFileSync(source, 'export c("demo_value") fn demo_value(value: *c_char): c_int { return 1; }\n');
  assert.throws(() => discoverCommands(root), /unsupported Cyna bridge type/);
  console.log("Cyna export discovery: passed");
} finally {
  rmSync(root, { recursive: true, force: true });
}
