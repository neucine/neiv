import { readFileSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";

const app = resolve(process.argv[2] || ".");
const manifest = JSON.parse(readFileSync(join(app, "app.json"), "utf8"));
const safeFile = value =>
  typeof value === "string" &&
  /^[A-Za-z0-9_./-]+$/.test(value) &&
  !value.startsWith("/") &&
  !value.split("/").includes("..") &&
  !value.includes("//");
if (typeof manifest.id !== "string" || !/^[a-z][a-z0-9-]*(\.[a-z][a-z0-9-]*)+$/.test(manifest.id))
  throw new Error("app.id must be a reverse-domain identifier");
if (typeof manifest.name !== "string" || !manifest.name.trim() || manifest.name.length > 80)
  throw new Error("app.name must be 1-80 characters");
if (
  manifest.version !== undefined &&
  (typeof manifest.version !== "string" || !/^\d+\.\d+\.\d+$/.test(manifest.version))
)
  throw new Error("app.version must be major.minor.patch");
if (
  manifest.icon !== undefined &&
  (!safeFile(manifest.icon) || !manifest.icon.endsWith(".icns") || !existsSync(join(app, manifest.icon)))
)
  throw new Error("app.icon must name an existing .icns file");
if (!safeFile(manifest.entry) || !manifest.entry.endsWith(".html")) throw new Error("invalid app.entry");
if (manifest.commands !== undefined)
  throw new Error("app.commands is obsolete; commands are discovered from Cyna exports");
if (
  !Array.isArray(manifest.capabilities) ||
  !manifest.capabilities.every(x => typeof x === "string" && /^[a-z][A-Za-z0-9.]*$/.test(x))
)
  throw new Error("invalid app.capabilities");
const capabilities = new Set([
  "dialog.open",
  "dialog.save",
  "shell.openExternal",
  "clipboard.read",
  "clipboard.write",
  "tray",
  "notification.show",
]);
if (
  manifest.capabilities.some(value => !capabilities.has(value)) ||
  new Set(manifest.capabilities).size !== manifest.capabilities.length
)
  throw new Error("unknown or duplicate app.capabilities entry");
if (manifest.window !== undefined)
  throw new Error("app.window is obsolete; configure the window in Cyna code");
const localHttpServer =
  manifest.localHttp && typeof manifest.localHttp === "object" && !Array.isArray(manifest.localHttp)
    ? manifest.localHttp.server
    : undefined;
if (manifest.localHttp !== undefined && manifest.localHttp !== true && !localHttpServer)
  throw new Error("app.localHttp must be true or contain a server");
if (
  localHttpServer &&
  (!safeFile(localHttpServer.source) ||
    !safeFile(localHttpServer.executable) ||
    !Array.isArray(localHttpServer.args) ||
    !localHttpServer.args.every(
      value => typeof value === "string" && value.length > 0 && value.length <= 256,
    ) ||
    !existsSync(join(app, localHttpServer.source, localHttpServer.executable)))
)
  throw new Error("invalid app.localHttp.server");
if (manifest.localHttp && manifest.nativePlugin !== undefined)
  throw new Error("app.localHttp cannot be combined with nativePlugin");
if (
  manifest.nativePlugin !== undefined &&
  (typeof manifest.nativePlugin !== "string" || !/^[A-Z][A-Za-z0-9_]{0,63}$/.test(manifest.nativePlugin))
)
  throw new Error("invalid native plugin class");
const customPlugin =
  manifest.nativePlugin && !["CynaVideoPlugin", "CynaColorPlugin"].includes(manifest.nativePlugin);
if (
  manifest.nativeSources !== undefined &&
  (!Array.isArray(manifest.nativeSources) ||
    manifest.nativeSources.length > 32 ||
    !manifest.nativeSources.every(
      value => safeFile(value) && value.endsWith(".m") && existsSync(join(app, value)),
    ) ||
    new Set(manifest.nativeSources).size !== manifest.nativeSources.length)
)
  throw new Error("invalid native sources");
if (
  manifest.nativeFrameworks !== undefined &&
  (!Array.isArray(manifest.nativeFrameworks) ||
    manifest.nativeFrameworks.length > 16 ||
    !manifest.nativeFrameworks.every(
      value => typeof value === "string" && /^[A-Za-z][A-Za-z0-9]{0,63}$/.test(value),
    ) ||
    new Set(manifest.nativeFrameworks).size !== manifest.nativeFrameworks.length)
)
  throw new Error("invalid native frameworks");
if (customPlugin && !manifest.nativeSources?.length)
  throw new Error("custom native plugin requires nativeSources");
if (!customPlugin && (manifest.nativeSources?.length || manifest.nativeFrameworks?.length))
  throw new Error("nativeSources and nativeFrameworks require a custom native plugin");
if (
  manifest.resources !== undefined &&
  (!Array.isArray(manifest.resources) ||
    !manifest.resources.every(
      item =>
        item &&
        safeFile(item.source) &&
        safeFile(item.target) &&
        existsSync(join(app, item.source)) &&
        !item.target.startsWith("web/"),
    ))
)
  throw new Error("invalid app.resources");
console.log(`${manifest.id}: manifest ok`);
