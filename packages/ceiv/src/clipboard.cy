import { read } from ceiv.buffer;
extern c("ceiv_clipboard_read_text") fn host_read(out: *c_char, capacity: c_int): c_int;
extern c("ceiv_clipboard_write_text") fn host_write(text: c_str): c_int;
extern c("ceiv_clipboard_capability") fn host_capability(read: c_int): c_int;

pub enum ClipboardError: i32 { denied = 0, invalid_text, unavailable }

pub fn read_text(): ?string!ClipboardError {
    if host_capability(1) == 0 { throw ClipboardError.denied; }
    return read(host_read, 65536);
}

pub fn write_text(text: c_str): void!ClipboardError {
    if host_capability(0) == 0 { throw ClipboardError.denied; }
    const status = host_write(text);
    if status == -1 { throw ClipboardError.invalid_text; }
    if status != 0 { throw ClipboardError.unavailable; }
    return;
}
