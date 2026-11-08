import { configure_window } from neiv.lib;
import { current } from neiv.window;
import { SurfaceId, capabilities, create_native, is_alive, attach, detach } from neiv.surface;

var video: ?SurfaceId = none;

export c("neiv_app_configure") fn configure(): void {
    const configured = configure_window("Cyna hybrid framework proof", 900, 600);
}

export c("cyna_app_video_show") fn video_show(): c_int {
    if video is item {
        if is_alive(item) { return 1; }
        video = none;
    }
    const window = current() catch (error) { return 0; };
    const report = capabilities(window, "video.player") catch (error) { return 0; };
    if not report.available or not report.media or not report.decoded_frame { return 0; }
    const item = create_native(window, "preview", "video.player", "{}") catch (error) { return 0; };
    video = item;
    return 1;
}

export c("cyna_app_video_detach") fn video_detach(): c_int {
    if video is item {
        if is_alive(item) { detach(item) catch (error) { return 0; }; return 1; }
    }
    return 0;
}

export c("cyna_app_video_attach") fn video_attach(): c_int {
    if video is item {
        if is_alive(item) { attach(item) catch (error) { return 0; }; return 1; }
    }
    return 0;
}

// The host owns native commands. UI state remains in JavaScript.
// @neiv {"name":"math.add","args":{"value":{"type":"int32","min":-1000000,"max":1000000},"delta":{"type":"int32","min":-1000000,"max":1000000}}}
export c("cyna_app_add") fn add(value: c_int, delta: c_int): c_int {
    return value + delta;
}

// A native surface may receive derived state without sending pixels to JS.
// @neiv {"name":"surface.setLevel","binding":"setSurfaceLevel","args":{"level":{"type":"int32","min":0,"max":1000}}}
export c("cyna_app_surface_level") fn surface_level(level: c_int): c_int {
    return level * level / 1000;
}
