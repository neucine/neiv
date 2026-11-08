import { read } from neiv.buffer;
extern c("neiv_dialog_alert") fn host_alert(message: c_str): c_int;
extern c("neiv_dialog_confirm") fn host_confirm(message: c_str): c_int;
extern c("neiv_dialog_capability") fn host_capability(save: c_int): c_int;
extern c("neiv_dialog_open_file") fn host_open_file(out: *c_char, capacity: c_int): c_int;
extern c("neiv_dialog_save_file") fn host_save_file(out: *c_char, capacity: c_int): c_int;

pub enum DialogError: i32 { denied = 0, invalid_result; }

pub fn alert(message: c_str): bool { return host_alert(message) == 0; }
pub fn confirm(message: c_str): bool { return host_confirm(message) == 1; }
pub fn open_file(): ?string!DialogError {
    if host_capability(0) == 0 { throw DialogError.denied; }
    return read(host_open_file, 4096);
}

pub fn save_file(): ?string!DialogError {
    if host_capability(1) == 0 { throw DialogError.denied; }
    return read(host_save_file, 4096);
}
