import { strict as assert } from "node:assert";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const root = mkdtempSync(join(tmpdir(), "ceiv-callbacks-"));
const generator = resolve("packages/ceiv/scripts/generate-callbacks.mjs");
const run = (...args) => spawnSync(process.execPath, [generator, ...args], { encoding: "utf8" });
try {
  mkdirSync(join(root, "src"));
  writeFileSync(join(root, "src/provider.cy"),
    '// @ceiv-callback\npub fn decode(bytes: *const c_uchar, length: c_size_t): c_int { return 0; }\n');
  assert.equal(run(root).status, 0);
  const generated = readFileSync(join(root, "src/generated/ceiv_generated_callbacks.cy"), "utf8");
  assert.match(generated, /export c\("ceiv_callback_decode"\) fn/);
  assert.match(generated, /provider\.decode\(bytes, length\)/);
  assert.equal(run("--check", root).status, 0);
  writeFileSync(join(root, "src/provider.cy"),
    '// @ceiv-callback\npub fn decode(bytes: *const u8, length: usize, output: *u8, width: *u32): i32 { return 0; }\n');
  assert.equal(run(root).status, 0);
  const typed = readFileSync(join(root, "src/generated/ceiv_generated_callbacks.cy"), "utf8");
  assert.match(typed, /bytes: \*const c_uchar, length: c_size_t, output: \*c_uchar, width: \*c_uint\): c_int/);
  assert.match(typed, /provider\.decode\(bytes as! \*const u8, length as usize, output as! \*u8, width as! \*u32\) as c_int/);
  assert.equal(run("--check", root).status, 0);
  writeFileSync(join(root, "src/provider.cy"),
    '// @ceiv-callback\npub fn decode(input: native_buffer.ReadBuffer, output: native_buffer.WriteBuffer): i32 { return 0; }\n');
  assert.equal(run(root).status, 0);
  const buffers = readFileSync(join(root, "src/generated/ceiv_generated_callbacks.cy"), "utf8");
  assert.match(buffers, /input_ptr: \*const c_uchar, input_len: c_size_t, output_ptr: \*c_uchar, output_len: c_size_t/);
  assert.match(buffers, /if \(input_ptr as! usize\) == 0 \{\n        return 1;\n    \}/);
  assert.match(buffers, /if \(output_ptr as! usize\) == 0 \{\n        return 1;\n    \}/);
  assert.match(buffers, /const input: native_buffer\.ReadBuffer = \{\n        pointer: input_ptr as! \*const u8,\n        length: input_len as usize\n    \};/);
  assert.match(buffers, /provider\.decode\(input, output\) as c_int/);
  assert.equal(run("--check", root).status, 0);
  writeFileSync(join(root, "src/provider.cy"),
    '// @ceiv-callback\npub fn decode(input: native_buffer.ReadBuffer): i32 { return 0; }\n');
  assert.equal(run(root).status, 0);
  assert.match(readFileSync(join(root, "src/generated/ceiv_generated_callbacks.cy"), "utf8"), /export c\("ceiv_callback_decode"\)/);
  assert.match(readFileSync(join(root, "native/generated/ceiv_callbacks.h"), "utf8"), /int ceiv_callback_decode\(const void \*input_ptr, size_t input_len\);/);
  writeFileSync(join(root, "src/provider.cy"),
    '// @ceiv-callback\npub fn decode(input: native_buffer.ReadBuffer): void {}\n');
  assert.match(run(root).stderr, /borrowed buffers require an i32 status result/);
  writeFileSync(join(root, "src/provider.cy"),
    '// @ceiv-callback\npub fn decode(input: native_buffer.ReadBuffer, input_len: usize): i32 { return 0; }\n');
  assert.match(run(root).stderr, /duplicate ABI names/);
  writeFileSync(join(root, "src/provider.cy"),
    '// @ceiv-callback\nexport c("legacy_callback") fn legacy(): c_int { return 0; }\n');
  assert.equal(run(root).status, 0);
  assert.doesNotMatch(readFileSync(join(root, "src/generated/ceiv_generated_callbacks.cy"), "utf8"), /legacy_callback/);
  writeFileSync(join(root, "src/provider.cy"),
    '// @ceiv-callback\npub fn decode(bytes: *const f32): i32 { return 0; }\n');
  assert.match(run(root).stderr, /unsupported callback parameter/);
  writeFileSync(join(root, "src/provider.cy"),
    '// @ceiv-callback\npub fn decode(bytes: *const c_uchar, length: c_size_t): c_int { return 0; }\n' +
    '// @ceiv-callback\npub fn decode(): void {}\n');
  assert.match(run(root).stderr, /duplicate native callback symbol/);
  writeFileSync(join(root, "src/provider.cy"), "pub fn no_callback(): void {}\n");
  mkdirSync(join(root, "src/dng"));
  writeFileSync(join(root, "src/dng/provider.cy"),
    '// @ceiv-callback\npub fn decode(): i32 { return 0; }\n');
  assert.equal(run(root).status, 0);
  assert.match(readFileSync(join(root, "src/generated/ceiv_generated_callbacks.cy"), "utf8"), /import \.dng\.provider;/);
  assert.match(readFileSync(join(root, "src/generated/ceiv_generated_callbacks.cy"), "utf8"), /return provider\.decode\(\) as c_int;/);
  rmSync(join(root, "src/dng"), { recursive: true });
  assert.equal(run(root).status, 0);
  rmSync(join(root, "src/generated/ceiv_generated_callbacks.cy"));
  assert.equal(run("--check", root).status, 0);
} finally {
  rmSync(root, { recursive: true, force: true });
}
