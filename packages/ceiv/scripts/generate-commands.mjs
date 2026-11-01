import { writeFileSync, readFileSync, mkdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { discoverCommands } from "./discover-commands.mjs";

const check = process.argv[2] === "--check";
const appArg = process.argv[check ? 3 : 2];
if (!appArg) throw new Error("usage: generate-commands.mjs [--check] <app-directory>");
const root = resolve(appArg);
const schema = discoverCommands(root);
if (schema.version !== 1 || !Array.isArray(schema.commands)) throw new Error("unsupported command schema");
const identifier = /^[A-Za-z_][A-Za-z_0-9]*$/;
const reservedKeys = new Set(["__proto__", "prototype", "constructor"]);
const commandName = /^[A-Za-z_][A-Za-z_0-9]*(\.[A-Za-z_][A-Za-z_0-9]*)*$/;
const events = Object.fromEntries(schema.events.map(event => {
  if (event.topic === "app.windows" || event.topic === "app.lifecycle" || !commandName.test(event.topic)) throw new Error(`invalid event topic: ${event.topic}`);
  return [event.topic, descriptor(event.payload)];
}));
const names = new Set();
const bindings = new Set();
function descriptor(raw, depth = 0) {
  if (depth > 8) throw new Error("command type nesting exceeds 8");
  const spec = typeof raw === "string" ? { type: raw } : raw;
  if (!spec || typeof spec !== "object" || Array.isArray(spec)) throw new Error("invalid type descriptor");
  const { type } = spec;
  if (type === "int32" || type === "number") {
    const lower = type === "int32" ? -2147483648 : -1e12;
    const upper = type === "int32" ? 2147483647 : 1e12;
    const min = spec.min ?? lower, max = spec.max ?? upper;
    if (!Number.isFinite(min) || !Number.isFinite(max) || min > max || min < lower || max > upper ||
        (type === "int32" && (!Number.isInteger(min) || !Number.isInteger(max)))) throw new Error("invalid numeric bounds");
    return { type, min, max };
  }
  if (type === "boolean") return { type };
  if (type === "string") {
    if (!Number.isInteger(spec.maxBytes) || spec.maxBytes < 1 || spec.maxBytes > 65536) throw new Error("string needs maxBytes 1-65536");
    return { type, maxBytes: spec.maxBytes };
  }
  if (type === "optional") return { type, value: descriptor(spec.value, depth + 1) };
  if (type === "array") {
    if (!Number.isInteger(spec.maxItems) || spec.maxItems < 0 || spec.maxItems > 1024) throw new Error("invalid maxItems");
    return { type, maxItems: spec.maxItems, items: descriptor(spec.items, depth + 1) };
  }
  if (type === "record") {
    if (!spec.fields || typeof spec.fields !== "object" || Array.isArray(spec.fields) ||
        Object.keys(spec.fields).length > 64) throw new Error("invalid record fields");
    const fields = {};
    for (const [key, value] of Object.entries(spec.fields)) {
      if (!identifier.test(key) || reservedKeys.has(key)) throw new Error(`invalid record field: ${key}`);
      fields[key] = descriptor(value, depth + 1);
    }
    return { type, fields };
  }
  throw new Error(`unsupported command type: ${type}`);
}
function tsType(spec) {
  switch (spec.type) {
    case "int32": case "number": return "number";
    case "boolean": return "boolean";
    case "string": return "string";
    case "optional": return `${tsType(spec.value)} | null | undefined`;
    case "array": return `Array<${tsType(spec.items)}>`;
    case "record": return `{ ${Object.entries(spec.fields).map(([key, value]) => `${key}${value.type === "optional" ? "?" : ""}: ${tsType(value)}`).join("; ")} }`;
  }
}
function objcLiteral(value) {
  if (typeof value === "string") return `@${JSON.stringify(value)}`;
  if (typeof value === "number") return `@(${value})`;
  if (Array.isArray(value)) return `@[${value.map(objcLiteral).join(", ")}]`;
  return `@{${Object.entries(value).map(([key, item]) => `${objcLiteral(key)}: ${objcLiteral(item)}`).join(", ")}}`;
}
function abiType(spec) {
  if (spec.type === "int32" || spec.type === "boolean") return "int";
  if (spec.type === "number") return "double";
  return "const char *";
}
function bufferReturn(spec) { return !["int32", "boolean", "number"].includes(spec.type); }
for (const command of schema.commands) {
  if (!commandName.test(command.name) || !identifier.test(command.binding) ||
      !identifier.test(command.symbol) || !Array.isArray(command.args) ||
      names.has(command.name) || bindings.has(command.binding))
    throw new Error(`unsupported command: ${JSON.stringify(command)}`);
  names.add(command.name); bindings.add(command.binding);
  command.returnType = descriptor(command.returns);
  const argNames = new Set();
  for (const arg of command.args) {
    if (!identifier.test(arg.name) || reservedKeys.has(arg.name) || argNames.has(arg.name)) throw new Error(`invalid argument: ${JSON.stringify(arg)}`);
    argNames.add(arg.name);
    arg.spec = descriptor(arg);
  }
}

const objc = [`// Generated from Cyna exports. Do not edit.`,
`#import "command_validation.h"`,
`#include <math.h>`,
`#include <string.h>`,
...schema.commands.map(command => `extern ${bufferReturn(command.returnType) ? "int" : abiType(command.returnType)} ${command.symbol}(${[...command.args.map(arg => abiType(arg.spec)), ...(bufferReturn(command.returnType) ? ["char *", "int"] : [])].join(", ") || "void"});`),
`static id dispatch_command(NSString *command, NSDictionary *args, NSDictionary **error) {`,
`    if (![args isKindOfClass:NSDictionary.class]) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }`];
for (const command of schema.commands) {
  objc.push(`    if ([command isEqualToString:@${JSON.stringify(command.name)}]) {`);
  objc.push(`        if (args.count > ${command.args.length}) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }`);
  for (const arg of command.args) {
    const key = `@${JSON.stringify(arg.name)}`;
    objc.push(`        id ${arg.name}_raw = args[${key}];`);
    objc.push(`        if (!CynaCommandValid(${arg.name}_raw, ${objcLiteral(arg.spec)}, 0)) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Invalid command arguments"); return nil; }`);
    switch (arg.spec.type) {
      case "int32": case "boolean": objc.push(`        int ${arg.name} = [${arg.name}_raw intValue];`); break;
      case "number": objc.push(`        double ${arg.name} = [${arg.name}_raw doubleValue];`); break;
      case "string": objc.push(`        const char *${arg.name} = [${arg.name}_raw UTF8String];`); break;
      default:
        objc.push(`        NSData *${arg.name}_data = [NSJSONSerialization dataWithJSONObject:${arg.name}_raw ?: NSNull.null options:NSJSONWritingFragmentsAllowed error:nil];`);
        objc.push(`        NSString *${arg.name}_json = [[NSString alloc] initWithData:${arg.name}_data encoding:NSUTF8StringEncoding];`);
        objc.push(`        if (!${arg.name}_json || ${arg.name}_data.length > 65536) { *error = CynaCommandError(@"INVALID_ARGUMENT", @"Command arguments too large"); return nil; }`);
        objc.push(`        const char *${arg.name} = [${arg.name}_json UTF8String];`);
    }
  }
  const outputArgs = bufferReturn(command.returnType) ? ["out", "65536"] : [];
  const call = `${command.symbol}(${[...command.args.map(arg => arg.name), ...outputArgs].join(", ")})`;
  if (bufferReturn(command.returnType)) objc.push(`        char out[65536] = {0};`);
  switch (command.returnType.type) {
    case "int32":
      objc.push(`        id result = @(${call});`); break;
    case "boolean":
      objc.push(`        int raw = ${call}; id result = raw == 0 || raw == 1 ? @((BOOL)raw) : nil;`); break;
    case "number":
      objc.push(`        double raw = ${call}; id result = isfinite(raw) ? @(raw) : nil;`); break;
    case "string":
      objc.push(`        int count = ${call};`);
      objc.push(`        id result = count >= 0 && count <= 65536 ? [[NSString alloc] initWithBytes:out length:(NSUInteger)count encoding:NSUTF8StringEncoding] : nil;`); break;
    default:
      objc.push(`        int count = ${call};`);
      objc.push(`        id result = nil;`);
      objc.push(`        if (count >= 0 && count <= 65536) { NSData *data = [NSData dataWithBytes:out length:(NSUInteger)count]; result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil]; }`);
  }
  objc.push(`        if (!CynaCommandValid(result, ${objcLiteral(command.returnType)}, 0)) { *error = CynaCommandError(@"INVALID_RESULT", @"Invalid native command result"); return nil; }`);
  objc.push(`        return result;`);
  objc.push(`    }`);
}
objc.push(`    *error = CynaCommandError(@"UNKNOWN_COMMAND", @"Unsupported command"); return nil;`, `}`);

const commandSource = [
  "// Generated from Cyna command exports. Do not edit.",
  'import { invoke } from "ceiv/sdk";',
  'import type { InvokeOptions } from "ceiv/sdk";',
  ...schema.commands.flatMap(command => {
    const params = [...command.args.map(arg => `${arg.name}: ${tsType(arg.spec)}`), "options?: InvokeOptions"].join(", ");
    const entries = command.args.map(arg => arg.name).join(", ");
    const argSpecs = Object.fromEntries(command.args.map(arg => [arg.name, arg.spec]));
    return [`export function ${command.binding}(${params}): Promise<${tsType(command.returnType)}> {`,
      `  return invoke(${JSON.stringify(command.name)}, { ${entries} }, ${JSON.stringify(argSpecs)}, ${JSON.stringify(command.returnType)}, options) as Promise<${tsType(command.returnType)}>;`, "}"];
  }),
].join("\n") + "\n";
const commandDeclaration = [
  "// Generated from Cyna command exports. Do not edit.",
  'import type { InvokeOptions } from "ceiv/sdk";',
  ...schema.commands.map(command => {
    const params = [...command.args.map(arg => `${arg.name}: ${tsType(arg.spec)}`), "options?: InvokeOptions"].join(", ");
    return `export declare function ${command.binding}(${params}): Promise<${tsType(command.returnType)}>;`;
  }),
].join("\n") + "\n";
const eventFields = Object.entries(events).map(([topic, spec]) =>
  `    ${JSON.stringify(topic)}: ${tsType(spec)};`);
const eventAugmentation = eventFields.length ? [
  'declare module "ceiv/sdk" {',
  "  interface NativeEvents {",
  ...eventFields,
  "  }",
  "}",
] : [];
const eventSource = [
  "// Generated from Cyna event declarations. Do not edit.",
  'import { configureEvents, events } from "ceiv/sdk";',
  ...eventAugmentation,
  `configureEvents(${JSON.stringify(events)});`,
  "export { events };",
].join("\n") + "\n";
const eventDeclaration = [
  "// Generated from Cyna event declarations. Do not edit.",
  'export { events } from "ceiv/sdk";',
  ...eventAugmentation,
].join("\n") + "\n";
const outputs = [
  ["web/generated/commands.ts", commandSource],
  ["web/generated/commands.d.ts", commandDeclaration],
  ["web/generated/events.ts", eventSource],
  ["web/generated/events.d.ts", eventDeclaration],
  ["native/generated/dispatch.inc", objc.join("\n") + "\n"],
  ["native/generated/events.json", JSON.stringify(events, null, 2) + "\n"],
];
for (const [path, content] of outputs) {
  const target = join(root, path);
  if (check) {
    if (readFileSync(target, "utf8") !== content) throw new Error(`generated file drift: ${target}`);
  } else {
    mkdirSync(join(root, path.substring(0, path.lastIndexOf("/"))), { recursive: true });
    writeFileSync(target, content);
  }
}
