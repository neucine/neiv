extern c("ceiv_tray_set_title") fn host_set_title(title: c_str): c_int;
extern c("ceiv_tray_clear") fn host_clear(): c_int;

pub enum TrayError: i32 { denied = 0, invalid_title }

pub fn set_title(title: c_str): void!TrayError {
    const status = host_set_title(title);
    if status == -2 { throw TrayError.denied; }
    if status != 0 { throw TrayError.invalid_title; }
    return;
}

pub fn clear(): void!TrayError {
    if host_clear() != 0 { throw TrayError.denied; }
    return;
}
