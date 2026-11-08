import std.json;
import { with_c_string, with_c_string_and_id } from neiv.buffer;

extern c("neiv_menu_set_application") fn host_set_application(tree_json: *const c_char): c_int;
extern c("neiv_menu_register_context") fn host_register_context(id: c_str, tree_json: *const c_char): c_int;
extern c("neiv_menu_set_state") fn host_set_state(action_id: c_str, enabled: c_int, checked: c_int, visible: c_int): c_int;
extern c("neiv_menu_on_action") fn host_on_action(callback: c fn(c_str, c_str, c_long, c_str): c_int): void;

pub struct Action {
    pub id: string;
    pub label: string;
    pub shortcut: ?string;
}

pub struct Submenu {
    pub id: string;
    pub label: string;
    pub items: List<Node>;
}

pub enum StandardRole: i32 { quit = 0, close, undo, redo, cut, copy, paste, select_all }
pub struct Role {
    pub label: string;
    pub role: StandardRole;
    pub shortcut: ?string;
}

pub union Node {
    action: Action;
    separator;
    submenu: Submenu;
    role: Role;
}

fn member(key: string, value: json.Value): json.Member {
    const result: json.Member = { key: key, value: value };
    return result;
}

fn encode_node(node: &const Node): json.Value {
    switch node {
        .action(action) => {
            var fields: List<json.Member> = list<json.Member>();
            fields.push(member("id", .string(action.id)));
            fields.push(member("label", .string(action.label)));
            if action.shortcut is shortcut { fields.push(member("shortcut", .string(shortcut))); }
            const object: json.Object = { members: fields };
            return .object(object);
        }
        .separator => {
            var fields: List<json.Member> = list<json.Member>();
            fields.push(member("separator", .bool(true)));
            const object: json.Object = { members: fields };
            return .object(object);
        }
        .submenu(submenu) => {
            var fields: List<json.Member> = list<json.Member>();
            fields.push(member("id", .string(submenu.id)));
            fields.push(member("label", .string(submenu.label)));
            fields.push(member("items", encode_nodes(submenu.items.view())));
            const object: json.Object = { members: fields };
            return .object(object);
        }
        .role(role) => {
            var fields: List<json.Member> = list<json.Member>();
            fields.push(member("label", .string(role.label)));
            const role_name = switch role.role {
                .quit => "quit";
                .close => "close";
                .undo => "undo";
                .redo => "redo";
                .cut => "cut";
                .copy => "copy";
                .paste => "paste";
                .select_all => "selectAll";
            };
            fields.push(member("role", .string(role_name)));
            if role.shortcut is shortcut { fields.push(member("shortcut", .string(shortcut))); }
            const object: json.Object = { members: fields };
            return .object(object);
        }
    }
}

fn encode_nodes(nodes: []const Node): json.Value {
    var values: List<json.Value> = list<json.Value>();
    for node in nodes { values.push(encode_node(&node)); }
    const array: json.Array = { items: values };
    return .array(array);
}

// Register a native menu tree during neiv_app_configure.
pub fn set_application(nodes: []const Node): bool {
    const value = encode_nodes(nodes);
    return with_c_string(json.encode(&value), host_set_application);
}
pub fn register_context(id: c_str, nodes: []const Node): bool {
    const value = encode_nodes(nodes);
    return with_c_string_and_id(id, json.encode(&value), host_register_context);
}
pub fn set_state(action_id: c_str, enabled: bool, checked: bool, visible: bool): bool {
    var e: c_int = 0;
    var c: c_int = 0;
    var v: c_int = 0;
    if enabled { e = 1; }
    if checked { c = 1; }
    if visible { v = 1; }
    return host_set_state(action_id, e, c, v) == 0;
}
pub fn on_action(callback: c fn(c_str, c_str, c_long, c_str): c_int): void { host_on_action(callback); }
