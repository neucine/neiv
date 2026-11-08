#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <assert.h>
int neiv_set_initial_window(const char *title, int width, int height) { (void)title; (void)width; (void)height; return 0; }
long neiv_window_open_handle(const char *title, int width, int height) { (void)title; (void)width; (void)height; return 1; }
long neiv_window_open_options(const char *title, int width, int height, int minWidth, int minHeight, int visible) { (void)title; (void)width; (void)height; (void)minWidth; (void)minHeight; (void)visible; return 1; }
int neiv_window_get_state(long handle, int *values) { (void)handle; values[0] = 0; values[1] = 0; values[2] = 640; values[3] = 420; values[4] = 1; values[5] = 1; return 0; }
int neiv_window_set_size(long handle, int width, int height) { (void)handle; (void)width; (void)height; return 0; }
int neiv_window_set_bounds(long handle, int x, int y, int width, int height) { (void)handle; (void)x; (void)y; (void)width; (void)height; return 0; }
long neiv_window_current_handle(void) { return 1; }
int neiv_window_focus_handle(long handle) { (void)handle; return 0; }
int neiv_window_set_title_handle(long handle, const char *title) { (void)handle; (void)title; return 0; }
int neiv_window_close_handle(long handle) { (void)handle; return 0; }
void neiv_app_set_quit_on_last_window(int enabled) { (void)enabled; }
int neiv_window_reload_handle(long handle) { (void)handle; return 0; }
int neiv_publish_event(const char *topic, const char *payload, long target) { (void)topic; (void)payload; (void)target; return 0; }
int neiv_menu_set_application(const char *tree) { (void)tree; return 0; }
int neiv_menu_register_context(const char *id, const char *tree) { (void)id; (void)tree; return 0; }
int neiv_menu_set_state(const char *id, int enabled, int checked, int visible) { (void)id; (void)enabled; (void)checked; (void)visible; return 0; }
void neiv_menu_on_action(int (*callback)(const char *, const char *, long long, const char *)) { (void)callback; }
int neiv_slot_set_text(long window, const char *slot, const char *text) { (void)window; (void)slot; (void)text; return 0; }
int neiv_shell_open_external(const char *url) { (void)url; return -2; }
int neiv_clipboard_read_text(char *out, int capacity) { (void)out; (void)capacity; return -2; }
int neiv_clipboard_write_text(const char *text) { (void)text; return -2; }
int neiv_clipboard_capability(int read) { (void)read; return 0; }
int neiv_tray_set_title(const char *title) { (void)title; return -2; }
int neiv_tray_clear(void) { return -2; }
int neiv_notification_show(const char *title, const char *body) { (void)title; (void)body; return -2; }
long neiv_surface_create_text(long window, const char *slot, const char *text) { (void)window; (void)slot; (void)text; return 1; }
int neiv_surface_set_text(long surface, const char *text) { (void)surface; (void)text; return 0; }
int neiv_surface_destroy(long surface) { (void)surface; return 0; }
int neiv_surface_set_accessibility_label(long surface, const char *label) { (void)surface; (void)label; return 0; }
long neiv_surface_create_color(long window, const char *slot, int level) { (void)window; (void)slot; (void)level; return 0; }
long neiv_surface_create_native(long window, const char *slot, const char *kind, const char *options) { (void)window; (void)slot; (void)kind; (void)options; return -1; }
int neiv_surface_set_color_level(long surface, int level) { (void)surface; (void)level; return -1; }
int neiv_surface_set_visible(long surface, int visible) { (void)surface; (void)visible; return 0; }
int neiv_surface_set_suspended(long surface, int suspended) { (void)surface; (void)suspended; return -2; }
int neiv_surface_is_alive(long surface) { (void)surface; return 0; }
int neiv_surface_attach(long surface) { (void)surface; return 0; }
int neiv_surface_detach(long surface) { (void)surface; return 0; }
int neiv_surface_get_metrics(long surface, double *values) { (void)surface; values[0] = 50; values[1] = 30; values[2] = 2; values[3] = 1; values[4] = 1; return 0; }
int neiv_surface_get_capabilities(long window, const char *kind, int *values) { (void)window; (void)kind; for (int i = 0; i < 7; i++) values[i] = 0; return -3; }
int neiv_surface_focus(long surface) { (void)surface; return -2; }
int neiv_surface_release_focus(long surface) { (void)surface; return -2; }

extern int cyna_app_add(int value, int delta);
extern int cyna_app_surface_level(int level);
#include "generated/dispatch.inc"

int main(void) {
    @autoreleasepool {
        NSDictionary *error = nil;
        assert([dispatch_command(@"math.add", @{@"value": @4, @"delta": @3}, &error) intValue] == 7);
        assert(dispatch_command(@"math.add", @{@"value": @YES, @"delta": @3}, &error) == nil);
        assert(dispatch_command(@"math.add", @{@"value": @1000001, @"delta": @3}, &error) == nil);
        assert(dispatch_command(@"math.add", @{@"value": @1.5, @"delta": @3}, &error) == nil);
        assert(dispatch_command(@"unknown.call", @{}, &error) == nil);
        assert([dispatch_command(@"surface.setLevel", @{@"level": @500}, &error) intValue] == 250);
        assert(dispatch_command(@"surface.setLevel", @{@"level": @1001}, &error) == nil);
    }
    return 0;
}
