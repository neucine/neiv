// Generated from Cyna command exports. Do not edit.
import { invoke } from "ceiv/sdk";
import type { InvokeOptions } from "ceiv/sdk";
export function show(options?: InvokeOptions): Promise<number> {
  return invoke("show", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function hide(options?: InvokeOptions): Promise<number> {
  return invoke("hide", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
