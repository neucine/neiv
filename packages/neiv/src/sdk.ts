// Neiv frontend runtime. App bindings and event declarations are generated separately.
type Reply = { id: number; ok: boolean; value?: unknown; error?: { code: string; message: string } };
type Session = { protocol: number; window: string; handle: number; generation: number };
export type WindowId = number & { readonly __neivWindowId: unique symbol };
type TypeSpec = {
  type: string;
  min?: number;
  max?: number;
  maxBytes?: number;
  maxItems?: number;
  items?: TypeSpec;
  value?: TypeSpec;
  fields?: Record<string, TypeSpec>;
};
export type InvokeOptions = { signal?: AbortSignal; deadlineMs?: number };
export class CynaError extends Error {
  constructor(
    public code: string,
    message: string,
  ) {
    super(message);
    this.name = "CynaError";
  }
}
function valid(value: unknown, spec: TypeSpec, depth = 0): boolean {
  if (depth > 8) return false;
  if (spec.type === "optional") return value == null || valid(value, spec.value!, depth + 1);
  if (spec.type === "int32")
    return (
      typeof value === "number" &&
      Number.isInteger(value) &&
      value >= (spec.min ?? -2147483648) &&
      value <= (spec.max ?? 2147483647)
    );
  if (spec.type === "number")
    return (
      typeof value === "number" &&
      Number.isFinite(value) &&
      value >= (spec.min ?? -1e12) &&
      value <= (spec.max ?? 1e12)
    );
  if (spec.type === "boolean") return typeof value === "boolean";
  if (spec.type === "string")
    return (
      typeof value === "string" &&
      !value.includes("\0") &&
      new TextEncoder().encode(value).length <= spec.maxBytes!
    );
  if (spec.type === "array")
    return (
      Array.isArray(value) &&
      value.length <= spec.maxItems! &&
      value.every(item => valid(item, spec.items!, depth + 1))
    );
  if (spec.type === "record") {
    if (!value || typeof value !== "object" || Array.isArray(value)) return false;
    const fields = spec.fields!;
    const record = value as Record<string, unknown>;
    return (
      Object.keys(record).every(key => Object.prototype.hasOwnProperty.call(fields, key)) &&
      Object.keys(fields).every(key => valid(record[key], fields[key], depth + 1))
    );
  }
  return false;
}
const pending = new Map<
  number,
  {
    resolve(value: unknown): void;
    reject(error: Error): void;
    result: TypeSpec;
    timer: ReturnType<typeof setTimeout>;
    signal?: AbortSignal;
    abort?: () => void;
  }
>();
let nextId = 0;
let session: Session | null = null;
let closeHandler: (() => boolean | Promise<boolean>) | null = null;
let ready: Array<{ resolve(): void; reject(error: Error): void }> = [];
export interface NativeEvents {
  "app.windows":
    | { state: "opened" | "reloading" | "closed" | "focused" | "blurred"; window: WindowId }
    | { state: "resized"; window: WindowId; width: number; height: number };
  "app.lifecycle": { state: "activated" | "deactivated" | "terminating" };
}
const eventSpecs: Record<string, TypeSpec> = {};
export function configureEvents(specs: Record<string, TypeSpec>): void {
  Object.assign(eventSpecs, specs);
}
type EventTopic = keyof NativeEvents;
const eventHandlers = new Map<
  string,
  {
    topic: EventTopic;
    sequence: number;
    handler(payload: NativeEvents[EventTopic]): void;
    signal?: AbortSignal;
    abort?: () => void;
  }
>();
const eventWaiters = new Set<(error: CynaError) => void>();
(window as any).cynaEvent = (event: {
  topic: string;
  subscriptionId: string;
  sequence: number;
  payload: unknown;
}) => {
  const active = eventHandlers.get(event.subscriptionId);
  if (
    !active ||
    event.topic !== active.topic ||
    !Number.isSafeInteger(event.sequence) ||
    event.sequence <= active.sequence
  )
    return;
  if (
    event.topic === "app.windows" &&
    (!event.payload ||
      typeof event.payload !== "object" ||
      !["opened", "reloading", "closed", "focused", "blurred", "resized"].includes(
        (event.payload as NativeEvents["app.windows"]).state,
      ) ||
      !Number.isSafeInteger((event.payload as NativeEvents["app.windows"]).window) ||
      (event.payload as NativeEvents["app.windows"]).window < 1 ||
      ((event.payload as NativeEvents["app.windows"]).state === "resized" &&
        (!Number.isSafeInteger((event.payload as any).width) ||
          !Number.isSafeInteger((event.payload as any).height))))
  )
    return;
  if (
    event.topic === "app.lifecycle" &&
    (!event.payload ||
      typeof event.payload !== "object" ||
      !["activated", "deactivated", "terminating"].includes(
        (event.payload as NativeEvents["app.lifecycle"]).state,
      ))
  )
    return;
  if (
    event.topic !== "app.windows" &&
    event.topic !== "app.lifecycle" &&
    !valid(event.payload, eventSpecs[event.topic])
  )
    return;
  active.sequence = event.sequence;
  active.handler(event.payload as NativeEvents[EventTopic]);
};
(window as any).cynaHandshake = (value: Session) => {
  if (
    value.protocol !== 1 ||
    !value.window ||
    !Number.isSafeInteger(value.handle) ||
    value.handle < 1 ||
    !Number.isSafeInteger(value.generation)
  ) {
    (window as any).cynaInvalidate("protocol mismatch", "PROTOCOL_MISMATCH");
    return;
  }
  session = value;
  for (const waiter of ready.splice(0)) waiter.resolve();
  if (actionContexts.size) syncActionStates();
  if (closeHandler) syncCloseHandler();
};
(window as any).cynaInvalidate = (reason: string, code = "INVALIDATED") => {
  session = null;
  for (const active of eventHandlers.values())
    if (active.signal && active.abort) active.signal.removeEventListener("abort", active.abort);
  eventHandlers.clear();
  actionContexts.clear();
  closeHandler = null;
  for (const fail of [...eventWaiters]) fail(new CynaError(code, reason));
  for (const waiter of ready.splice(0)) waiter.reject(new CynaError(code, reason));
  for (const [id, call] of pending) {
    clearTimeout(call.timer);
    if (call.signal && call.abort) call.signal.removeEventListener("abort", call.abort);
    call.reject(new CynaError(code, reason));
    pending.delete(id);
  }
};
window.addEventListener("pagehide", () => (window as any).cynaInvalidate("page closed"));
try {
  (window as any).webkit.messageHandlers.cyna.postMessage({ kind: "hello" });
} catch {}
(window as any).cynaReply = (reply: Reply) => {
  const call = pending.get(reply.id);
  if (!call) return;
  pending.delete(reply.id);
  clearTimeout(call.timer);
  if (call.signal && call.abort) call.signal.removeEventListener("abort", call.abort);
  if (reply.ok && valid(reply.value, call.result)) call.resolve(reply.value);
  else
    call.reject(
      new CynaError(reply.error?.code || "BAD_REPLY", reply.error?.message || "Invalid native reply"),
    );
};
function waitReady(): Promise<void> {
  return session ? Promise.resolve() : new Promise((resolve, reject) => ready.push({ resolve, reject }));
}
export async function currentWindow(): Promise<WindowId> {
  await waitReady();
  if (!session) throw new CynaError("INVALIDATED", "Page is unavailable");
  return session.handle as WindowId;
}
function syncCloseHandler() {
  if (session)
    (window as any).webkit.messageHandlers.cyna.postMessage({
      ...session,
      id: ++nextId,
      kind: "close-handler",
      enabled: !!closeHandler,
    });
}
export function setCloseHandler(handler: () => boolean | Promise<boolean>): () => void {
  if (closeHandler) throw new CynaError("INVALID_ARGUMENT", "Close handler already registered");
  closeHandler = handler;
  syncCloseHandler();
  return () => {
    if (closeHandler === handler) {
      closeHandler = null;
      syncCloseHandler();
    }
  };
}
(window as any).cynaCloseRequest = async (request: { requestId: string }) => {
  const active = session;
  if (!active || !closeHandler) return;
  let allow = false;
  try {
    allow = (await closeHandler()) === true;
  } catch (error) {
    console.error("Neiv close handler failed", error);
  }
  if (session === active)
    (window as any).webkit.messageHandlers.cyna.postMessage({
      ...active,
      id: ++nextId,
      kind: "close-reply",
      requestId: request.requestId,
      allow,
    });
};
export type ActionState = { enabled?: boolean; checked?: boolean; visible?: boolean };
export type ActionInvocation = {
  id: string;
  source: "menu" | "shortcut" | "context";
  window: WindowId;
  data: unknown;
};
export type ActionHandler = ActionState & { run(invocation: ActionInvocation): void | Promise<void> };
export type ActionContextOptions = {
  scope: "app" | "window" | "view";
  element?: HTMLElement;
  actions: Record<string, ActionHandler>;
};
type ActionContextRecord = ActionContextOptions & { active: boolean; order: number; disposed: boolean };
const actionContexts = new Set<ActionContextRecord>();
let actionOrder = 0;
function selectedAction(id: string): ActionHandler | undefined {
  const ranked = [...actionContexts]
    .filter(
      context =>
        context.active &&
        !context.disposed &&
        (context.scope !== "view" || !!context.element?.matches(":focus-within")) &&
        Object.prototype.hasOwnProperty.call(context.actions, id),
    )
    .sort(
      (a, b) =>
        ({ view: 3, window: 2, app: 1 })[b.scope] - { view: 3, window: 2, app: 1 }[a.scope] ||
        b.order - a.order,
    );
  return ranked[0]?.actions[id];
}
function syncActionStates() {
  if (!session) return;
  const ids = new Set([...actionContexts].flatMap(context => Object.keys(context.actions)));
  const states: Record<string, ActionState> = {};
  for (const id of ids) {
    const action = selectedAction(id);
    states[id] = {
      enabled: !!action && action.enabled !== false,
      checked: action?.checked === true,
      visible: action?.visible !== false,
    };
  }
  try {
    (window as any).webkit.messageHandlers.cyna.postMessage({
      ...session,
      id: ++nextId,
      kind: "action-state",
      states,
    });
  } catch {}
}
if (typeof document !== "undefined") {
  document.addEventListener("focusin", syncActionStates);
  document.addEventListener("focusout", () => queueMicrotask(syncActionStates));
}
(window as any).cynaAction = async (request: ActionInvocation & { requestId: string }) => {
  const action = selectedAction(request.id);
  let ok = false;
  try {
    if (
      action &&
      action.enabled !== false &&
      session?.handle === request.window &&
      ["menu", "shortcut", "context"].includes(request.source)
    ) {
      await action.run({
        id: request.id,
        source: request.source,
        window: request.window,
        data: request.data,
      });
      ok = true;
    }
  } catch (error) {
    console.error("Neiv action failed", error);
  }
  if (session)
    try {
      (window as any).webkit.messageHandlers.cyna.postMessage({
        ...session,
        id: ++nextId,
        kind: "action-reply",
        requestId: request.requestId,
        ok,
      });
    } catch {}
};
export function createActionContext(options: ActionContextOptions) {
  if (options.scope === "view" && !options.element)
    throw new CynaError("INVALID_ARGUMENT", "View context needs an element");
  const context: ActionContextRecord = { ...options, active: false, order: 0, disposed: false };
  actionContexts.add(context);
  return {
    activate() {
      if (context.disposed) throw new CynaError("CONTEXT_DISPOSED", "Action context disposed");
      context.active = true;
      context.order = ++actionOrder;
      syncActionStates();
    },
    deactivate() {
      context.active = false;
      syncActionStates();
    },
    update(id: string, state: ActionState) {
      if (context.disposed) throw new CynaError("CONTEXT_DISPOSED", "Action context disposed");
      if (!context.actions[id]) throw new CynaError("UNKNOWN_ACTION", id);
      Object.assign(context.actions[id], state);
      syncActionStates();
    },
    dispose() {
      context.disposed = true;
      actionContexts.delete(context);
      syncActionStates();
    },
  };
}
export function popupContextMenu(
  menuId: string,
  options: { element: HTMLElement; data?: unknown },
): Promise<string | null> {
  if (!menuId || menuId.length > 100 || !options.element.isConnected)
    throw new CynaError("INVALID_ARGUMENT", "Invalid context menu anchor");
  const box = options.element.getBoundingClientRect();
  let data: string;
  try {
    data = JSON.stringify(options.data ?? null);
  } catch {
    throw new CynaError("INVALID_ARGUMENT", "Invalid context data");
  }
  if (!data || new TextEncoder().encode(data).length > 16384)
    throw new CynaError("INVALID_ARGUMENT", "Invalid context data");
  return invoke(
    "__neiv.context.popup",
    { menuId, x: Math.max(0, box.left), y: Math.max(0, box.bottom), data },
    {
      menuId: { type: "string", maxBytes: 100 },
      x: { type: "number", min: 0, max: 100000 },
      y: { type: "number", min: 0, max: 100000 },
      data: { type: "string", maxBytes: 16384 },
    },
    { type: "optional", value: { type: "string", maxBytes: 100 } },
  ) as Promise<string | null>;
}
const dialogText = { type: "string", maxBytes: 500 };
const dialogPath = { type: "optional", value: { type: "string", maxBytes: 4096 } };
const dialogExtensions = { type: "array", maxItems: 16, items: { type: "string", maxBytes: 12 } };
export type FileDialogOptions = { title?: string; extensions?: string[] };
export const dialogs = {
  alert(message: string): Promise<void> {
    return invoke(
      "__neiv.dialog.alert",
      { message },
      { message: dialogText },
      { type: "boolean" },
      { deadlineMs: 3600000 },
    ).then(() => {});
  },
  confirm(message: string): Promise<boolean> {
    return invoke(
      "__neiv.dialog.confirm",
      { message },
      { message: dialogText },
      { type: "boolean" },
      { deadlineMs: 3600000 },
    ) as Promise<boolean>;
  },
  openFile(title = "Open File"): Promise<string | null> {
    return invoke("__neiv.dialog.openFile", { message: title }, { message: dialogText }, dialogPath, {
      deadlineMs: 3600000,
    }) as Promise<string | null>;
  },
  saveFile(title = "Save File"): Promise<string | null> {
    return invoke("__neiv.dialog.saveFile", { message: title }, { message: dialogText }, dialogPath, {
      deadlineMs: 3600000,
    }) as Promise<string | null>;
  },
  openFiles(options: FileDialogOptions & { multiple?: boolean } = {}): Promise<string[] | null> {
    return invoke(
      "__neiv.dialog.openFiles",
      {
        message: options.title ?? "Open Files",
        extensions: options.extensions ?? [],
        multiple: options.multiple ?? true,
      },
      { message: dialogText, extensions: dialogExtensions, multiple: { type: "boolean" } },
      {
        type: "optional",
        value: { type: "array", maxItems: 1024, items: { type: "string", maxBytes: 4096 } },
      },
      { deadlineMs: 3600000 },
    ) as Promise<string[] | null>;
  },
  saveFileWithOptions(options: FileDialogOptions = {}): Promise<string | null> {
    return invoke(
      "__neiv.dialog.saveFileWithOptions",
      { message: options.title ?? "Save File", extensions: options.extensions ?? [] },
      { message: dialogText, extensions: dialogExtensions },
      dialogPath,
      { deadlineMs: 3600000 },
    ) as Promise<string | null>;
  },
};
export const shell = {
  openExternal(url: string): Promise<void> {
    return invoke(
      "__neiv.shell.openExternal",
      { url },
      { url: { type: "string", maxBytes: 2048 } },
      { type: "boolean" },
    ).then(() => {});
  },
};
export const clipboard = {
  readText(): Promise<string | null> {
    return invoke(
      "__neiv.clipboard.readText",
      {},
      {},
      { type: "optional", value: { type: "string", maxBytes: 65535 } },
    ) as Promise<string | null>;
  },
  writeText(text: string): Promise<void> {
    return invoke(
      "__neiv.clipboard.writeText",
      { text },
      { text: { type: "string", maxBytes: 65535 } },
      { type: "boolean" },
    ).then(() => {});
  },
};
export const tray = {
  setTitle(title: string): Promise<void> {
    return invoke(
      "__neiv.tray.setTitle",
      { title },
      { title: { type: "string", maxBytes: 128 } },
      { type: "boolean" },
    ).then(() => {});
  },
  clear(): Promise<void> {
    return invoke("__neiv.tray.clear", {}, {}, { type: "boolean" }).then(() => {});
  },
};
export const notifications = {
  show(title: string, body: string): Promise<void> {
    return invoke(
      "__neiv.notification.show",
      { title, body },
      { title: { type: "string", maxBytes: 256 }, body: { type: "string", maxBytes: 2048 } },
      { type: "boolean" },
    ).then(() => {});
  },
};
export async function invoke(
  command: string,
  args: Record<string, unknown>,
  argSpecs: Record<string, TypeSpec>,
  result: TypeSpec,
  options: InvokeOptions = {},
  kind: "invoke" | "subscribe" = "invoke",
): Promise<unknown> {
  if (
    !Object.keys(args).every(key => Object.prototype.hasOwnProperty.call(argSpecs, key)) ||
    !Object.keys(argSpecs).every(key => valid(args[key], argSpecs[key]))
  )
    throw new CynaError("INVALID_ARGUMENT", "Invalid command arguments");
  if (new TextEncoder().encode(JSON.stringify(args)).length > 65536)
    throw new CynaError("INVALID_ARGUMENT", "Command arguments too large");
  if (options.signal?.aborted) throw new CynaError("CANCELLED", "Request cancelled");
  await waitReady();
  if (options.signal?.aborted) throw new CynaError("CANCELLED", "Request cancelled");
  const active = session;
  if (!active) throw new CynaError("INVALIDATED", "Page is unavailable");
  const deadlineMs = options.deadlineMs ?? 10000;
  if (
    !Number.isFinite(deadlineMs) ||
    deadlineMs < 1 ||
    deadlineMs > (command.startsWith("__neiv.dialog.") ? 3600000 : 30000)
  )
    throw new CynaError("INVALID_ARGUMENT", "Invalid deadline");
  return new Promise((resolve, reject) => {
    const id = ++nextId;
    const request =
      kind === "invoke"
        ? { ...active, id, kind, command, args, deadlineMs }
        : { ...active, id, kind, topic: command };
    if (new TextEncoder().encode(JSON.stringify(request)).length > 65536) {
      reject(new CynaError("INVALID_ARGUMENT", "Command arguments too large"));
      return;
    }
    const cancel = (code: string, message: string) => {
      const call = pending.get(id);
      if (!call) return;
      pending.delete(id);
      clearTimeout(call.timer);
      if (call.signal && call.abort) call.signal.removeEventListener("abort", call.abort);
      try {
        (window as any).webkit.messageHandlers.cyna.postMessage({ ...active, id, kind: "cancel" });
      } catch {}
      reject(new CynaError(code, message));
    };
    const abort = () => cancel("CANCELLED", "Request cancelled");
    const timer = setTimeout(() => cancel("TIMEOUT", "Native command timed out"), deadlineMs);
    pending.set(id, { resolve, reject, result, timer, signal: options.signal, abort });
    options.signal?.addEventListener("abort", abort, { once: true });
    try {
      (window as any).webkit.messageHandlers.cyna.postMessage(request);
    } catch (error) {
      cancel("BRIDGE_ERROR", String(error));
    }
  });
}
async function subscribe<K extends EventTopic>(
  topic: K,
  handler: (payload: NativeEvents[K]) => void,
  options: { signal?: AbortSignal } = {},
): Promise<() => void> {
  if (eventHandlers.size >= 16) throw new CynaError("LIMIT_EXCEEDED", "Too many subscriptions");
  const id = (await invoke(
    topic,
    {},
    {},
    { type: "string", maxBytes: 64 },
    { signal: options.signal },
    "subscribe",
  )) as string;
  const stop = () => {
    const active = eventHandlers.get(id);
    if (!active) return;
    eventHandlers.delete(id);
    if (active.signal && active.abort) active.signal.removeEventListener("abort", active.abort);
    if (!session) return;
    try {
      (window as any).webkit.messageHandlers.cyna.postMessage({
        ...session,
        id: ++nextId,
        kind: "unsubscribe",
        subscriptionId: id,
      });
    } catch {}
  };
  const abort = () => stop();
  eventHandlers.set(id, {
    topic,
    sequence: 0,
    handler: handler as (payload: NativeEvents[EventTopic]) => void,
    signal: options.signal,
    abort,
  });
  options.signal?.addEventListener("abort", abort, { once: true });
  if (options.signal?.aborted) {
    stop();
    throw new CynaError("CANCELLED", "Subscription cancelled");
  }
  return stop;
}
export const events = {
  subscribe,
  once<K extends EventTopic>(topic: K, options: { signal?: AbortSignal } = {}): Promise<NativeEvents[K]> {
    return new Promise((resolve, reject) => {
      let stop: (() => void) | undefined;
      let settled = false;
      const fail = (error: CynaError) => {
        if (settled) return;
        settled = true;
        options.signal?.removeEventListener("abort", abort);
        eventWaiters.delete(fail);
        stop?.();
        reject(error);
      };
      const abort = () => fail(new CynaError("CANCELLED", "Subscription cancelled"));
      eventWaiters.add(fail);
      options.signal?.addEventListener("abort", abort, { once: true });
      subscribe(
        topic,
        payload => {
          if (settled) return;
          settled = true;
          options.signal?.removeEventListener("abort", abort);
          eventWaiters.delete(fail);
          stop?.();
          resolve(payload);
        },
        options,
      ).then(
        unsubscribe => {
          stop = unsubscribe;
          if (settled) stop();
        },
        error => fail(error instanceof CynaError ? error : new CynaError("BRIDGE_ERROR", String(error))),
      );
    });
  },
};
