import assert from "node:assert/strict";
import { dirname, join } from "node:path";
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from "node:fs";
import { pathToFileURL } from "node:url";

const messages = [];
const listeners = new Map();
const documentListeners = new Map();
globalThis.document = {
  addEventListener(name, handler) {
    documentListeners.set(name, handler);
  },
};
globalThis.window = {
  webkit: {
    messageHandlers: {
      cyna: {
        postMessage(value) {
          messages.push(value);
        },
      },
    },
  },
  addEventListener(name, handler) {
    listeners.set(name, handler);
  },
};
const generated = dirname(process.argv[2]);
const fixture = mkdtempSync(
  join(dirname(new URL(import.meta.url).pathname), "../packages/neiv/.bridge-test-"),
);
process.on("exit", () => rmSync(fixture, { recursive: true, force: true }));
for (const name of ["commands", "events"]) {
  const source = readFileSync(join(generated, `${name}.js`), "utf8")
    .replaceAll('"/__weiv_packages/@neucine/neiv/sdk.js"', '"@neucine/neiv/sdk"')
    .replaceAll('"/__weiv_packages/@neucine/neiv/sdk"', '"@neucine/neiv/sdk"');
  writeFileSync(join(fixture, `${name}.js`), source);
}
const { doubleValue, scoreText, sizePayload, labelText, halfValue, invert, summary } = await import(
  pathToFileURL(join(fixture, "commands.js")).href
);
const {
  CynaError,
  currentWindow,
  setCloseHandler,
  createActionContext,
  popupContextMenu,
  dialogs,
  shell,
  clipboard,
} = await import(
  pathToFileURL(join(dirname(new URL(import.meta.url).pathname), "../packages/neiv/dist/sdk.js")).href
);
const { events } = await import(pathToFileURL(join(fixture, "events.js")).href);
const beforeHandshake = doubleValue(3);
assert.deepEqual(messages, [{ kind: "hello" }]);
window.cynaHandshake({ protocol: 1, window: "window-a", handle: 1, generation: 1 });
await Promise.resolve();
assert.deepEqual(messages[1], {
  protocol: 1,
  window: "window-a",
  handle: 1,
  generation: 1,
  id: 1,
  kind: "invoke",
  command: "math.double",
  args: { value: 3 },
  deadlineMs: 10000,
});
window.cynaReply({ id: 1, ok: true, value: 6 });
assert.equal(await beforeHandshake, 6);

await assert.rejects(scoreText("a".repeat(65), true, 2), error => error.code === "INVALID_ARGUMENT");
await assert.rejects(scoreText("Cyna", 1, 2), error => error.code === "INVALID_ARGUMENT");
await assert.rejects(scoreText("Cyna", true, Infinity), error => error.code === "INVALID_ARGUMENT");
await assert.rejects(
  sizePayload({ title: "x", flags: [true, false, true, false, true] }),
  error => error.code === "INVALID_ARGUMENT",
);
const score = scoreText("Cyna", true, 2);
await Promise.resolve();
window.cynaReply({ id: 2, ok: true, value: 8 });
assert.equal(await score, 8);
const payload = sizePayload({ title: "x", flags: [true], note: null });
await Promise.resolve();
window.cynaReply({ id: 3, ok: true, value: 45 });
assert.equal(await payload, 45);
const label = labelText();
await Promise.resolve();
window.cynaReply({ id: 4, ok: true, value: "Cyna OK" });
assert.equal(await label, "Cyna OK");
const half = halfValue(9);
await Promise.resolve();
window.cynaReply({ id: 5, ok: true, value: 4.5 });
assert.equal(await half, 4.5);
const inverted = invert(true);
await Promise.resolve();
window.cynaReply({ id: 6, ok: true, value: false });
assert.equal(await inverted, false);
const rejected = doubleValue(2);
await Promise.resolve();
window.cynaReply({ id: 7, ok: false, error: { code: "INVALID_ARGUMENT", message: "bad input" } });
await assert.rejects(rejected, error => error instanceof CynaError && error.code === "INVALID_ARGUMENT");

const controller = new AbortController();
const cancelled = doubleValue(4, { signal: controller.signal });
await Promise.resolve();
controller.abort();
await assert.rejects(cancelled, error => error instanceof CynaError && error.code === "CANCELLED");
assert.equal(messages.at(-1).kind, "cancel");
window.cynaReply({ id: 8, ok: true, value: 8 });

const invalidated = doubleValue(5);
await Promise.resolve();
window.cynaInvalidate("page navigated");
await assert.rejects(invalidated, error => error instanceof CynaError && error.code === "INVALIDATED");
window.cynaReply({ id: 9, ok: true, value: 10 });
const waiting = doubleValue(6);
window.cynaInvalidate("window closed");
await assert.rejects(waiting, error => error instanceof CynaError && error.code === "INVALIDATED");
window.cynaHandshake({ protocol: 1, window: "window-b", handle: 2, generation: 2 });
const observed = [];
const subscribed = events.subscribe("app.windows", event => observed.push(event));
await Promise.resolve();
assert.equal(messages.at(-1).kind, "subscribe");
window.cynaReply({ id: 10, ok: true, value: "subscription-a" });
const unsubscribe = await subscribed;
window.cynaEvent({
  topic: "app.windows",
  subscriptionId: "subscription-a",
  sequence: 1,
  payload: { state: "opened", window: 3 },
});
window.cynaEvent({
  topic: "app.windows",
  subscriptionId: "subscription-a",
  sequence: 2,
  payload: { state: "resized", window: 3, width: "bad", height: 400 },
});
window.cynaEvent({
  topic: "app.windows",
  subscriptionId: "subscription-a",
  sequence: 1,
  payload: { state: "stale", window: 3 },
});
assert.deepEqual(observed, [{ state: "opened", window: 3 }]);
window.cynaEvent({
  topic: "app.windows",
  subscriptionId: "subscription-a",
  sequence: 3,
  payload: { state: "resized", window: 3, width: 640, height: 400 },
});
assert.deepEqual(observed[1], { state: "resized", window: 3, width: 640, height: 400 });
unsubscribe();
assert.equal(messages.at(-1).kind, "unsubscribe");
window.cynaEvent({
  topic: "app.windows",
  subscriptionId: "subscription-a",
  sequence: 2,
  payload: { state: "closed", window: 3 },
});
assert.equal(observed.length, 2);
const composite = summary();
await Promise.resolve();
window.cynaReply({ id: 12, ok: true, value: { message: "ok", values: [1, 2], enabled: true } });
assert.deepEqual(await composite, { message: "ok", values: [1, 2], enabled: true });
const once = events.once("app.windows");
await Promise.resolve();
assert.equal(messages.at(-1).topic, "app.windows");
window.cynaReply({ id: 13, ok: true, value: "subscription-b" });
for (let i = 0; i < 8; i++) await Promise.resolve();
window.cynaEvent({
  topic: "app.windows",
  subscriptionId: "subscription-b",
  sequence: 1,
  payload: { state: "opened", window: 4 },
});
assert.deepEqual(await once, { state: "opened", window: 4 });
assert.equal(messages.at(-1).kind, "unsubscribe");
const invalidatedOnce = events.once("app.windows");
await Promise.resolve();
window.cynaReply({ id: 15, ok: true, value: "subscription-c" });
for (let i = 0; i < 8; i++) await Promise.resolve();
window.cynaInvalidate("test reset");
await assert.rejects(invalidatedOnce, error => error instanceof CynaError && error.code === "INVALIDATED");
const incompatible = doubleValue(1);
window.cynaHandshake({ protocol: 2, window: "window-b", handle: 2, generation: 3 });
await assert.rejects(incompatible, error => error instanceof CynaError && error.code === "PROTOCOL_MISMATCH");
window.cynaHandshake({ protocol: 1, window: "window-c", handle: 3, generation: 4 });
assert.equal(await currentWindow(), 3);
const customEvents = [];
const customSubscription = events.subscribe("hello.updated", event => customEvents.push(event));
await Promise.resolve();
const customRequest = messages.at(-1);
assert.equal(customRequest.topic, "hello.updated");
window.cynaReply({ id: customRequest.id, ok: true, value: "subscription-custom" });
const stopCustom = await customSubscription;
window.cynaEvent({
  topic: "hello.updated",
  subscriptionId: "subscription-custom",
  sequence: 1,
  payload: { message: 123 },
});
assert.deepEqual(customEvents, []);
window.cynaEvent({
  topic: "hello.updated",
  subscriptionId: "subscription-custom",
  sequence: 3,
  payload: { message: "new" },
});
window.cynaEvent({
  topic: "hello.updated",
  subscriptionId: "subscription-custom",
  sequence: 2,
  payload: { message: "old" },
});
assert.deepEqual(customEvents, [{ message: "new" }]);
stopCustom();

let appRuns = 0,
  viewRuns = 0,
  focused = false,
  lastAction,
  lastViewAction;
const element = {
  matches() {
    return focused;
  },
  isConnected: true,
  getBoundingClientRect() {
    return { left: 10, bottom: 20 };
  },
};
const appContext = createActionContext({
  scope: "app",
  actions: {
    "demo.action": {
      run(invocation) {
        appRuns++;
        lastAction = invocation;
      },
    },
  },
});
const viewContext = createActionContext({
  scope: "view",
  element,
  actions: {
    "demo.action": {
      run(invocation) {
        viewRuns++;
        lastViewAction = invocation;
      },
    },
  },
});
appContext.activate();
viewContext.activate();
await window.cynaAction({ id: "demo.action", source: "menu", window: 3, data: null, requestId: "action-a" });
assert.equal(appRuns, 1);
assert.deepEqual(lastAction, { id: "demo.action", source: "menu", window: 3, data: null });
focused = true;
documentListeners.get("focusin")();
await window.cynaAction({
  id: "demo.action",
  source: "shortcut",
  window: 3,
  data: null,
  requestId: "action-b",
});
assert.equal(viewRuns, 1);
await window.cynaAction({
  id: "demo.action",
  source: "context",
  window: 3,
  data: { text: "x" },
  requestId: "action-context",
});
assert.deepEqual(lastViewAction, { id: "demo.action", source: "context", window: 3, data: { text: "x" } });
viewContext.update("demo.action", { enabled: false });
await window.cynaAction({
  id: "demo.action",
  source: "context",
  window: 3,
  data: { text: "x" },
  requestId: "action-c",
});
assert.equal(viewRuns, 2);
assert.equal(appRuns, 1);
viewContext.dispose();
appContext.dispose();
assert.equal(messages.at(-1).kind, "action-state");
assert.deepEqual(messages.at(-1).states, {});

const popup = popupContextMenu("demo.context", { element });
await Promise.resolve();
const popupRequest = messages.at(-1);
assert.equal(popupRequest.command, "__neiv.context.popup");
window.cynaReply({ id: popupRequest.id, ok: true, value: "demo.action" });
assert.equal(await popup, "demo.action");
const confirm = dialogs.confirm("Continue?");
await Promise.resolve();
const dialogRequest = messages.at(-1);
assert.equal(dialogRequest.command, "__neiv.dialog.confirm");
window.cynaReply({ id: dialogRequest.id, ok: true, value: true });
assert.equal(await confirm, true);
const files = dialogs.openFiles({ title: "Documents", extensions: ["txt"], multiple: true });
await Promise.resolve();
const filesRequest = messages.at(-1);
assert.equal(filesRequest.command, "__neiv.dialog.openFiles");
assert.deepEqual(filesRequest.args, { message: "Documents", extensions: ["txt"], multiple: true });
window.cynaReply({ id: filesRequest.id, ok: false, error: { code: "CAPABILITY_DENIED", message: "Denied" } });
await assert.rejects(files, error => error.code === "CAPABILITY_DENIED");
const external = shell.openExternal("https://example.com");
await Promise.resolve();
const externalRequest = messages.at(-1);
assert.equal(externalRequest.command, "__neiv.shell.openExternal");
window.cynaReply({
  id: externalRequest.id,
  ok: false,
  error: { code: "CAPABILITY_DENIED", message: "Denied" },
});
await assert.rejects(external, error => error.code === "CAPABILITY_DENIED");
const copied = clipboard.readText();
await Promise.resolve();
const clipboardRequest = messages.at(-1);
assert.equal(clipboardRequest.command, "__neiv.clipboard.readText");
window.cynaReply({ id: clipboardRequest.id, ok: true, value: "Neiv" });
assert.equal(await copied, "Neiv");
let closeCalls = 0;
const removeCloseHandler = setCloseHandler(async () => {
  closeCalls++;
  return closeCalls > 1;
});
assert.equal(messages.at(-1).kind, "close-handler");
assert.equal(messages.at(-1).enabled, true);
await window.cynaCloseRequest({ requestId: "close-a" });
assert.equal(messages.at(-1).kind, "close-reply");
assert.equal(messages.at(-1).allow, false);
await window.cynaCloseRequest({ requestId: "close-b" });
assert.equal(messages.at(-1).allow, true);
removeCloseHandler();
assert.equal(messages.at(-1).enabled, false);
console.log("bridge lifecycle: passed");
