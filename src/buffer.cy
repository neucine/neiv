// Private adapter for bounded host output buffers on Cyna 0.4.1.
extern c("malloc") fn malloc(size: c_size_t): *c_void;
extern c("free") fn free(ptr: *c_void): void;
extern c("neiv_window_open_options") fn host_open_options(title: *const c_char, width: c_int, height: c_int, min_width: c_int, min_height: c_int, visible: c_int): c_long;
extern c("neiv_window_get_state") fn host_window_state(handle: c_long, values: *c_int): c_int;
extern c("neiv_surface_get_metrics") fn host_surface_metrics(handle: c_long, values: *c_double): c_int;
extern c("neiv_surface_get_capabilities") fn host_surface_capabilities(window: c_long, kind: c_str, values: *c_int): c_int;

pub fn surface_capability_values(window: c_long, kind: c_str): [8]c_int {
    const raw = malloc(28);
    defer free(raw);
    var result: [8]c_int = [0, 0, 0, 0, 0, 0, 0, 0];
    unchecked {
        const ptr = raw as! *c_int;
        result[0] = host_surface_capabilities(window, kind, ptr);
        if result[0] == 0 {
            var index: usize = 0;
            while index < 7 {
                result[index + 1] = *(ptr + index);
                index = index + 1;
            }
        }
    }
    return result;
}

pub fn surface_metrics_values(handle: c_long): ?[5]c_double {
    const raw = malloc(40);
    defer free(raw);
    var values: [5]c_double = [0.0, 0.0, 0.0, 0.0, 0.0];
    unchecked {
        const ptr = raw as! *c_double;
        if host_surface_metrics(handle, ptr) != 0 { return none; }
        var index: usize = 0;
        while index < 5 {
            values[index] = *(ptr + index);
            index = index + 1;
        }
    }
    return values;
}

pub fn window_state_values(handle: c_long): ?[6]c_int {
    const raw = malloc(24);
    defer free(raw);
    var values: [6]c_int = [0, 0, 0, 0, 0, 0];
    unchecked {
        const ptr = raw as! *c_int;
        if host_window_state(handle, ptr) != 0 { return none; }
        var index: usize = 0;
        while index < 6 {
            values[index] = *(ptr + index);
            index = index + 1;
        }
    }
    return values;
}

pub fn open_window_options(title: string, width: c_int, height: c_int,
    min_width: c_int, min_height: c_int, visible: c_int): c_long {
    const bytes = title.bytes();
    const raw = malloc((bytes.len() + 1) as c_size_t);
    defer free(raw);
    var handle: c_long = 0;
    unchecked {
        const ptr = raw as! *u8;
        var index: usize = 0;
        while index < bytes.len() {
            *(ptr + index) = bytes[index];
            index = index + 1;
        }
        *(ptr + bytes.len()) = 0;
        handle = host_open_options(raw as! *const c_char, width, height, min_width, min_height, visible);
    }
    return handle;
}

pub fn read(callback: c fn(*c_char, c_int): c_int, capacity: c_int): ?string {
    if capacity < 1 or capacity > 65536 { return none; }
    const raw = malloc(capacity as c_size_t);
    defer free(raw);
    var count: c_int = -1;
    unchecked { count = callback(raw as! *c_char, capacity); }
    if count < 0 or count >= capacity { return none; }
    var bytes: List<u8> = list<u8>();
    bytes.reserve(count as usize);
    var index: usize = 0;
    while index < (count as usize) {
        unchecked { bytes.push(*((raw as! *u8) + index)); }
        index = index + 1;
    }
    return string.from(bytes.view());
}

pub fn with_c_string(text: string, callback: c fn(*const c_char): c_int): bool {
    const bytes = text.bytes();
    const raw = malloc((bytes.len() + 1) as c_size_t);
    defer free(raw);
    var result: c_int = -1;
    unchecked {
        const ptr = raw as! *u8;
        var index: usize = 0;
        while index < bytes.len() {
            *(ptr + index) = bytes[index];
            index = index + 1;
        }
        *(ptr + bytes.len()) = 0;
        result = callback(raw as! *const c_char);
    }
    return result == 0;
}

pub fn with_c_string_and_id(id: c_str, text: string, callback: c fn(c_str, *const c_char): c_int): bool {
    const bytes = text.bytes();
    const raw = malloc((bytes.len() + 1) as c_size_t);
    defer free(raw);
    var result: c_int = -1;
    unchecked {
        const ptr = raw as! *u8;
        var index: usize = 0;
        while index < bytes.len() {
            *(ptr + index) = bytes[index];
            index = index + 1;
        }
        *(ptr + bytes.len()) = 0;
        result = callback(id, raw as! *const c_char);
    }
    return result == 0;
}
