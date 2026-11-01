import { open_window_options, window_state_values } from ceiv.buffer;
extern c("ceiv_window_open_handle") fn host_open(title: c_str, width: c_int, height: c_int): c_long;
extern c("ceiv_window_set_size") fn host_set_size(handle: c_long, width: c_int, height: c_int): c_int;
extern c("ceiv_window_set_bounds") fn host_set_bounds(handle: c_long, x: c_int, y: c_int, width: c_int, height: c_int): c_int;
extern c("ceiv_window_current_handle") fn host_current(): c_long;
extern c("ceiv_window_focus_handle") fn host_focus(handle: c_long): c_int;
extern c("ceiv_window_set_title_handle") fn host_set_title(handle: c_long, title: c_str): c_int;
extern c("ceiv_window_close_handle") fn host_close(handle: c_long): c_int;
extern c("ceiv_window_reload_handle") fn host_reload(handle: c_long): c_int;

pub struct WindowId { value: c_long; }
pub enum WindowError: i32 { invalid_options = 0, not_found, unavailable }
pub struct WindowOptions {
    pub title: string;
    pub width: c_int;
    pub height: c_int;
    pub min_width: c_int;
    pub min_height: c_int;
    pub visible: bool;
}
pub struct WindowState {
    pub x: c_int;
    pub y: c_int;
    pub width: c_int;
    pub height: c_int;
    pub focused: bool;
    pub visible: bool;
}
pub fn raw_handle(id: WindowId): c_long { return id.value; }
pub fn from_raw_handle(handle: c_long): WindowId { return WindowId { value: handle }; }

pub fn current(): WindowId!WindowError {
    const handle = host_current();
    if handle == 0 { throw WindowError.unavailable; }
    return WindowId { value: handle };
}

pub fn open(title: c_str, width: c_int, height: c_int): WindowId!WindowError {
    const handle = host_open(title, width, height);
    if handle == 0 { throw WindowError.invalid_options; }
    return WindowId { value: handle };
}
pub fn open_with_options(options: WindowOptions): WindowId!WindowError {
    var visible: c_int = 0;
    if options.visible { visible = 1; }
    const handle = open_window_options(options.title, options.width, options.height,
        options.min_width, options.min_height, visible);
    if handle == 0 { throw WindowError.invalid_options; }
    return WindowId { value: handle };
}
pub fn get_state(id: WindowId): WindowState!WindowError {
    if window_state_values(id.value) is values {
        return WindowState { x: values[0], y: values[1], width: values[2], height: values[3],
            focused: values[4] == 1, visible: values[5] == 1 };
    }
    throw WindowError.not_found;
}
pub fn set_bounds(id: WindowId, x: c_int, y: c_int, width: c_int, height: c_int): void!WindowError {
    const status = host_set_bounds(id.value, x, y, width, height);
    if status == -2 { throw WindowError.invalid_options; }
    if status != 0 { throw WindowError.not_found; }
    return;
}
pub fn set_size(id: WindowId, width: c_int, height: c_int): void!WindowError {
    const status = host_set_size(id.value, width, height);
    if status == -2 { throw WindowError.invalid_options; }
    if status != 0 { throw WindowError.not_found; }
    return;
}

pub fn focus(id: WindowId): void!WindowError {
    if host_focus(id.value) != 0 { throw WindowError.not_found; }
    return;
}
pub fn set_title(id: WindowId, title: c_str): void!WindowError {
    if host_set_title(id.value, title) != 0 { throw WindowError.not_found; }
    return;
}
pub fn close(id: WindowId): void!WindowError {
    if host_close(id.value) != 0 { throw WindowError.not_found; }
    return;
}
pub fn reload(id: WindowId): void!WindowError {
    if host_reload(id.value) != 0 { throw WindowError.not_found; }
    return;
}
