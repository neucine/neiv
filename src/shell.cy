extern c("neiv_shell_open_external") fn host_open_external(url: c_str): c_int;

pub enum ShellError: i32 { invalid_url = 0, denied, unavailable }

pub fn open_external(url: c_str): void!ShellError {
    const status = host_open_external(url);
    if status == -2 { throw ShellError.denied; }
    if status == -3 { throw ShellError.unavailable; }
    if status != 0 { throw ShellError.invalid_url; }
    return;
}
