import { WindowId, raw_handle } from neiv.window;

extern c("neiv_slot_set_text") fn host_set_text(window: c_long, slot_id: c_str, text: c_str): c_int;

pub fn set_text(window: WindowId, slot_id: c_str, text: c_str): bool {
    return host_set_text(raw_handle(window), slot_id, text) == 0;
}
