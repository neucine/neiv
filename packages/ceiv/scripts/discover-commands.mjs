import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const identifier = /^[A-Za-z_][A-Za-z_0-9]*$/;
const camel = name => name.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());
const base = type => {
  if (type === "c_int" || type === "i32") return { type: "int32" };
  if (type === "c_double") return { type: "number" };
  if (type === "c_str") return { type: "string", maxBytes: 65536 };
  throw new Error(`unsupported Cyna bridge type: ${type}`);
};
const compatible = (type, spec) => {
  const kind = typeof spec === "string" ? spec : spec?.type;
  return type === "string" ? ["string", "record", "array", "optional"].includes(kind) :
    ["c_int", "i32"].includes(type) ? ["int32", "boolean"].includes(kind) :
    type === "c_double" ? kind === "number" :
    type === "c_str" ? ["string", "record", "array", "optional"].includes(kind) : false;
};

export function discoverCommands(root) {
  const src = join(root, "src");
  const files = readdirSync(src, { recursive: true }).filter(file => file.endsWith(".cy") && !file.startsWith("generated/") && !["ceiv_callbacks.cy", "ceiv_commands.cy"].includes(file)).sort();
  const commands = [];
  const events = [];
  let configure = null;
  for (const file of files) {
    const source = readFileSync(join(src, file), "utf8");
    const lines = source.split(/\r?\n/);
    for (let index = 0; index < lines.length; index++) {
      const line = lines[index];
      const eventMarker = line.match(/^\s*\/\/\s*@ceiv-event\s+(\{.*\})\s*$/);
      if (eventMarker) {
        const event = JSON.parse(eventMarker[1]);
        if (!event || typeof event.topic !== "string" || !/^[a-z][a-z0-9]*(?:\.[a-z][A-Za-z_0-9]*)+$/.test(event.topic) ||
            !event.payload || typeof event.payload !== "object")
          throw new Error(`${file}:${index + 1}: invalid event declaration`);
        events.push(event);
      }
      const old = line.match(/^\s*export c\("([A-Za-z_][A-Za-z_0-9]*)"\) fn ([A-Za-z_][A-Za-z_0-9]*)\s*\(([^)]*)\)\s*:\s*([^\s{]+)\s*\{/);
      const publicFunction = line.match(/^\s*pub fn ([A-Za-z_][A-Za-z_0-9]*)\s*\(([^)]*)\)\s*:\s*([^\s{]+)\s*\{/);
      if (lines[index - 1]?.trim() === "// @ceiv-configure") {
        if (!publicFunction || publicFunction[2].trim() || publicFunction[3] !== "void" || configure)
          throw new Error(`${file}:${index + 1}: invalid Ceiv configure function`);
        configure = { module: file.slice(0, -3).replaceAll("/", "."), functionName: publicFunction[1] };
        continue;
      }
      const marker = lines[index - 1]?.match(/^\s*\/\/\s*@ceiv\s+(\{.*\})\s*$/);
      const plainMarker = lines[index - 1]?.trim() === "// @ceiv";
      const meta = marker ? JSON.parse(marker[1]) : {};
      const start = old || (publicFunction && (marker || plainMarker) ? [null, `ceiv_command_${publicFunction[1]}`, ...publicFunction.slice(1)] : null);
      if (!start) {
        if (/^\s*export\s+c\b/.test(line) || /@link\.export\s*\(/.test(line))
          throw new Error(`${file}:${index + 1}: unsupported Cyna export spelling; use export c("symbol") fn on one line`);
        continue;
      }
      const [, symbol, functionName, parameterText, resultType] = start;
      if (lines[index - 1]?.trim() === "// @ceiv-callback") continue;
      if (symbol === "ceiv_app_configure") {
        if (parameterText.trim() || resultType !== "void")
          throw new Error(`${file}:${index + 1}: ceiv_app_configure must be fn configure(): void`);
        continue;
      }
      if (Object.keys(meta).some(key => !["name", "binding", "args", "returns"].includes(key)))
        throw new Error(`${file}:${index + 1}: unknown @ceiv metadata field`);
      if (!identifier.test(symbol)) throw new Error(`${file}:${index + 1}: invalid command symbol`);
      const raw = parameterText.trim() ? parameterText.split(",").map(part => {
        const match = part.trim().match(/^([A-Za-z_][A-Za-z_0-9]*):\s*(.+)$/);
        if (!match) throw new Error(`${file}:${index + 1}: unsupported parameter: ${part}`);
        return { name: match[1], type: match[2].trim() };
      }) : [];
      const stringResult = !old && resultType === "string";
      const buffer = stringResult || raw.length >= 2 && raw.at(-2).name === "out" && raw.at(-2).type === "*c_char" &&
        raw.at(-1).name === "capacity" && ["c_int", "i32"].includes(raw.at(-1).type);
      if (buffer && !["c_int", "i32", "string"].includes(resultType)) throw new Error(`${file}:${index + 1}: buffer export must return text or an int32 byte count`);
      const inputs = buffer && !stringResult ? raw.slice(0, -2) : raw;
      const args = inputs.map(param => {
        if (!identifier.test(param.name)) throw new Error(`invalid Cyna parameter: ${param.name}`);
        const override = meta.args?.[param.name];
        if (override && !compatible(param.type, override)) throw new Error(`${file}:${index + 1}: incompatible bridge type for ${param.name}`);
        return { name: param.name, ...(override || base(param.type)) };
      });
      if (meta.args && Object.keys(meta.args).some(name => !inputs.some(input => input.name === name)))
        throw new Error(`${file}:${index + 1}: bridge metadata names a missing parameter`);
      if (!buffer) base(resultType);
      if (buffer && !meta.returns) throw new Error(`${file}:${index + 1}: buffer return needs @ceiv returns metadata`);
      if (!buffer && meta.returns && !compatible(resultType, meta.returns))
        throw new Error(`${file}:${index + 1}: incompatible bridge return type`);
      const binding = meta.binding || camel(functionName);
      const name = meta.name || binding;
      if (!identifier.test(binding) || !/^[A-Za-z_][A-Za-z_0-9]*(?:\.[A-Za-z_][A-Za-z_0-9]*)*$/.test(name))
        throw new Error(`${file}:${index + 1}: invalid command name or binding`);
      commands.push({ name, binding, symbol, args, returns: meta.returns || base(resultType),
        ...(old ? {} : { implementation: { module: file.slice(0, -3).replaceAll("/", "."), functionName,
          parameters: raw, resultType } }) });
    }
  }
  if (!commands.length) throw new Error("no Cyna exports found in src");
  for (const field of ["name", "binding", "symbol"]) {
    const seen = new Set();
    for (const command of commands) {
      if (seen.has(command[field])) throw new Error(`duplicate Cyna command ${field}: ${command[field]}`);
      seen.add(command[field]);
    }
  }
  if (new Set(events.map(event => event.topic)).size !== events.length) throw new Error("duplicate Cyna event topic");
  return { version: 1, commands, events, configure };
}
