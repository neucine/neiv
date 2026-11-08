// Generated from Cyna command exports. Do not edit.
import { invoke } from "neiv/sdk";
import type { InvokeOptions } from "neiv/sdk";
export function videoShow(options?: InvokeOptions): Promise<number> {
  return invoke("videoShow", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function videoDetach(options?: InvokeOptions): Promise<number> {
  return invoke("videoDetach", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function videoAttach(options?: InvokeOptions): Promise<number> {
  return invoke("videoAttach", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function add(value: number, delta: number, options?: InvokeOptions): Promise<number> {
  return invoke("math.add", { value, delta }, {"value":{"type":"int32","min":-1000000,"max":1000000},"delta":{"type":"int32","min":-1000000,"max":1000000}}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function setSurfaceLevel(level: number, options?: InvokeOptions): Promise<number> {
  return invoke("surface.setLevel", { level }, {"level":{"type":"int32","min":0,"max":1000}}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
