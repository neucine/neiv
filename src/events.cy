import { WindowId, raw_handle } from neiv.window;

extern c("neiv_publish_event") fn host_publish(topic: c_str, payload_json: c_str, target: c_long): c_int;

pub enum PublishError: i32 { invalid_payload = 0, queue_full, window_not_found }

fn checked(status: c_int): void!PublishError {
    if status == -2 { throw PublishError.queue_full; }
    if status == -3 { throw PublishError.window_not_found; }
    if status != 0 { throw PublishError.invalid_payload; }
    return;
}

// Payloads are JSON values checked against the event declaration by the host.
pub fn publish_app(topic: c_str, payload_json: c_str): void!PublishError {
    try checked(host_publish(topic, payload_json, 0));
    return;
}

pub fn publish_window(id: WindowId, topic: c_str, payload_json: c_str): void!PublishError {
    try checked(host_publish(topic, payload_json, raw_handle(id)));
    return;
}
