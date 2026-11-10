#!/usr/bin/env node
import { existsSync, mkdirSync, rmSync, watch, writeFileSync } from "node:fs";
import { dirname, basename, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn, spawnSync } from "node:child_process";

const repo = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const command = process.argv[2];
const args = process.argv.slice(3);
const usage = "Usage: neiv new <directory> [--id dev.example.app] | build [directory] | run [directory] | check [directory] | dev [directory] | package [directory] [--sign identity] [--notarize-profile profile]";
function run(program, parameters, cwd) {
  const result = spawnSync(program, parameters, { cwd, stdio: "inherit", env: process.env });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
function appPath(value) { return resolve(value || "."); }
function packageOptions(values) {
  let directory, sign, profile;
  for (let index = 0; index < values.length; index++) {
    const value = values[index];
    if (value === "--sign" || value === "--notarize-profile") {
      const argument = values[++index];
      if (!argument || argument.startsWith("--")) throw new Error(`${value} requires a value`);
      if (value === "--sign") { if (sign) throw new Error("duplicate --sign"); sign = argument; }
      else { if (profile) throw new Error("duplicate --notarize-profile"); profile = argument; }
    } else if (!value.startsWith("--") && directory === undefined) directory = value;
    else throw new Error(usage);
  }
  if (profile && (!sign || sign === "-")) throw new Error("notarization requires a Developer ID signing identity");
  return { root: appPath(directory), sign, profile };
}
function packageApp(root, sign, profile) {
  run("sh", [join(repo, "app-build.sh"), root]);
  const bundle = join(root, "build/NeivApp.app");
  const archive = join(root, "build/NeivApp.zip");
  if (sign) {
    const parameters = ["--force", "--options", "runtime"];
    if (sign !== "-") parameters.push("--timestamp");
    run("codesign", [...parameters, "--sign", sign, bundle]);
    run("codesign", ["--verify", "--strict", "--verbose=2", bundle]);
  }
  const archiveApp = () => {
    rmSync(archive, { force: true });
    run("ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", "NeivApp.app", "NeivApp.zip"], join(root, "build"));
  };
  archiveApp();
  if (profile) {
    run("xcrun", ["notarytool", "submit", archive, "--keychain-profile", profile, "--wait"]);
    run("xcrun", ["stapler", "staple", bundle]);
    run("xcrun", ["stapler", "validate", bundle]);
    archiveApp();
  }
  console.log(`Package ready: ${archive}`);
}
function dev(root) {
  let appProcess = null, building = false, queued = false, timer = null;
  const watchers = [];
  const build = () => {
    if (building) { queued = true; return; }
    building = true;
    console.log(`Neiv rebuilding ${root}`);
    const task = spawn("sh", [join(repo, "app-build.sh"), root], { stdio: "inherit" });
    task.on("error", error => { console.error(`neiv dev: ${error.message}`); building = false; });
    task.on("exit", code => {
      building = false;
      if (code === 0) {
        if (appProcess) appProcess.kill("SIGTERM");
        appProcess = spawn(join(root, "build/NeivApp.app/Contents/MacOS/NeivApp"), [], { stdio: "inherit" });
        appProcess.on("error", error => console.error(`neiv dev: ${error.message}`));
        console.log("Neiv app restarted");
      } else console.error(`Neiv build failed (${code}); watching for changes`);
      if (queued) { queued = false; build(); }
    });
  };
  for (const directory of ["src", "web"]) {
    const target = join(root, directory);
    if (!existsSync(target)) continue;
    watchers.push(watch(target, { recursive: true }, (_kind, name) => {
      if (name?.split(/[\\/]/).includes("generated")) return;
      clearTimeout(timer);
      timer = setTimeout(build, 250);
    }));
  }
  for (const file of ["app.json", "cyna.toml"]) {
    const target = join(root, file);
    if (existsSync(target)) watchers.push(watch(target, () => { clearTimeout(timer); timer = setTimeout(build, 250); }));
  }
  const stop = () => { clearTimeout(timer); watchers.forEach(watcher => watcher.close()); if (appProcess) appProcess.kill("SIGTERM"); process.exit(0); };
  process.on("SIGINT", stop); process.on("SIGTERM", stop);
  build();
}
function create() {
  if (!args[0] || args.length > 3 || (args.length > 1 && (args[1] !== "--id" || !args[2])))
    throw new Error(usage);
  const root = appPath(args[0]);
  if (existsSync(root)) throw new Error(`destination already exists: ${root}`);
  const slug = basename(root).toLowerCase().replace(/[^a-z0-9-]+/g, "-").replace(/^-+|-+$/g, "");
  if (!/^[a-z][a-z0-9-]*$/.test(slug)) throw new Error("directory name must start with a letter");
  const id = args[2] || `dev.local.${slug}`;
  if (!/^[a-z][a-z0-9-]*(\.[a-z][a-z0-9-]*)+$/.test(id)) throw new Error("invalid app ID");
  const packageName = slug.replaceAll("-", "_");
  const title = slug.replaceAll("-", " ").replace(/\b\w/g, letter => letter.toUpperCase());
  mkdirSync(join(root, "src"), { recursive: true });
  mkdirSync(join(root, "web"));
  writeFileSync(join(root, "app.json"), JSON.stringify({
    id, name: title, entry: "index.html", capabilities: [],
  }, null, 2) + "\n");
  writeFileSync(join(root, ".gitignore"), "/build/\n/web/generated/\n/native/generated/\n/cyna.lock\n");
  writeFileSync(join(root, "cyna.toml"), `name = "${packageName}"\nversion = "0.1.3"\nsrc = "src"\ntype = "staticlib"\nentry = "src/lib.cy"\n\n[dependencies]\nneiv = { version = "0.1.3" }\n\n[build]\ntarget = "native"\nopt = "release"\n`);
  writeFileSync(join(root, "src/lib.cy"), `import { configure_window } from neiv.lib;\n\nexport c("neiv_app_configure") fn configure(): void {\n    const configured = configure_window(${JSON.stringify(title)}, 720, 480);\n}\n\nexport c("${packageName}_increment") fn increment(value: c_int): c_int {\n    return value + 1;\n}\n`);
  writeFileSync(join(root, "web/App.weiv"), `<template>\n  <main>\n    <h1>${title}</h1>\n    <p>{{ count }}</p>\n    <button @click="increase">Increment with Cyna</button>\n    <p role="status">{{ status }}</p>\n  </main>\n</template>\n<script lang="ts">\n  import { increment } from "./generated/commands.ts";\n  let count = 0;\n  let status = "Ready";\n  async function increase() {\n    try {\n      const next = await increment(count);\n      weivUpdate(() => { count = next; status = "Cyna returned " + next; });\n    } catch (error) {\n      weivUpdate(() => { status = (error as Error).message; });\n    }\n  }\n</script>\n<style>\n  body { font: 18px -apple-system, sans-serif; }\n  main { max-width: 48rem; margin: 4rem auto; }\n</style>\n`);
  run(process.execPath, [join(repo, "scripts/generate-commands.mjs"), root]);
  run(process.execPath, [join(repo, "scripts/generate-callbacks.mjs"), root]);
  run(process.execPath, [join(repo, "scripts/prepare-cyna.mjs"), root]);
  console.log(`Created ${root}`);
}
try {
  if (command === "new") create();
  else if (command === "package") {
    const options = packageOptions(args);
    packageApp(options.root, options.sign, options.profile);
  }
  else if (["build", "run", "check", "dev"].includes(command) && args.length <= 1) {
    const root = appPath(args[0]);
    if (command === "dev") dev(root);
    else if (command === "check") {
      run("sh", [join(repo, "scripts/ensure-cyna-package.sh")]);
      run(process.execPath, [join(repo, "scripts/validate-app.mjs"), root]);
      run(process.execPath, [join(repo, "scripts/generate-commands.mjs"), root]);
      run(process.execPath, [join(repo, "scripts/generate-callbacks.mjs"), root]);
      run(process.execPath, [join(repo, "scripts/prepare-cyna.mjs"), root]);
      run("cyna", ["install", "build/cyna.toml"], root);
      run("cyna", ["check", "build/cyna.toml"], root);
      console.log(`Neiv check passed: ${root}`);
    } else {
      run("sh", [join(repo, "app-build.sh"), root]);
      if (command === "run") run("open", ["-n", join(root, "build/NeivApp.app")]);
    }
  } else {
    throw new Error(usage);
  }
} catch (error) {
  console.error(`neiv: ${error.message}`);
  process.exitCode = 1;
}
