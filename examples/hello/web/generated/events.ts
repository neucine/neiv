// Generated from Cyna event declarations. Do not edit.
import { configureEvents, events } from "ceiv/sdk";
declare module "ceiv/sdk" {
  interface NativeEvents {
    "hello.updated": { message: string };
  }
}
configureEvents({"hello.updated":{"type":"record","fields":{"message":{"type":"string","maxBytes":64}}}});
export { events };
