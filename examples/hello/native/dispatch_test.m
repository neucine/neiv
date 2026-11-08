#import <Foundation/Foundation.h>
#include <assert.h>
#include <math.h>
#include <string.h>
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
void neiv_app_quit(void) {}
int neiv_app_current(void) { return 1; }
int neiv_app_id(char *out, int capacity) { const char *id = "dev.neucine.neiv.hello"; size_t length = strlen(id); if (capacity <= length) return -1; strcpy(out, id); return (int)length; }
int neiv_app_name(char *out, int capacity) { (void)out; (void)capacity; return -1; }
int neiv_dialog_capability(int save) { (void)save; return 0; }
int neiv_dialog_alert(const char *message) { (void)message; return 0; }
int neiv_dialog_confirm(const char *message) { (void)message; return 1; }
int neiv_dialog_open_file(char *out, int capacity) { (void)out; (void)capacity; return -1; }
int neiv_dialog_save_file(char *out, int capacity) { (void)out; (void)capacity; return -1; }
void neiv_app_on_lifecycle(void (*callback)(const char *)) { (void)callback; }
#include "generated/dispatch.inc"

int main(void) {
    @autoreleasepool {
        NSDictionary *error = nil;
        assert([dispatch_command(@"math.double", @{@"value":@3}, &error) intValue] == 6);
        assert([dispatch_command(@"fileDialogStatus", @{}, &error) intValue] == 1);
        assert([dispatch_command(@"appIdentity", @{}, &error) intValue] == 1);
        assert([dispatch_command(@"openWindow", @{}, &error) intValue] == 1);
        assert([dispatch_command(@"serviceDenial", @{}, &error) intValue] == 1);
        assert([dispatch_command(@"surfaceLifecycle", @{}, &error) intValue] == 1);
        assert([dispatch_command(@"optionalServiceDenial", @{}, &error) intValue] == 1);
        assert([dispatch_command(@"text.score", @{@"text":@"Cyna", @"enabled":@YES, @"factor":@2}, &error) intValue] == 8);
        assert([dispatch_command(@"data.size", @{@"payload":@{@"title":@"Cyna", @"flags":@[@YES,@NO], @"note":NSNull.null}}, &error) intValue] > 0);
        assert([dispatch_command(@"text.label", @{}, &error) isEqualToString:@"Cyna OK"]);
        assert([dispatch_command(@"math.half", @{@"value":@9}, &error) doubleValue] == 4.5);
        id inverted = dispatch_command(@"logic.invert", @{@"value":@YES}, &error);
        assert(inverted && [inverted boolValue] == NO);
        NSDictionary *summary = dispatch_command(@"data.summary", @{}, &error);
        assert([summary[@"message"] isEqualToString:@"ok"]);
        assert([summary[@"values"] count] == 2);
        assert(dispatch_command(@"text.score", @{@"text":@"Cyna", @"enabled":@1, @"factor":@2}, &error) == nil);
        assert([error[@"code"] isEqualToString:@"INVALID_ARGUMENT"]);
        assert(dispatch_command(@"text.score", @{@"text":@"Cyna", @"enabled":@YES, @"factor":@(INFINITY)}, &error) == nil);
        assert(dispatch_command(@"text.score", @{@"text":[@"a" stringByPaddingToLength:65 withString:@"a" startingAtIndex:0], @"enabled":@YES, @"factor":@2}, &error) == nil);
        assert(dispatch_command(@"data.size", @{@"payload":@{@"title":@"x", @"flags":@[@YES,@NO,@YES,@NO,@YES]}}, &error) == nil);
        assert(dispatch_command(@"data.size", @{@"payload":@{@"title":@"x", @"flags":@[], @"extra":@1}}, &error) == nil);
        assert(dispatch_command(@"unknown.call", @{}, &error) == nil);
        assert([error[@"code"] isEqualToString:@"UNKNOWN_COMMAND"]);
    }
    return 0;
}
