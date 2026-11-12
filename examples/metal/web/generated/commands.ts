// Generated from Cyna command exports. Do not edit.
import { invoke } from "@neucine/neiv/sdk";
import type { InvokeOptions } from "@neucine/neiv/sdk";
export function show(options?: InvokeOptions): Promise<number> {
  return invoke("show", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
export function hide(options?: InvokeOptions): Promise<number> {
  return invoke("hide", {  }, {}, {"type":"int32","min":-2147483648,"max":2147483647}, options) as Promise<number>;
}
