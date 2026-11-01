import { configure_window } from ceiv.lib;
import { current } from ceiv.window;
import { SurfaceId, capabilities, create_color, set_color_level, set_accessibility_label, set_visible, set_suspended, is_alive, destroy } from ceiv.surface;

var active: ?SurfaceId = none;

export c("ceiv_app_configure") fn configure(): void {
    const configured = configure_window("Ceiv Metal", 640, 480);
}

export c("metal_show") fn show(): c_int {
    if active is item {
        if is_alive(item) {
            set_color_level(item, 720) catch (error) { return 0; };
            return 1;
        }
        active = none;
    }
    const window = current() catch (error) { return 0; };
    const report = capabilities(window, "color") catch (error) { return 0; };
    if not report.available or not report.metal or not report.pixel_bgra8 { return 0; }
    const item = create_color(window, "color", 500) catch (error) { return 0; };
    set_accessibility_label(item, "Metal color preview") catch (error) { return 0; };
    set_visible(item, false) catch (error) { return 0; };
    set_suspended(item, true) catch (error) { return 0; };
    set_suspended(item, false) catch (error) { return 0; };
    set_visible(item, true) catch (error) { return 0; };
    active = item;
    return 1;
}

export c("metal_hide") fn hide(): c_int {
    if active is item {
        destroy(item) catch (error) { return 0; };
        active = none;
    }
    return 1;
}
