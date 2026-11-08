// Generated from Cyna command exports. Do not edit.
import { invoke } from "neiv/sdk";
import type { InvokeOptions } from "neiv/sdk";
export function openWindow(options?: InvokeOptions): Promise<number> {
  return invoke("openWindow", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function publishUpdate(options?: InvokeOptions): Promise<number> {
  return invoke("publishUpdate", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function showNativeLabel(options?: InvokeOptions): Promise<number> {
  return invoke("showNativeLabel", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function surfaceLifecycle(options?: InvokeOptions): Promise<number> {
  return invoke("surfaceLifecycle", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function renameCurrent(options?: InvokeOptions): Promise<number> {
  return invoke("renameCurrent", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function closeCurrent(options?: InvokeOptions): Promise<number> {
  return invoke("closeCurrent", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function fileDialogStatus(options?: InvokeOptions): Promise<number> {
  return invoke("fileDialogStatus", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function serviceDenial(options?: InvokeOptions): Promise<number> {
  return invoke("serviceDenial", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function optionalServiceDenial(options?: InvokeOptions): Promise<number> {
  return invoke("optionalServiceDenial", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function appIdentity(options?: InvokeOptions): Promise<number> {
  return invoke("appIdentity", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function doubleValue(value: number, options?: InvokeOptions): Promise<number> {
  return invoke("math.double", { value }, {"value":{"type":"int32","min":-10000,"max":10000}}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function slowDouble(value: number, options?: InvokeOptions): Promise<number> {
  return invoke("math.slowDouble", { value }, {"value":{"type":"int32","min":-10000,"max":10000}}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function scoreText(text: string, enabled: boolean, factor: number, options?: InvokeOptions): Promise<number> {
  return invoke("text.score", { text, enabled, factor }, {"text":{"type":"string","maxBytes":64},"enabled":{"type":"boolean"},"factor":{"type":"number","min":0,"max":10}}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function sizePayload(payload: { title: string; flags: Array<boolean>; note?: string | null | undefined }, options?: InvokeOptions): Promise<number> {
  return invoke("data.size", { payload }, {"payload":{"type":"record","fields":{"title":{"type":"string","maxBytes":64},"flags":{"type":"array","maxItems":4,"items":{"type":"boolean"}},"note":{"type":"optional","value":{"type":"string","maxBytes":32}}}}}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function labelText(options?: InvokeOptions): Promise<string> {
  return invoke("text.label", {  }, {}, {"type":"string","maxBytes":16}, options) as Promise<string>;
}
export function halfValue(value: number, options?: InvokeOptions): Promise<number> {
  return invoke("math.half", { value }, {"value":{"type":"number","min":-100,"max":100}}, {"type":"number","min":-50,"max":50}, options) as Promise<number>;
}
export function invert(value: boolean, options?: InvokeOptions): Promise<boolean> {
  return invoke("logic.invert", { value }, {"value":{"type":"boolean"}}, {"type":"boolean"}, options) as Promise<boolean>;
}
export function summary(options?: InvokeOptions): Promise<{ message: string; values: Array<number>; enabled?: boolean | null | undefined }> {
  return invoke("data.summary", {  }, {}, {"type":"record","fields":{"message":{"type":"string","maxBytes":32},"values":{"type":"array","maxItems":3,"items":{"type":"int32","min":-2147483648,"max":2147483647}},"enabled":{"type":"optional","value":{"type":"boolean"}}}}, options) as Promise<{ message: string; values: Array<number>; enabled?: boolean | null | undefined }>;
}
