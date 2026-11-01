import { text_length, write_result } from ceiv.lib;
import { configure_window } from ceiv.lib;
import { open_with_options, WindowOptions, get_state, set_size, current, close, set_title, from_raw_handle } from ceiv.window;
import { publish_app } from ceiv.events;
import { Action, Node, set_application, register_context, set_state, on_action } from ceiv.menu;
import { set_text } from ceiv.slot;
import { current_app, id, on_lifecycle } from ceiv.app;
import { open_file } from ceiv.dialog;
import { open_external, ShellError } from ceiv.shell;
import { write_text, ClipboardError } from ceiv.clipboard;
import ceiv.surface;
import ceiv.tray;
import ceiv.notification;
import { TrayError } from ceiv.tray;
import { NotificationError } from ceiv.notification;

// @ceiv-event {"topic":"hello.updated","payload":{"type":"record","fields":{"message":{"type":"string","maxBytes":64}}}}

export c("ceiv_app_configure") fn configure(): void {
    const configured = configure_window("Hello from Cyna", 680, 460);
    const menu_items: [2]Node = [
        .action(Action { id: "hello.double", label: "Double", shortcut: "CmdOrCtrl+D" }),
        .action(Action { id: "hello.backend", label: "Rename from Cyna", shortcut: none }),
    ];
    const menu_ready = set_application(menu_items[..]);
    const backend_ready = set_state("hello.backend", true, false, true);
    const context_items: [1]Node = [.action(Action { id: "hello.double", label: "Double here", shortcut: none })];
    const context_ready = register_context("hello.context", context_items[..]);
    on_lifecycle(lifecycle);
    on_action(backend_action);
}

// @ceiv-callback
export c("hello_backend_action") fn backend_action(action_id: c_str, source: c_str, window_handle: c_long, data_json: c_str): c_int {
    if strcmp(action_id, "hello.backend") != 0 { return 1; }
    const window = from_raw_handle(window_handle);
    set_title(window, "Cyna backend action") catch (error) { return 1; };
    return 0;
}
extern c("strcmp") fn strcmp(left: c_str, right: c_str): c_int;

// @ceiv-callback
export c("hello_lifecycle") fn lifecycle(state: c_str): void { }

export c("hello_open_window") fn open_window(): c_int {
    const options: WindowOptions = { title: "Opened by Cyna", width: 640, height: 420,
        min_width: 400, min_height: 300, visible: true };
    const window = open_with_options(options) catch (error) { return 0; };
    set_size(window, 650, 430) catch (error) { return 0; };
    const state = get_state(window) catch (error) { return 0; };
    if state.width < 640 { return 0; }
    return 1;
}

export c("hello_publish_update") fn publish_update(): c_int {
    publish_app("hello.updated", "{\"message\":\"Hello from Cyna\"}") catch (error) { return 0; };
    return 1;
}

export c("hello_show_native_label") fn show_native_label(): c_int {
    const window = current() catch (error) { return 0; };
    if set_text(window, "hello_label", "Native Cyna slot") { return 1; }
    return 0;
}

export c("hello_surface_lifecycle") fn surface_lifecycle(): c_int {
    const window = current() catch (error) { return 0; };
    const item = surface.create_text(window, "ephemeral_label", "First") catch (error) { return 0; };
    surface.set_text(item, "Second") catch (error) { return 0; };
    surface.destroy(item) catch (error) { return 0; };
    return 1;
}

export c("hello_rename_current") fn rename_current(): c_int {
    const window = current() catch (error) { return 0; };
    set_title(window, "Renamed by Cyna") catch (error) { return 0; };
    return 1;
}

export c("hello_close_current") fn close_current(): c_int {
    const window = current() catch (error) { return 0; };
    close(window) catch (error) { return 0; };
    return 1;
}

export c("hello_file_dialog_status") fn file_dialog_status(): c_int {
    const path = open_file() catch (error) { return 1; };
    if path == none { return 0; }
    return 2;
}

export c("hello_service_denial") fn service_denial(): c_int {
    open_external("https://example.com") catch (error) {
        if error != ShellError.denied { return 0; }
        write_text("test") catch (clipboard_error) {
            if clipboard_error == ClipboardError.denied { return 1; }
            return 0;
        };
        return 0;
    };
    return 0;
}

export c("hello_optional_service_denial") fn optional_service_denial(): c_int {
    tray.set_title("Ceiv") catch (error) {
        if error != TrayError.denied { return 0; }
    };
    notification.show("Ceiv", "Hello") catch (error) {
        if error == NotificationError.denied { return 1; }
        return 0;
    };
    return 0;
}

export c("hello_app_identity") fn app_identity(): c_int {
    if current_app() is app {
        if id(app) is app_id {
            if app_id == "dev.neucine.ceiv.hello" { return 1; }
            return 4;
        }
        return 3;
    }
    return 2;
}

// @ceiv {"name":"math.double","args":{"value":{"type":"int32","min":-10000,"max":10000}}}
export c("hello_double") fn double_value(value: c_int): c_int {
    return value * 2;
}

extern c("usleep") fn usleep(usec: c_uint): c_int;
// @ceiv {"name":"math.slowDouble","args":{"value":{"type":"int32","min":-10000,"max":10000}}}
export c("hello_slow_double") fn slow_double(value: c_int): c_int {
    const paused = usleep(500000);
    return value * 2;
}

// @ceiv {"name":"text.score","binding":"scoreText","args":{"text":{"type":"string","maxBytes":64},"enabled":{"type":"boolean"},"factor":{"type":"number","min":0,"max":10}}}
export c("hello_score") fn score(text: c_str, enabled: c_int, factor: c_double): c_int {
    if enabled == 0 { return 0; }
    return (text_length(text) as c_int) * (factor as c_int);
}

// Composite values cross this narrow C boundary as validated JSON text.
// @ceiv {"name":"data.size","binding":"sizePayload","args":{"payload":{"type":"record","fields":{"title":{"type":"string","maxBytes":64},"flags":{"type":"array","items":"boolean","maxItems":4},"note":{"type":"optional","value":{"type":"string","maxBytes":32}}}}}}
export c("hello_payload_size") fn payload_size(payload: c_str): c_int {
    return text_length(payload) as c_int;
}

// @ceiv {"name":"text.label","binding":"labelText","returns":{"type":"string","maxBytes":16}}
export c("hello_label") fn label(out: *c_char, capacity: c_int): c_int {
    return write_result(out, capacity, "Cyna OK");
}

// @ceiv {"name":"math.half","binding":"halfValue","args":{"value":{"type":"number","min":-100,"max":100}},"returns":{"type":"number","min":-50,"max":50}}
export c("hello_half") fn half(value: c_double): c_double { return value / 2.0; }

// @ceiv {"name":"logic.invert","args":{"value":{"type":"boolean"}},"returns":"boolean"}
export c("hello_invert") fn invert(value: c_int): c_int {
    if value == 0 { return 1; }
    return 0;
}

// @ceiv {"name":"data.summary","returns":{"type":"record","fields":{"message":{"type":"string","maxBytes":32},"values":{"type":"array","items":"int32","maxItems":3},"enabled":{"type":"optional","value":"boolean"}}}}
export c("hello_summary") fn summary(out: *c_char, capacity: c_int): c_int {
    return write_result(out, capacity, "{\"message\":\"ok\",\"values\":[1,2],\"enabled\":true}");
}
