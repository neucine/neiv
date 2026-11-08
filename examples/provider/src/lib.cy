import { configure_window } from neiv.lib;
import { current } from neiv.window;
import { SurfaceId, create_native, get_metrics, is_alive, attach, detach, focus, destroy } from neiv.surface;

var active: ?SurfaceId = none;

export c("neiv_app_configure") fn configure(): void {
    const configured = configure_window("Neiv Provider", 640, 480);
}

export c("provider_show") fn show(): c_int {
    if active is item {
        if is_alive(item) { return 1; }
        active = none;
    }
    const window = current() catch (error) { return 0; };
    const item = create_native(window, "provider", "demo.color", "{}") catch (error) { return 0; };
    active = item;
    return 1;
}

export c("provider_hide") fn hide(): c_int {
    if active is item {
        if is_alive(item) { destroy(item) catch (error) { return 0; }; }
        active = none;
    }
    return 1;
}

export c("provider_detach") fn detach_surface(): c_int {
    if active is item {
        if is_alive(item) {
            detach(item) catch (error) { return 0; };
            return 1;
        }
    }
    return 0;
}

export c("provider_attach") fn attach_surface(): c_int {
    if active is item {
        if is_alive(item) {
            attach(item) catch (error) { return 0; };
            return 1;
        }
    }
    return 0;
}

export c("provider_scale") fn scale(): c_int {
    if active is item {
        if is_alive(item) {
            const metrics = get_metrics(item) catch (error) { return 0; };
            if not metrics.attached or metrics.width <= 0.0 or metrics.height <= 0.0 { return 0; }
            return metrics.scale as c_int;
        }
    }
    return 0;
}

export c("provider_focus") fn focus_surface(): c_int {
    if active is item {
        if is_alive(item) {
            focus(item) catch (error) { return 0; };
            return 1;
        }
    }
    return 0;
}
