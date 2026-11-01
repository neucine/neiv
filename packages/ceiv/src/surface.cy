import { WindowId, raw_handle } from ceiv.window;
import { surface_metrics_values, surface_capability_values } from ceiv.buffer;

extern c("ceiv_surface_create_text") fn host_create_text(window: c_long, slot_id: c_str, text: c_str): c_long;
extern c("ceiv_surface_set_text") fn host_set_text(surface: c_long, text: c_str): c_int;
extern c("ceiv_surface_destroy") fn host_destroy(surface: c_long): c_int;
extern c("ceiv_surface_set_accessibility_label") fn host_set_accessibility_label(surface: c_long, label: c_str): c_int;
extern c("ceiv_surface_create_color") fn host_create_color(window: c_long, slot_id: c_str, level: c_int): c_long;
extern c("ceiv_surface_create_native") fn host_create_native(window: c_long, slot_id: c_str, kind: c_str, options_json: c_str): c_long;
extern c("ceiv_surface_set_color_level") fn host_set_color_level(surface: c_long, level: c_int): c_int;
extern c("ceiv_surface_set_visible") fn host_set_visible(surface: c_long, visible: c_int): c_int;
extern c("ceiv_surface_set_suspended") fn host_set_suspended(surface: c_long, suspended: c_int): c_int;
extern c("ceiv_surface_is_alive") fn host_is_alive(surface: c_long): c_int;
extern c("ceiv_surface_attach") fn host_attach(surface: c_long): c_int;
extern c("ceiv_surface_detach") fn host_detach(surface: c_long): c_int;
extern c("ceiv_surface_focus") fn host_focus(surface: c_long): c_int;
extern c("ceiv_surface_release_focus") fn host_release_focus(surface: c_long): c_int;

pub struct SurfaceId { value: c_long; }
pub enum SurfaceError: i32 { invalid_options = 0, not_found, unsupported, already_attached, already_detached, slot_occupied, unavailable }
pub struct SurfaceMetrics {
    pub width: c_double;
    pub height: c_double;
    pub scale: c_double;
    pub visible: bool;
    pub attached: bool;
}
pub struct SurfaceCapabilities {
    pub available: bool;
    pub metal: bool;
    pub media: bool;
    pub pixel_bgra8: bool;
    pub gpu_completion: bool;
    pub decoded_frame: bool;
    pub software_fallback: bool;
}

pub fn capabilities(window: WindowId, kind: c_str): SurfaceCapabilities!SurfaceError {
    const values = surface_capability_values(raw_handle(window), kind);
    if values[0] == -3 { throw SurfaceError.unsupported; }
    if values[0] == -2 { throw SurfaceError.not_found; }
    if values[0] != 0 { throw SurfaceError.invalid_options; }
    return SurfaceCapabilities { available: values[1] == 1, metal: values[2] == 1,
        media: values[3] == 1, pixel_bgra8: values[4] == 1,
        gpu_completion: values[5] == 1, decoded_frame: values[6] == 1,
        software_fallback: values[7] == 1 };
}

pub fn get_metrics(surface: SurfaceId): SurfaceMetrics!SurfaceError {
    if surface_metrics_values(surface.value) is values {
        return SurfaceMetrics { width: values[0], height: values[1], scale: values[2],
            visible: values[3] == 1.0, attached: values[4] == 1.0 };
    }
    throw SurfaceError.not_found;
}

pub fn create_text(window: WindowId, slot_id: c_str, text: c_str): SurfaceId!SurfaceError {
    const handle = host_create_text(raw_handle(window), slot_id, text);
    if handle == 0 { throw SurfaceError.invalid_options; }
    return SurfaceId { value: handle };
}

pub fn set_text(surface: SurfaceId, text: c_str): void!SurfaceError {
    if host_set_text(surface.value, text) != 0 { throw SurfaceError.not_found; }
    return;
}

pub fn destroy(surface: SurfaceId): void!SurfaceError {
    if host_destroy(surface.value) != 0 { throw SurfaceError.not_found; }
    return;
}

pub fn set_accessibility_label(surface: SurfaceId, label: c_str): void!SurfaceError {
    if host_set_accessibility_label(surface.value, label) != 0 { throw SurfaceError.not_found; }
    return;
}

pub fn create_color(window: WindowId, slot_id: c_str, level: c_int): SurfaceId!SurfaceError {
    const handle = host_create_color(raw_handle(window), slot_id, level);
    if handle == -1 { throw SurfaceError.unsupported; }
    if handle == -2 { throw SurfaceError.not_found; }
    if handle == 0 { throw SurfaceError.invalid_options; }
    return SurfaceId { value: handle };
}

// Low-level boundary for optional native modules. Provider packages should
// expose a typed Cyna wrapper rather than app code constructing JSON.
pub fn create_native(window: WindowId, slot_id: c_str, kind: c_str, options_json: c_str): SurfaceId!SurfaceError {
    const handle = host_create_native(raw_handle(window), slot_id, kind, options_json);
    if handle == -1 { throw SurfaceError.unsupported; }
    if handle == -2 { throw SurfaceError.not_found; }
    if handle == 0 { throw SurfaceError.invalid_options; }
    return SurfaceId { value: handle };
}

pub fn set_color_level(surface: SurfaceId, level: c_int): void!SurfaceError {
    if host_set_color_level(surface.value, level) != 0 { throw SurfaceError.not_found; }
    return;
}

pub fn set_visible(surface: SurfaceId, visible: bool): void!SurfaceError {
    var value: c_int = 0;
    if visible { value = 1; }
    if host_set_visible(surface.value, value) != 0 { throw SurfaceError.not_found; }
    return;
}

pub fn set_suspended(surface: SurfaceId, suspended: bool): void!SurfaceError {
    var value: c_int = 0;
    if suspended { value = 1; }
    const status = host_set_suspended(surface.value, value);
    if status == -2 { throw SurfaceError.unsupported; }
    if status != 0 { throw SurfaceError.not_found; }
    return;
}

pub fn is_alive(surface: SurfaceId): bool { return host_is_alive(surface.value) == 1; }

pub fn attach(surface: SurfaceId): void!SurfaceError {
    const status = host_attach(surface.value);
    if status == -2 { throw SurfaceError.already_attached; }
    if status == -3 { throw SurfaceError.slot_occupied; }
    if status != 0 { throw SurfaceError.not_found; }
    return;
}

pub fn detach(surface: SurfaceId): void!SurfaceError {
    const status = host_detach(surface.value);
    if status == -2 { throw SurfaceError.already_detached; }
    if status != 0 { throw SurfaceError.not_found; }
    return;
}

pub fn focus(surface: SurfaceId): void!SurfaceError {
    const status = host_focus(surface.value);
    if status == -2 or status == -3 { throw SurfaceError.unavailable; }
    if status != 0 { throw SurfaceError.not_found; }
    return;
}

pub fn release_focus(surface: SurfaceId): void!SurfaceError {
    const status = host_release_focus(surface.value);
    if status == -2 or status == -3 { throw SurfaceError.unavailable; }
    if status != 0 { throw SurfaceError.not_found; }
    return;
}
