// Generated from Cyna command exports. Do not edit.
import { invoke } from "neiv/sdk";
import type { InvokeOptions } from "neiv/sdk";
export function show(options?: InvokeOptions): Promise<number> {
  return invoke("show", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function hide(options?: InvokeOptions): Promise<number> {
  return invoke("hide", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function detachSurface(options?: InvokeOptions): Promise<number> {
  return invoke("detachSurface", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function attachSurface(options?: InvokeOptions): Promise<number> {
  return invoke("attachSurface", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function scale(options?: InvokeOptions): Promise<number> {
  return invoke("scale", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function focusSurface(options?: InvokeOptions): Promise<number> {
  return invoke("focusSurface", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
