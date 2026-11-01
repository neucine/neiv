// Portable helpers for the generated C command boundary.
extern c("strlen") fn strlen(text: c_str): c_size_t;
extern c("memcpy") fn memcpy(dst: *c_void, src: *const c_void, size: c_size_t): *c_void;
extern c("ceiv_set_initial_window") fn set_initial_window(title: c_str, width: c_int, height: c_int): c_int;

// Call from the app's ceiv_app_configure export before the host starts.
pub fn configure_window(title: c_str, width: c_int, height: c_int): bool {
    return set_initial_window(title, width, height) == 0;
}

pub fn text_length(text: c_str): c_size_t { return strlen(text); }

// Return the UTF-8 byte count, or -1 when the caller's buffer is too small.
pub fn write_result(out: *c_char, capacity: c_int, text: c_str): c_int {
    if capacity < 0 { return -1; }
    const count = strlen(text);
    if count > (capacity as c_size_t) { return -1; }
    unchecked {
        const copied = memcpy(out as! *c_void, text as! *const c_void, count);
    }
    return count as c_int;
}
