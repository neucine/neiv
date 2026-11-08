import { read } from neiv.buffer;
extern c("neiv_app_quit") fn host_quit(): void;
extern c("neiv_app_set_quit_on_last_window") fn host_set_quit_on_last_window(enabled: c_int): void;
extern c("neiv_app_current") fn host_current(): c_int;
extern c("neiv_app_id") fn host_id(out: *c_char, capacity: c_int): c_int;
extern c("neiv_app_name") fn host_name(out: *c_char, capacity: c_int): c_int;
extern c("neiv_app_on_lifecycle") fn host_on_lifecycle(callback: c fn(c_str): void): void;

pub struct App { value: c_int; }

pub fn current_app(): ?App {
    if host_current() == 0 { return none; }
    return App { value: 1 };
}

pub fn id(app: App): ?string { return read(host_id, 256); }

pub fn name(app: App): ?string { return read(host_name, 256); }
pub fn on_lifecycle(callback: c fn(c_str): void): void { host_on_lifecycle(callback); }

pub fn quit(): void { host_quit(); }
pub fn quit_on_last_window(enabled: bool): void {
    if enabled { host_set_quit_on_last_window(1); } else { host_set_quit_on_last_window(0); }
}
